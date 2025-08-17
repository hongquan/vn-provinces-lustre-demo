import gleam/option.{type Option, None, Some}
import gleam/uri
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import modem

import actions
import core.{type Msg, type Province, type Ward}
import router.{type Route, parse_to_route}
import views.{render_province_list, render_ward_list, show_brief_info_province}

pub type Model {
  Model(
    route: Route,
    provinces: List(Province),
    selected_province: Option(Province),
    wards: List(Ward),
    selected_ward: Option(Ward),
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
  let model = Model(route, [], None, [], None)
  let effects =
    effect.batch([modem.init(on_url_change), actions.load_provinces()])
  // At initial, we will load provinces from API.
  // We also check the browser URL, if it:
  // - points to a province, we check if the province code is valid, and load wards
  #(model, effects)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  echo msg
  case msg {
    core.ApiReturnedProvinces(Ok(provinces)) -> {
      echo provinces
      #(
        Model(
          ..model,
          provinces:,
          wards: [],
          selected_province: None,
          selected_ward: None,
        ),
        effect.none(),
      )
    }
    core.ProvinceSelected(p) -> {
      let model =
        Model(..model, wards: [], selected_province: p, selected_ward: None)
      case p {
        None -> #(model, effect.none())
        Some(p) -> #(model, actions.load_wards(p.code))
      }
    }
    core.ApiReturnedWards(Ok(wards)) -> {
      #(Model(..model, wards:), effect.none())
    }
    core.ApiReturnedWards(Error(e)) -> {
      echo e
      #(model, effect.none())
    }
    core.WardSelected(w) -> {
      let model = Model(..model, selected_ward: w)
      #(model, effect.none())
    }
    _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  let province_dropdown =
    render_province_list(model.provinces, core.ProvinceSelected)
  let ward_dropdown = render_ward_list(model.wards, core.WardSelected)
  h.div([a.class("p-4 dark:bg-gray-900 antialiased h-screen")], [
    h.h1([a.class("text-xl py-4 text-gray-900 dark:text-gray-300")], [
      h.text("Hello"),
    ]),
    h.div([a.class("space-y-4 md:flex md:flex-row md:space-x-4 md:space-y-0")], [
      h.div([a.class("text-gray-900 dark:text-gray-300 space-y-4")], [
        province_dropdown,
        model.selected_province
          |> option.map(show_brief_info_province)
          |> option.unwrap(element.none()),
      ]),
      h.div([a.class("text-gray-900 dark:text-gray-300 space-y-4")], [
        ward_dropdown,
        model.selected_ward
          |> option.map(views.show_brief_info_ward)
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
