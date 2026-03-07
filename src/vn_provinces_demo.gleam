import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri
import iv
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import modem
import plinth/browser/document
import plinth/browser/element as web_element
import plinth/browser/event as web_event
import updates

import actions
import common.{
  type Model, type Msg, ApiReturnedSearchedProvinces, ApiReturnedSearchedWards,
  ApiReturnedWards, Model, OnRouteChange, PCombobox, UserClickedOutside,
  WCombobox,
}
import router.{type Route, parse_to_route}
import types/core.{ComboboxState, create_empty_combobox_state}
import types/province.{type Province}
import types/ward.{type Ward}
import views.{
  render_province_combobox, render_ward_combobox, show_brief_info_province,
  show_brief_info_ward,
}

const id_province_combobox = "province-combobox"

const id_ward_combobox = "ward-combobox"

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(runtime) = lustre.start(app, "#app", Nil)
  document.add_event_listener("click", fn(lev) {
    case get_message_for_document_click(lev) {
      Ok(Some(msg)) -> {
        lustre.send(runtime, msg)
      }
      _ -> Nil
    }
  })
}

fn get_message_for_document_click(lev: web_event.Event(Msg)) {
  use clicked_elm <- result.try(web_element.cast(web_event.target(lev)))
  let outside_province_cbb =
    document.get_element_by_id(id_province_combobox)
    |> result.map(fn(p_cbb) { web_element.contains(clicked_elm, p_cbb) })
    |> result.unwrap(True)
  let outside_ward_cbb =
    document.get_element_by_id(id_ward_combobox)
    |> result.map(fn(w_cbb) { web_element.contains(clicked_elm, w_cbb) })
    |> result.unwrap(True)
  let msg =
    case outside_province_cbb, outside_ward_cbb {
      True, True -> Some(common.OutBoth)
      True, _ -> Some(common.OutProvince)
      _, True -> Some(common.OutWard)
      _, _ -> None
    }
    |> option.map(UserClickedOutside)
    |> option.map(lustre.dispatch)
  Ok(msg)
}

fn init(_args) -> #(Model, Effect(Msg)) {
  let query =
    modem.initial_uri()
    |> option.from_result
    |> option.then(fn(u) { u.query })
    |> option.map(fn(q) { option.from_result(uri.parse_query(q)) })
    |> option.flatten
    |> option.unwrap([])
  let route = parse_to_route(query)
  let model =
    Model(
      route:,
      provinces: [],
      wards: [],
      // For province combobox
      province_combobox_state: create_empty_combobox_state(),
      ward_combobox_state: create_empty_combobox_state(),
    )
  let effects =
    effect.batch([modem.init(on_url_change), actions.load_provinces()])
  // At initial, we will load provinces from API.
  // We also check the browser URL, if it:
  // - points to a province, we check if the province code is valid, and load wards
  #(model, effects)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    common.ApiReturnedProvinces(Ok(provinces)) -> {
      handle_loaded_provinces(provinces, model)
    }

    ApiReturnedSearchedProvinces(Ok(provinces)) -> {
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            filtered_items: iv.from_list(provinces),
          ),
        )
      #(model, effect.none())
    }

    ApiReturnedWards(Ok(wards)) -> {
      handle_loaded_wards(wards, model)
    }

    ApiReturnedSearchedWards(Ok(wards)) -> {
      let model =
        Model(
          ..model,
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            filtered_items: iv.from_list(wards),
          ),
        )
      #(model, effect.none())
    }

    OnRouteChange(new_route) -> {
      case new_route {
        router.Home -> {
          let model =
            Model(
              ..model,
              route: new_route,
              wards: [],
              // For province combobox
              province_combobox_state: ComboboxState(
                ..create_empty_combobox_state(),
                filtered_items: iv.from_list(model.provinces),
              ),
              ward_combobox_state: create_empty_combobox_state(),
            )
          #(model, effect.none())
        }
        router.Province(p, w) -> {
          handle_route_changed(new_route, p, w, model)
        }
      }
    }

    PCombobox(mm) -> {
      updates.handle_province_combobox(mm, model, id_province_combobox)
    }

    WCombobox(mm) -> {
      updates.handle_ward_combobox(mm, model, id_ward_combobox)
    }

    UserClickedOutside(position) -> {
      let should_close_province_dropdown = case position {
        common.OutBoth -> True
        common.OutProvince -> True
        _ -> False
      }
      let should_close_ward_dropdown = case position {
        common.OutBoth -> True
        common.OutWard -> True
        _ -> False
      }
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            is_shown: !should_close_province_dropdown,
          ),
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            is_shown: !should_close_ward_dropdown,
          ),
        )
      #(model, effect.none())
    }
    _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  let selected_province = model.province_combobox_state.selected_item
  let selected_ward = model.ward_combobox_state.selected_item
  let cb_msg_1 =
    views.ComboboxEmitMsg(
      fn(s) { PCombobox(province.TextInput(s)) },
      fn(p) { PCombobox(province.Selected(p)) },
      PCombobox(province.Focus),
      PCombobox(province.ClearClick),
      fn(d) { PCombobox(province.Slide(d)) },
    )

  let province_combobox =
    render_province_combobox(
      id_province_combobox,
      model.province_combobox_state,
      cb_msg_1,
    )
  let cb_msg_2 =
    views.ComboboxEmitMsg(
      fn(s) { WCombobox(ward.TextInput(s)) },
      fn(p) { WCombobox(ward.Selected(p)) },
      WCombobox(ward.Focus),
      WCombobox(ward.ClearClick),
      fn(d) { WCombobox(ward.Slide(d)) },
    )

  let ward_combobox =
    render_ward_combobox(id_ward_combobox, model.ward_combobox_state, cb_msg_2)
  // Handle "click outside" for our combobox

  h.section([a.class("grow")], [
    h.div([a.class("space-y-8 sm:flex sm:flex-row sm:space-x-8 sm:space-y-0")], [
      h.div([], [
        h.label([a.class("text-lg")], [h.text("Tỉnh thành")]),
        province_combobox,
        selected_province
          |> option.map(show_brief_info_province)
          |> option.unwrap(element.none()),
      ]),
      h.div([], [
        h.label([a.class("text-lg")], [h.text("Phường xã")]),
        ward_combobox,
        selected_ward
          |> option.map(show_brief_info_ward)
          |> option.unwrap(element.none()),
      ]),
    ]),
  ])
}

pub fn on_url_change(uri: uri.Uri) -> Msg {
  let route =
    uri.query
    |> option.map(fn(q) { option.from_result(uri.parse_query(q)) })
    |> option.flatten
    |> option.unwrap([])
    |> parse_to_route
  OnRouteChange(route)
}

fn handle_loaded_provinces(
  provinces: List(Province),
  model: Model,
) -> #(Model, Effect(Msg)) {
  // Check the browser URL, if it points to a province, we :
  // - Set the combobox value to that province.
  // - Load the wards for that province.
  let #(selected_province, whatnext) = case model.route {
    router.Province(i, _v) -> {
      case list.find(provinces, fn(p) { p.code == i }) {
        Ok(p) -> {
          #(Some(p), actions.load_wards(p.code))
        }
        _ -> #(None, effect.none())
      }
    }
    _ -> #(None, effect.none())
  }
  let #(filter_text, filtered_items) = case selected_province {
    Some(p) -> #(p.name, iv.wrap(p))
    _ -> #("", iv.from_list(provinces))
  }
  // Save provinces to model, reset the selection and wards
  let model =
    Model(
      ..model,
      provinces:,
      wards: [],
      province_combobox_state: ComboboxState(
        ..model.province_combobox_state,
        filter_text:,
        selected_item: selected_province,
        filtered_items:,
      ),
    )
  #(model, whatnext)
}

fn handle_loaded_wards(wards: List(Ward), model: Model) {
  let selected_ward = case model.route {
    router.Province(_p, Some(w_code)) -> {
      wards |> list.find(fn(w) { w.code == w_code }) |> option.from_result
    }
    _ -> None
  }
  // Save wards to the model
  let #(filter_text, filtered_items) = case selected_ward {
    Some(w) -> #(w.name, iv.wrap(w))
    _ -> #("", iv.from_list(wards))
  }
  let model =
    Model(
      ..model,
      wards:,
      ward_combobox_state: ComboboxState(
        ..model.ward_combobox_state,
        selected_item: selected_ward,
        filter_text:,
        filtered_items:,
      ),
    )
  #(model, effect.none())
}

fn handle_route_changed(
  new_route: Route,
  queried_province: Int,
  queried_ward: Option(Int),
  model: Model,
) -> #(Model, Effect(Msg)) {
  let Model(provinces:, wards:, route: current_route, ..) = model
  // If queried_province != current_province, we will load new wards
  // If queried_province == current_province and queried_ward != current_ward, we update model
  let queried_province =
    list.find(provinces, fn(p) { p.code == queried_province })
  let filtered_provinces = case queried_province {
    Ok(p) -> iv.wrap(p)
    _ -> iv.from_list(provinces)
  }
  let queried_ward = case queried_ward {
    Some(code) ->
      wards |> list.find(fn(w) { w.code == code }) |> option.from_result
    _ -> None
  }
  let filtered_wards = case queried_ward {
    Some(w) -> iv.wrap(w)
    None -> iv.from_list(wards)
  }
  let #(current_province, _current_ward) = case current_route {
    router.Home -> #(None, None)
    router.Province(i, j) -> #(Some(i), j)
  }
  let should_load_wards = case queried_province, current_province {
    Ok(p), Some(i) if p.code != i -> Some(p.code)
    Ok(p), None -> Some(p.code)
    _, _ -> None
  }
  let whatnext = case should_load_wards {
    Some(p_code) -> actions.load_wards(p_code)
    None -> effect.none()
  }
  let ward_text =
    queried_ward |> option.map(fn(w) { w.name }) |> option.unwrap("")
  let model =
    Model(
      ..model,
      route: new_route,
      province_combobox_state: ComboboxState(
        ..model.province_combobox_state,
        selected_item: option.from_result(queried_province),
        filtered_items: filtered_provinces,
      ),
      ward_combobox_state: ComboboxState(
        ..model.ward_combobox_state,
        selected_item: queried_ward,
        filtered_items: filtered_wards,
        filter_text: ward_text,
      ),
    )
  #(model, whatnext)
}
