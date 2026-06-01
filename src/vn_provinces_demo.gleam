import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/uri
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import modem

import action
import common.{
  type Message, type Model, ApiReturnedProvinces, ApiReturnedSearchedProvinces,
  ApiReturnedSearchedWards, ApiReturnedSourceWards, ApiReturnedWards, Model,
  OnRouteChange, UserClickedClearOnProvinceCbx, UserClickedClearOnWardCbx,
  UserFocusedProvinceCbx, UserFocusedWardCbx, UserSelectedProvince,
  UserSelectedWard, UserTextInputProvince, UserTextInputWard,
}
import component/combobox
import mytype/province.{type Province}
import mytype/ward.{type Ward}
import router.{type Route, parse_to_route}
import view/after_25

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = combobox.register()
  let assert Ok(_runtime) = lustre.start(app, "#app", Nil)
  Nil
}

fn init(_args) -> #(Model, Effect(Message)) {
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
      filtered_provinces: [],
      wards: [],
      filtered_wards: [],
      selected_province: None,
      selected_ward: None,
      source_wards: [],
    )
  let effects =
    effect.batch([modem.init(on_url_change), action.load_provinces()])
  #(model, effects)
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    OnRouteChange(new_route) -> {
      case new_route {
        router.Home -> {
          let model =
            Model(
              ..model,
              route: new_route,
              wards: [],
              filtered_wards: [],
              source_wards: [],
              selected_ward: None,
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
      #(Model(..model, filtered_provinces: provinces), effect.none())
    }
    ApiReturnedSearchedProvinces(Error(_e)) -> #(model, effect.none())

    ApiReturnedWards(Ok(wards)) -> {
      handle_loaded_wards(wards, model)
    }
    ApiReturnedWards(Error(_e)) -> #(model, effect.none())

    ApiReturnedSearchedWards(Ok(wards)) -> {
      #(Model(..model, filtered_wards: wards), effect.none())
    }
    ApiReturnedSearchedWards(Error(_e)) -> #(model, effect.none())

    ApiReturnedSourceWards(Ok(wards)) -> {
      let source_wards = case model.selected_ward {
        Some(_w) -> wards
        _ -> []
      }
      let model = Model(..model, source_wards:)
      #(model, effect.none())
    }
    ApiReturnedSourceWards(Error(_e)) -> #(model, effect.none())

    UserFocusedProvinceCbx -> #(model, effect.none())
    UserTextInputProvince(value) -> {
      #(model, action.search_provinces(value))
    }
    UserClickedClearOnProvinceCbx -> {
      let model =
        Model(
          ..model,
          selected_province: None,
          selected_ward: None,
          wards: [],
          filtered_wards: [],
          source_wards: [],
        )
      #(model, modem.push(".", Some(""), None))
    }
    UserSelectedProvince(code) -> {
      let query_string = uri.query_to_string([#("p", int.to_string(code))])
      #(model, modem.push("", Some(query_string), None))
    }

    UserFocusedWardCbx -> #(model, effect.none())
    UserTextInputWard(value) -> {
      let province_code =
        model.selected_province
        |> option.map(fn(p) { p.code })
        |> option.unwrap(0)
      #(model, action.search_wards(value, province_code))
    }
    UserClickedClearOnWardCbx -> {
      let q = case model.route {
        router.Province(p, _) ->
          Some(uri.query_to_string([#("p", int.to_string(p))]))
        _ -> None
      }
      #(model, modem.push(".", q, None))
    }
    UserSelectedWard(code) -> {
      let new_w = #("w", int.to_string(code))
      let new_query = case model.route {
        router.Province(p, _) -> [#("p", int.to_string(p)), new_w]
        _ -> [new_w]
      }
      #(model, modem.push("", Some(uri.query_to_string(new_query)), None))
    }
  }
}

fn view(model: Model) -> Element(Message) {
  h.section([a.class("grow")], [
    h.header([a.class("mb-4 border-b border-gray-500")], [
      h.h2([a.class("text-2xl")], [h.text("Sau sáp nhập 2025")]),
    ]),
    after_25.view(model),
  ])
}

pub fn on_url_change(uri: uri.Uri) -> Message {
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
) -> #(Model, Effect(Message)) {
  let #(selected_province, whatnext) = case model.route {
    router.Province(i, _v) -> {
      case list.find(provinces, fn(p) { p.code == i }) {
        Ok(p) -> #(Some(p), action.load_wards(p.code))
        _ -> #(None, effect.none())
      }
    }
    _ -> #(None, effect.none())
  }
  let model =
    Model(
      ..model,
      provinces:,
      filtered_provinces: provinces,
      wards: [],
      source_wards: [],
      selected_province:,
      selected_ward: None,
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
  let whatnext = case selected_ward {
    Some(w) -> action.load_legacy_ward_sources(w.code)
    _ -> effect.none()
  }
  let model =
    Model(
      ..model,
      wards:,
      filtered_wards: wards,
      selected_ward:,
      source_wards: [],
    )
  #(model, whatnext)
}

fn handle_route_changed(
  queried_province: Int,
  queried_ward: Option(Int),
  model: Model,
  new_route: Route,
) -> #(Model, Effect(Message)) {
  let Model(provinces:, wards:, route: current_route, ..) = model
  let queried_province =
    list.find(provinces, fn(p) { p.code == queried_province })
  let queried_ward = case queried_ward {
    Some(code) ->
      wards |> list.find(fn(w) { w.code == code }) |> option.from_result
    _ -> None
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
  let source_wards = case queried_ward {
    Some(_) -> model.source_wards
    None -> []
  }
  let model =
    Model(
      ..model,
      route: new_route,
      selected_province: option.from_result(queried_province),
      selected_ward: queried_ward,
      source_wards:,
    )
  #(model, whatnext)
}
