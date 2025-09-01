import gleam/dynamic/decode.{new_primitive_decoder}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/uri
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as ev
import modem
import plinth/browser/document.{create_text_node}
import plinth/browser/element as web_element

import actions
import core.{
  type ComboboxState, type Msg, type Province, type Ward, ComboboxState,
  ProvinceComboboxClearClick, ProvinceComboboxFocused, ProvinceComboboxSelected,
  ProvinceComboboxTextInput, UserClickedOutside, WardComboboxClearClick,
  WardComboboxFocused, WardComboboxSelected, WardComboboxTextInput,
  create_empty_combobox_state,
}
import router.{type Route, parse_to_route}
import views.{
  render_province_combobox, render_ward_combobox, show_brief_info_province,
  show_brief_info_ward,
}

const id_province_combobox = "province-combobox"

const id_ward_combobox = "ward-combobox"

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
    core.ApiReturnedWards(Ok(wards)) -> {
      io.println("Wards loaded")
      handle_loaded_wards(wards, model)
    }
    core.ApiReturnedSearchedWards(Ok(wards)) -> {
      let model =
        Model(
          ..model,
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            filtered_items: wards,
          ),
        )
      #(model, effect.none())
    }
    core.OnRouteChange(new_route) -> {
      case new_route {
        router.Home -> {
          let model =
            Model(
              ..model,
              route: new_route,
              wards: [],
              // For province combobox
              province_combobox_state: create_empty_combobox_state(),
              ward_combobox_state: create_empty_combobox_state(),
            )

          #(model, effect.none())
        }
        router.Province(p, w) -> {
          handle_route_changed(new_route, p, w, model)
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
    ProvinceComboboxClearClick -> {
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            filter_text: "",
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
    WardComboboxClearClick -> {
      let model =
        Model(
          ..model,
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            filter_text: "",
          ),
        )
      #(model, effect.none())
    }
    WardComboboxTextInput(s) -> {
      io.println("Ward input text: " <> s)
      let Model(
        province_combobox_state: ComboboxState(
          selected_item: selected_province,
          ..,
        ),
        ..,
      ) = model
      let model =
        Model(
          ..model,
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            filter_text: s,
          ),
        )
      let province_code =
        selected_province |> option.map(fn(p) { p.code }) |> option.unwrap(0)
      #(model, actions.search_wards(s, province_code))
    }

    WardComboboxSelected(w) -> {
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
    UserClickedOutside -> {
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            is_shown: False,
          ),
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            is_shown: False,
          ),
        )
      #(model, effect.none())
    }
    _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  let Model(
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
    ..,
  ) = model
  let filtered_provinces = case province_filter_text {
    "" -> provinces
    _ -> filtered_provinces
  }
  let cb_msg =
    views.ComboboxEmitMsg(
      ProvinceComboboxTextInput,
      ProvinceComboboxSelected,
      ProvinceComboboxFocused,
      ProvinceComboboxClearClick,
    )

  let province_combobox =
    render_province_combobox(
      id_province_combobox,
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
      WardComboboxClearClick,
    )

  let filtered_wards = case ward_filter_text {
    "" -> wards
    _ -> filtered_wards
  }
  let ward_combobox =
    render_ward_combobox(
      id_ward_combobox,
      ward_combobox_shown,
      filtered_wards,
      ward_filter_text,
      selected_ward,
      cb_msg,
    )
  // Handle "click outside" for our combobox
  let click_handler =
    ev.on("click", {
      let html_element_decoder = get_htmlelement_decoder()
      use clicked_node <- decode.field("target", html_element_decoder)
      let outside_province = case
        document.get_element_by_id(id_province_combobox)
      {
        Ok(box) -> web_element.contains(clicked_node, box)
        Error(_) -> True
      }
      let outside_ward = case document.get_element_by_id(id_ward_combobox) {
        Ok(box) -> web_element.contains(clicked_node, box)
        Error(_) -> True
      }
      case outside_province || outside_ward {
        True -> decode.success(UserClickedOutside)
        False -> decode.failure(UserClickedOutside, "Not outsise")
      }
    })
  h.section([a.class("grow"), click_handler], [
    h.div([a.class("space-y-8 md:flex md:flex-row md:space-x-8 md:space-y-0")], [
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
  core.OnRouteChange(route)
}

fn handle_loaded_provinces(
  provinces: List(core.Province),
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
    Some(p) -> #(p.name, [p])
    _ -> #("", [])
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
    Some(w) -> #(w.name, [w])
    _ -> #("", [])
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
    Ok(p) -> [p]
    _ -> []
  }
  let queried_ward = case queried_ward {
    Some(code) ->
      wards |> list.find(fn(w) { w.code == code }) |> option.from_result
    _ -> None
  }
  let filtered_wards = case queried_ward {
    Some(w) -> [w]
    None -> []
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
      ),
    )
  #(model, whatnext)
}

fn get_htmlelement_decoder() -> decode.Decoder(web_element.Element) {
  new_primitive_decoder("HTMLElement", fn(data) {
    case web_element.cast(data) {
      Ok(x) -> Ok(x)
      Error(_) -> Error(create_text_node(""))
    }
  })
}
