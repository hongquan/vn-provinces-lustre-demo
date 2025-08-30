import consts
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, is_some}
import gleam/result
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
import lustre/event as ev

import core.{type Province, type Ward}

pub type ComboboxEmitMsg(msg, obj) {
  ComboboxEmitMsg(
    text_input: fn(String) -> msg,
    choice_click: fn(obj) -> msg,
    input_focus: msg,
  )
}

pub fn render_province_as_option(
  p: Province,
  selected_code: Int,
) -> Element(msg) {
  h.option(
    [a.value(int.to_string(p.code)), a.selected(p.code == selected_code)],
    p.name,
  )
}

pub fn render_ward_as_option(w: Ward, selected_ward: Int) -> Element(msg) {
  h.option(
    [a.value(int.to_string(w.code)), a.selected(w.code == selected_ward)],
    w.name,
  )
}

pub fn get_province_from_code(c: Int, provinces: List(Province)) {
  provinces |> list.find(fn(p) { p.code == c })
}

pub fn get_ward_from_code(c: Int, wards: List(Ward)) -> Result(Ward, Nil) {
  wards |> list.find(fn(w) { w.code == c })
}

pub fn render_province_list(
  provinces: List(Province),
  selected_code: Int,
  receiver: fn(Option(Province)) -> msg,
) -> Element(msg) {
  let options = [
    h.option([a.value("")], "Tỉnh thành..."),
    ..list.map(provinces, render_province_as_option(_, selected_code))
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
      ev.on_change(on_change_handler),
    ],
    options,
  )
}

pub fn show_brief_info_province(province: Province) {
  h.dl([a.class("max-w-md")], [
    h.dt([a.class("font-semibold text-lg")], [h.text(province.name)]),
    h.dt([a.class("flex")], [
      h.span([a.class("block")], [h.text("Mã số:")]),
      h.span([a.class("block flex-grow text-end")], [
        h.text(int.to_string(province.code)),
      ]),
    ]),
  ])
}

pub fn show_brief_info_ward(ward: Ward) {
  h.dl([a.class("max-w-md")], [
    h.dt([a.class("font-semibold text-lg")], [h.text(ward.name)]),
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
  selected_ward: Int,
  receiver: fn(Option(Ward)) -> msg,
) -> Element(msg) {
  let options = [
    h.option([a.value("")], "Phường xã..."),
    ..list.map(wards, render_ward_as_option(_, selected_ward))
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
      ev.on_change(on_change_handler),
    ],
    options,
  )
}

pub fn render_province_combobox(
  id: String,
  to_show: Bool,
  provinces: List(Province),
  filter_text: String,
  settled_province: Option(Province),
  emit_msg: ComboboxEmitMsg(msg, Province),
) -> Element(msg) {
  let li_items =
    provinces
    |> list.map(fn(p) {
      let click_handler =
        ev.on("click", decode.success(emit_msg.choice_click(p)))
      #(
        int.to_string(p.code),
        h.li([], [
          h.button(
            [
              a.class(
                "w-full hover:bg-gray-200 dark:hover:bg-gray-600 text-start px-2 py-1.5 rounded cursor-pointer",
              ),
              click_handler,
            ],
            [
              h.text(p.name),
            ],
          ),
        ]),
      )
    })
  // Event handler for the text input
  let input_handler = case is_some(settled_province) {
    True -> ev.debounce(ev.on_input(emit_msg.text_input), 200)
    False -> a.none()
  }
  // Handle "click outside"
  h.div([a.id(id), a.class("relative")], [
    // The Text Input of the combobox
    h.input([
      a.class(
        "border focus-visible:outline-none focus-visible:ring-1 px-2 py-1 w-full rounded",
      ),
      input_handler,
      ev.on_focus(emit_msg.input_focus),
      a.value(filter_text),
    ]),
    // We need some container div elements to make paddings and create scroll view for the dropdown.
    h.div(
      [
        a.class(
          "absolute z-1 top-10 start-0 -end-4 py-2 ps-2 bg-gray-50 dark:bg-gray-800 shadow",
        ),
        a.classes([#("hidden", !to_show)]),
      ],
      [
        h.div([a.class("max-h-40 overflow-y-auto")], [
          // The dropdown of the combobox
          keyed.ul([a.class("pe-2")], li_items),
        ]),
      ],
    ),
  ])
}

pub fn render_ward_combobox(
  id: String,
  to_show: Bool,
  wards: List(Ward),
  filter_text: String,
  settled_ward: Option(Ward),
  emit_msg: ComboboxEmitMsg(msg, Ward),
) {
  let li_items =
    wards
    |> list.map(fn(w) {
      let click_handler =
        ev.on("click", decode.success(emit_msg.choice_click(w)))
      #(
        int.to_string(w.code),
        h.li([], [
          h.button(
            [
              a.class(
                "w-full hover:bg-gray-200 dark:hover:bg-gray-600 text-start px-2 py-1.5 rounded cursor-pointer",
              ),
              click_handler,
            ],
            [
              h.text(w.name),
            ],
          ),
        ]),
      )
    })
  // Event handler for the text input
  let input_handler = case is_some(settled_ward) {
    True -> ev.debounce(ev.on_input(emit_msg.text_input), 200)
    False -> a.none()
  }
  h.div([a.id(id), a.class("relative")], [
    // The Text Input of the combobox
    h.input([
      a.class(
        "border focus-visible:outline-none focus-visible:ring-1 px-2 py-1 w-full rounded",
      ),
      input_handler,
      ev.on_focus(emit_msg.input_focus),
      a.value(filter_text),
      a.value(filter_text),
    ]),
    // We need some container div elements to make paddings and create scroll view for the dropdown.
    h.div(
      [
        a.class(
          "absolute z-1 top-10 start-0 -end-4 py-2 ps-2 bg-gray-50 dark:bg-gray-800 shadow",
        ),
        a.classes([#("hidden", !to_show)]),
      ],
      [
        h.div([a.class("max-h-40 overflow-y-auto")], [
          // The dropdown of the combobox
          keyed.ul([a.class("pe-2")], li_items),
        ]),
      ],
    ),
  ])
}
