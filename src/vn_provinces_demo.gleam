import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/uri
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import modem

import actions
import core.{
  type ComboboxState, type Msg, type Province, type Ward, ComboboxState,
  ProvinceComboboxFocused, ProvinceComboboxSelected, ProvinceComboboxTextInput,
  ProvinceSelected, WardComboboxFocused, WardComboboxSelected,
  WardComboboxTextInput, WardSelected, create_empty_combobox_state,
}
import router.{type Route, parse_to_route}
import views.{
  render_province_combobox, render_ward_combobox, show_brief_info_province,
  show_brief_info_ward,
}

pub type Model {
  Model(
    route: Route,
    provinces: List(Province),
    wards: List(Ward),
    // For province combobox
    province_combobox_state: ComboboxState(Province),
    ward_combobox_state: ComboboxState(Ward),
  )
}

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
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
    core.ApiReturnedProvinces(Ok(provinces)) -> {
      handle_loaded_provinces(provinces, model)
    }
    core.ApiReturnedSearchedProvinces(Ok(provinces)) -> {
      io.println("ApiReturnedSearchedProvinces")
      echo provinces
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            filtered_items: provinces,
          ),
        )
      #(model, effect.none())
    }
    // User has picked a province from dropdown
    ProvinceSelected(p) -> {
      let model =
        Model(
          ..model,
          wards: [],
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            selected_item: p,
          ),
        )
      case p {
        None -> #(model, effect.none())
        Some(p) -> {
          // Reflect to browser URL
          let query_string =
            uri.query_to_string([#("p", int.to_string(p.code))])
          #(model, modem.push("", Some(query_string), None))
        }
      }
    }
    core.ApiReturnedWards(Ok(wards)) -> {
      io.println("Wards loaded")
      handle_loaded_wards(wards, model)
    }
    core.ApiReturnedWards(Error(e)) -> {
      echo e
      #(model, effect.none())
    }
    WardSelected(w) -> {
      case w {
        None -> #(model, effect.none())
        Some(w) -> {
          // Reflect to browser URL
          let new_append = #("w", int.to_string(w.code))
          let new_query = case model.route {
            router.Province(p, _w) -> [#("p", int.to_string(p)), new_append]
            _ -> [new_append]
          }
          #(model, modem.push("", Some(uri.query_to_string(new_query)), None))
        }
      }
    }
    core.OnRouteChange(new_route) -> {
      case new_route {
        router.Home -> #(model, effect.none())
        router.Province(p, _w) -> {
          echo model
          handle_route_changed(new_route, p, model)
        }
      }
    }
    ProvinceComboboxTextInput(s) -> {
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            filter_text: s,
          ),
        )
      #(model, actions.search_provinces(s))
    }
    ProvinceComboboxSelected(p) -> {
      io.println("ProvinceComboboxSelected")
      echo p
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            selected_item: Some(p),
            filter_text: p.name,
            is_shown: False,
          ),
        )
      // Reflect to browser URL
      let query_string = uri.query_to_string([#("p", int.to_string(p.code))])
      #(model, modem.push("", Some(query_string), None))
    }
    ProvinceComboboxFocused -> {
      io.println("Focused")
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            is_shown: True,
          ),
        )
      #(model, effect.none())
    }

    WardComboboxFocused -> {
      let model =
        Model(
          ..model,
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            is_shown: True,
          ),
        )
      #(model, effect.none())
    }

    WardComboboxSelected(w) -> {
      io.println("WardComboboxSelected")
      echo w
      let model =
        Model(
          ..model,
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            is_shown: False,
            filter_text: w.name,
            selected_item: Some(w),
          ),
        )
      // Reflect to browser URL
      let new_append = #("w", int.to_string(w.code))
      let new_query = case model.route {
        router.Province(p, _w) -> [#("p", int.to_string(p)), new_append]
        _ -> [new_append]
      }
      #(model, modem.push("", Some(uri.query_to_string(new_query)), None))
    }
    _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  let Model(
    route:,
    provinces:,
    wards:,
    province_combobox_state: ComboboxState(
      is_shown: province_combobox_shown,
      filter_text: province_filter_text,
      filtered_items: filtered_provinces,
      selected_item: selected_province,
    ),
    ward_combobox_state: ComboboxState(
      filter_text: ward_filter_text,
      selected_item: selected_ward,
      filtered_items: filtered_wards,
      is_shown: ward_combobox_shown,
    ),
  ) = model
  echo selected_province
  echo selected_ward
  let filtered_provinces = case province_filter_text {
    "" -> provinces
    _ -> filtered_provinces
  }
  // If the filter text is empty and the URL is pointing to a province, we show province name in the text input
  let province_filter_text = case province_filter_text, route {
    "", router.Province(p_code, _w) -> {
      provinces
      |> list.find_map(fn(p) {
        case p.code == p_code {
          True -> Ok(p.name)
          False -> Error(Nil)
        }
      })
      |> result.unwrap(province_filter_text)
    }
    _, _ -> province_filter_text
  }
  let cb_msg =
    views.ComboboxEmitMsg(
      ProvinceComboboxTextInput,
      ProvinceComboboxSelected,
      ProvinceComboboxFocused,
    )

  let province_combobox =
    render_province_combobox(
      province_combobox_shown,
      filtered_provinces,
      province_filter_text,
      selected_province,
      cb_msg,
    )
  let cb_msg =
    views.ComboboxEmitMsg(
      WardComboboxTextInput,
      WardComboboxSelected,
      WardComboboxFocused,
    )

  let filtered_wards = case ward_filter_text {
    "" -> wards
    _ -> filtered_wards
  }
  // If the filter text is empty and the URL is pointing to a ward, we show ward name in the text input
  let ward_filter_text = case ward_filter_text, route {
    "", router.Province(_p, Some(w_code)) -> {
      wards
      |> list.find_map(fn(w) {
        case w.code == w_code {
          True -> {
            Ok(w.name)
          }
          False -> Error(Nil)
        }
      })
      |> result.unwrap(ward_filter_text)
    }
    _, _ -> ward_filter_text
  }
  let ward_combobox =
    render_ward_combobox(
      ward_combobox_shown,
      filtered_wards,
      ward_filter_text,
      selected_ward,
      cb_msg,
    )
  h.section([], [
    h.div([a.class("space-y-4 md:flex md:flex-row md:space-x-4 md:space-y-0")], [
      h.div([], [
        province_combobox,
        selected_province
          |> option.map(show_brief_info_province)
          |> option.unwrap(element.none()),
      ]),
      h.div([], [
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
  core.OnRouteChange(route)
}

fn handle_loaded_provinces(
  provinces: List(core.Province),
  model: Model,
) -> #(Model, Effect(Msg)) {
  // Check the browser URL, if it points to a province, we load the wards for that province
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
  // Save provinces to model, reset the selection and wards
  let model =
    Model(
      ..model,
      provinces:,
      wards: [],
      province_combobox_state: ComboboxState(
        ..model.province_combobox_state,
        selected_item: selected_province,
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
  let model =
    Model(
      ..model,
      wards:,
      ward_combobox_state: ComboboxState(
        ..model.ward_combobox_state,
        selected_item: selected_ward,
      ),
    )
  #(model, effect.none())
}

fn handle_route_changed(
  new_route: Route,
  queried_province: Int,
  model: Model,
) -> #(Model, Effect(Msg)) {
  let Model(provinces:, route: current_route, ..) = model
  let queried_province =
    list.find(provinces, fn(p) { p.code == queried_province })
  // If queried_province != current_province, we will load new wards
  let current_province = case current_route {
    router.Home -> None
    router.Province(i, _v) -> Some(i)
  }
  let whatnext = case queried_province, current_province {
    Ok(i), Some(j) if i.code != j -> actions.load_wards(i.code)
    Ok(i), None -> actions.load_wards(i.code)
    _, _ -> effect.none()
  }
  let model =
    Model(
      ..model,
      route: new_route,
      province_combobox_state: ComboboxState(
        ..model.province_combobox_state,
        selected_item: option.from_result(queried_province),
      ),
    )
  #(model, whatnext)
}
