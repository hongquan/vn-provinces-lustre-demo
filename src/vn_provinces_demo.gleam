import gleam/int
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

import action
import common.{
  type Model, type Msg, ApiReturnedProvinces, ApiReturnedSearchedProvinces,
  ApiReturnedSearchedWards, ApiReturnedSourceWards, ApiReturnedWards, Model,
  OnRouteChange, PCombobox, UserClickedClearOnProvinceCbx, UserClickedOutside,
  UserFocusedProvinceCbx, UserSelectedProvince, WCombobox,
}
import component/combobox
import mytype/core.{ComboboxState, create_empty_combobox_state}
import mytype/province.{type Province}
import mytype/ward.{type Ward}
import router.{type Route, parse_to_route}
import update
import view
import view/after_25

const id_province_combobox = "province-combobox"

const id_ward_combobox = "ward-combobox"

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  // Register Web Component for combobox.
  let assert Ok(_) = combobox.register()
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
      selected_province_code: 0,
      source_wards: [],
    )
  let effects =
    effect.batch([modem.init(on_url_change), action.load_provinces()])
  // At initial, we will load provinces from API.
  // We also check the browser URL, if it:
  // - points to a province, we check if the province code is valid, and load wards
  #(model, effects)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(new_route) -> {
      case new_route {
        router.Home -> {
          let model =
            Model(
              ..model,
              route: new_route,
              wards: [],
              source_wards: [],
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
          handle_route_changed(p, w, model, new_route)
        }
      }
    }

    ApiReturnedProvinces(Ok(provinces)) -> {
      handle_loaded_provinces(provinces, model)
    }

    ApiReturnedProvinces(Error(_e)) -> #(model, effect.none())

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
    ApiReturnedSearchedProvinces(Error(_e)) -> #(model, effect.none())

    ApiReturnedWards(Ok(wards)) -> {
      handle_loaded_wards(wards, model)
    }
    ApiReturnedWards(Error(_e)) -> #(model, effect.none())

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
    ApiReturnedSearchedWards(Error(_e)) -> #(model, effect.none())

    ApiReturnedSourceWards(Ok(wards)) -> {
      echo wards
      // Save to model if some ward is selected in the combobox.
      let source_wards = case model.ward_combobox_state.selected_item {
        Some(_w) -> wards
        _ -> []
      }
      let model = Model(..model, source_wards:)
      #(model, effect.none())
    }
    ApiReturnedSourceWards(Error(_e)) -> #(model, effect.none())

    PCombobox(mm) -> {
      update.handle_province_combobox(mm, model, id_province_combobox)
    }

    WCombobox(mm) -> {
      update.handle_ward_combobox(mm, model, id_ward_combobox)
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
    UserFocusedProvinceCbx -> {
      #(model, effect.none())
    }
    UserClickedClearOnProvinceCbx -> {
      #(model, modem.push(".", Some(""), None))
    }
    UserSelectedProvince(code) -> {
      let query_string = uri.query_to_string([#("p", int.to_string(code))])
      #(model, modem.push("", Some(query_string), None))
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  let css_classes = view.get_default_combobox_css()
  h.section([a.class("grow")], [
    h.header([a.class("mb-4 border-b border-gray-500")], [
      h.h2([a.class("text-2xl")], [h.text("Sau sáp nhập 2025")]),
    ]),
    after_25.view(model, id_province_combobox, id_ward_combobox, css_classes),
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
          #(Some(p), action.load_wards(p.code))
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
      source_wards: [],
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
  // If a ward is selected in the route, load legacy ward sources
  let whatnext = case selected_ward {
    Some(w) -> action.load_legacy_ward_sources(w.code)
    _ -> effect.none()
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
  #(model, whatnext)
}

fn handle_route_changed(
  queried_province: Int,
  queried_ward: Option(Int),
  model: Model,
  new_route: Route,
) -> #(Model, Effect(Msg)) {
  let Model(provinces:, wards:, route: current_route, ..) = model
  // If queried_province != current_province, we will load new wards.
  // If queried_province == current_province and queried_ward != current_ward, we update model.
  // When loading new ward, we also load legacy ward sources.
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
  let whatnext = case should_load_wards, queried_ward {
    Some(p_code), Some(w) ->
      effect.batch([
        action.load_wards(p_code),
        action.load_legacy_ward_sources(w.code),
      ])
    None, Some(w) -> action.load_legacy_ward_sources(w.code)
    Some(p_code), None -> action.load_wards(p_code)
    _, _ -> effect.none()
  }
  let ward_text =
    queried_ward |> option.map(fn(w) { w.name }) |> option.unwrap("")
  // Clear source_wards if no ward is selected
  let source_wards = case queried_ward {
    Some(_) -> model.source_wards
    None -> []
  }
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
      source_wards:,
    )
  #(model, whatnext)
}
