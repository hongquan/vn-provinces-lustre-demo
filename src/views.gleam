import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, Some, is_some}
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
import lustre/event as ev

import core.{type Province, type Ward}

const class_combobox_input = "border focus-visible:outline-none focus-visible:ring-1 ps-2 pe-6 py-1 w-full rounded"

const class_combobox_choice_button = "w-full hover:bg-gray-200 dark:hover:bg-gray-600 text-start px-2 py-1.5 rounded cursor-pointer"

const class_combobox_close_button = "absolute end-0 px-2 text-xl hover:text-red-400 focus:text-red-400 hover:dark:text-red-400 cursor-pointer"

const class_combobox_dropdown_container = "absolute z-1 top-10 start-0 end-0 sm:-end-4 py-2 ps-2 bg-gray-50 dark:bg-gray-800 rounded shadow"

pub type ComboboxEmitMsg(msg, obj) {
  ComboboxEmitMsg(
    text_input: fn(String) -> msg,
    choice_click: fn(obj) -> msg,
    input_focus: msg,
    clear_click: msg,
  )
}

pub fn show_brief_info_province(province: Province) {
  h.dl([a.class("max-w-md mt-8")], [
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
  h.dl([a.class("max-w-md mt-8")], [
    h.dt([a.class("font-semibold text-lg")], [h.text(ward.name)]),
    h.dt([a.class("flex")], [
      h.span([a.class("block")], [h.text("Mã số:")]),
      h.span([a.class("block flex-grow text-end")], [
        h.text(int.to_string(ward.code)),
      ]),
    ]),
  ])
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
      let indicator = case settled_province {
        Some(x) if x == p -> "✓ "
        _ -> ""
      }
      #(
        int.to_string(p.code),
        h.li([a.role("option")], [
          h.button(
            [
              a.class(class_combobox_choice_button),
              click_handler,
            ],
            [
              h.text(indicator <> p.name),
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
      a.type_("search"),
      a.class(class_combobox_input),
      a.role("combobox"),
      a.value(filter_text),
      input_handler,
      ev.on_focus(emit_msg.input_focus),
    ]),
    h.button(
      [
        a.class(class_combobox_close_button),
        a.aria_label("Close"),
        a.aria_hidden(True),
        ev.on_click(emit_msg.clear_click),
      ],
      [
        h.text("⨯"),
      ],
    ),
    // We need some container div elements to make paddings and create scroll view for the dropdown.
    h.div(
      [
        a.class(class_combobox_dropdown_container),
        a.classes([#("hidden", !to_show)]),
      ],
      [
        h.div([a.class("max-h-40 overflow-y-auto")], [
          // The dropdown of the combobox
          keyed.ul([a.class("pe-2"), a.role("listbox")], li_items),
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
      let indicator = case settled_ward {
        Some(x) if x == w -> "✓ "
        _ -> ""
      }
      #(
        int.to_string(w.code),
        h.li([a.role("option")], [
          h.button(
            [
              a.class(class_combobox_choice_button),
              click_handler,
            ],
            [
              h.text(indicator <> w.name),
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
      a.type_("search"),
      a.class(class_combobox_input),
      a.role("combobox"),
      a.value(filter_text),
      input_handler,
      ev.on_focus(emit_msg.input_focus),
    ]),
    h.button(
      [
        a.class(class_combobox_close_button),
        a.aria_label("Close"),
        a.aria_hidden(True),
        ev.on_click(emit_msg.clear_click),
      ],
      [
        h.text("⨯"),
      ],
    ),
    // We need some container div elements to make paddings and create scroll view for the dropdown.
    h.div(
      [
        a.class(class_combobox_dropdown_container),
        a.classes([#("hidden", !to_show)]),
      ],
      [
        h.div([a.class("max-h-40 overflow-y-auto")], [
          // The dropdown of the combobox
          keyed.ul([a.class("pe-2"), a.role("listbox")], li_items),
        ]),
      ],
    ),
  ])
}
