import consts
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event

import core.{type Province, type Ward}

pub fn render_province_as_option(p: Province) -> Element(msg) {
  h.option([a.value(int.to_string(p.code))], p.name)
}

pub fn render_ward_as_option(w: Ward) -> Element(msg) {
  h.option([a.value(int.to_string(w.code))], w.name)
}

pub fn get_province_from_code(c: Int, provinces: List(Province)) {
  provinces |> list.find(fn(p) { p.code == c })
}

pub fn get_ward_from_code(c: Int, wards: List(Ward)) {
  wards |> list.find(fn(w) { w.code == c })
}

pub fn render_province_list(
  provinces: List(Province),
  receiver: fn(Option(Province)) -> msg,
) -> Element(msg) {
  let options = [
    h.option([a.value("")], "Tỉnh thành..."),
    ..list.map(provinces, render_province_as_option)
  ]
  let on_change_handler = fn(v: String) {
    v
    |> int.parse
    |> result.try(get_province_from_code(_, provinces))
    |> option.from_result
    |> receiver
  }
  h.select(
    [
      a.class(consts.css_select),
      event.on_change(on_change_handler),
    ],
    options,
  )
}

pub fn show_brief_info_province(province: Province) {
  h.dl([a.class("text-sm max-w-xs")], [
    h.dt([a.class("font-semibold")], [h.text(province.name)]),
    h.dt([a.class("flex")], [
      h.span([a.class("block")], [h.text("Mã số:")]),
      h.span([a.class("block flex-grow text-end")], [
        h.text(int.to_string(province.code)),
      ]),
    ]),
  ])
}

pub fn show_brief_info_ward(ward: Ward) {
  h.dl([a.class("text-sm max-w-xs")], [
    h.dt([a.class("font-semibold")], [h.text(ward.name)]),
    h.dt([a.class("flex")], [
      h.span([a.class("block")], [h.text("Mã số:")]),
      h.span([a.class("block flex-grow text-end")], [
        h.text(int.to_string(ward.code)),
      ]),
    ]),
  ])
}

pub fn render_ward_list(
  wards: List(Ward),
  receiver: fn(Option(Ward)) -> msg,
) -> Element(msg) {
  let options = [
    h.option([a.value("")], "Phường xã..."),
    ..list.map(wards, render_ward_as_option)
  ]
  let on_change_handler = fn(v: String) {
    v
    |> int.parse
    |> result.try(get_ward_from_code(_, wards))
    |> option.from_result
    |> receiver
  }
  h.select(
    [
      a.class(consts.css_select),
      event.on_change(on_change_handler),
    ],
    options,
  )
}
