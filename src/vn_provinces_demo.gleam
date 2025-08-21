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
  let model = Model(route, [], None, [])
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
    // User has picked a province from dropdown
    core.ProvinceSelected(p) -> {
      let model = Model(..model, wards: [], selected_province: p)
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
      #(Model(..model, wards:), effect.none())
    }
    core.ApiReturnedWards(Error(e)) -> {
      echo e
      #(model, effect.none())
    }
    core.WardSelected(w) -> {
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
          handle_route_changed(new_route, p, model)
        }
      }
    }
    _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  let Model(route:, provinces:, selected_province:, wards:) = model
  let selected_province =
    selected_province |> option.map(fn(p) { p.code }) |> option.unwrap(0)
  let province_dropdown =
    render_province_list(provinces, selected_province, core.ProvinceSelected)
  let selected_ward = case route {
    router.Province(_p, Some(w)) -> w
    _ -> 0
  }
  let ward_dropdown = render_ward_list(wards, selected_ward, core.WardSelected)
  let ward_info = case list.find(wards, fn(w) { w.code == selected_ward }) {
    Ok(ward) -> views.show_brief_info_ward(ward)
    _ -> element.none()
  }
  h.div(
    [
      a.class(
        "p-4 dark:bg-gray-900 text-gray-900 dark:text-gray-300 antialiased h-screen",
      ),
    ],
    [
      h.header([], [
        h.h1([a.class("text-xl py-4 text-gray-900 dark:text-gray-300")], [
          h.text("Tỉnh thành Việt Nam 🇻🇳"),
        ]),
      ]),
      h.main([], [
        h.div(
          [a.class("space-y-4 md:flex md:flex-row md:space-x-4 md:space-y-0")],
          [
            h.div([a.class("text-gray-900 dark:text-gray-300 space-y-4")], [
              province_dropdown,
              model.selected_province
                |> option.map(show_brief_info_province)
                |> option.unwrap(element.none()),
            ]),
            h.div([a.class("text-gray-900 dark:text-gray-300 space-y-4")], [
              ward_dropdown,
              ward_info,
            ]),
          ],
        ),
      ]),
      h.footer([a.class("mt-8 text-sm")], [
        h.text("Implemented in "),
        h.a(
          [
            a.href("https://gleam.run/"),
            a.class("underline hover:text-sky-800 dark:hover:text-sky-300"),
          ],
          [
            h.text("Gleam language"),
          ],
        ),
        h.text(" "),
        h.text("and"),
        h.text(" "),
        h.a(
          [
            a.href("https://hexdocs.pm/lustre/"),
            a.class("underline hover:text-sky-800 dark:hover:text-sky-300"),
          ],
          [
            h.text("Lustre framework."),
          ],
        ),
        h.br([]),
        h.a(
          [
            a.href("https://github.com/hongquan/vn-provinces-lustre-demo"),
            a.class("underline hover:text-sky-800 dark:hover:text-sky-300"),
          ],
          [
            h.text("Source"),
          ],
        ),
        h.text("."),
      ]),
    ],
  )
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
  let model = Model(..model, provinces:, wards: [], selected_province:)
  #(model, whatnext)
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
      selected_province: option.from_result(queried_province),
    )
  #(model, whatnext)
}
