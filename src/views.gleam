import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{Some}
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
import lustre/event as ev

import core.{type ComboboxState, type Province, type Ward, ComboboxState}

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
  provinces: List(Province),
  state: ComboboxState(Province),
  emit_msg: ComboboxEmitMsg(msg, Province),
) -> Element(msg) {
  let ComboboxState(
    is_shown: to_show,
    filter_text:,
    filtered_items: filtered_provinces,
    selected_item: settled_province,
    ..,
  ) = state
  let offered_provinces = case filter_text {
    "" -> provinces
    _ -> filtered_provinces
  }
  let li_items =
    offered_provinces
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
  let input_handler = ev.on_input(emit_msg.text_input) |> ev.debounce(200)
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
  wards: List(Ward),
  state: ComboboxState(Ward),
  emit_msg: ComboboxEmitMsg(msg, Ward),
) {
  let ComboboxState(
    is_shown: to_show,
    filter_text:,
    filtered_items: filtered_wards,
    selected_item: settled_ward,
    ..,
  ) = state
  let offered_wards = case filter_text {
    "" -> wards
    _ -> filtered_wards
  }
  let li_items =
    offered_wards
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
  let input_handler = ev.on_input(emit_msg.text_input) |> ev.debounce(200)
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
