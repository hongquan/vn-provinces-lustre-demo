import gleam/dynamic/decode
import gleam/int
import gleam/option.{None, Some}
import iv
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
import lustre/event as ev

import common.{type Model, PCombobox, WCombobox}
import types/core.{type ComboboxState, ComboboxState}
import types/province.{type Province}
import types/ward.{type Ward}
import views.{type ComboboxCss, type ComboboxEmitMsg, get_combobox_keyup_handler}

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
  state: ComboboxState(Province),
  emit_msg: ComboboxEmitMsg(msg, Province),
  css_classes: ComboboxCss,
) -> Element(msg) {
  let ComboboxState(
    is_shown: to_show,
    filter_text:,
    filtered_items: filtered_provinces,
    selected_item: settled_province,
    focused_index:,
  ) = state
  let li_items =
    filtered_provinces
    |> iv.index_map(fn(p, i) {
      let click_handler =
        ev.on("click", decode.success(emit_msg.choice_click(p)))
      let indicator = case settled_province {
        Some(x) if x == p -> "✓ "
        _ -> ""
      }
      let is_focused = case focused_index {
        fi if fi > 0 && fi == i + 1 -> True
        _ -> False
      }
      #(
        int.to_string(p.code),
        h.li([a.role("option")], [
          h.button(
            [
              a.classes([
                #(css_classes.choice_button, True),
                #(css_classes.focus_choice, is_focused),
                #(css_classes.unfocus_choice, !is_focused),
              ]),
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
  let focused_province = case focused_index - 1 {
    fi if fi >= 0 -> {
      filtered_provinces |> iv.get(fi) |> option.from_result
    }
    _ -> None
  }
  let keyup_handler = get_combobox_keyup_handler(emit_msg, focused_province)
  h.div([a.id(id), a.class("relative")], [
    // The Text Input of the combobox
    h.input([
      a.type_("search"),
      a.class(css_classes.input),
      a.role("combobox"),
      a.value(filter_text),
      input_handler,
      ev.on_focus(emit_msg.input_focus),
      keyup_handler,
    ]),
    h.button(
      [
        a.class(css_classes.close_button),
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
        a.class(css_classes.dropdown_container),
        a.classes([#("hidden", !to_show)]),
      ],
      [
        h.div([a.class("max-h-40 overflow-y-auto")], [
          // The dropdown of the combobox
          keyed.ul([a.class("pe-2"), a.role("listbox")], iv.to_list(li_items)),
        ]),
      ],
    ),
  ])
}

pub fn render_ward_combobox(
  id: String,
  state: ComboboxState(Ward),
  emit_msg: ComboboxEmitMsg(msg, Ward),
  css_classes: ComboboxCss,
) {
  let ComboboxState(
    is_shown: to_show,
    filter_text:,
    filtered_items: filtered_wards,
    selected_item: settled_ward,
    focused_index:,
  ) = state
  let li_items =
    filtered_wards
    |> iv.index_map(fn(w, i) {
      let click_handler =
        ev.on("click", decode.success(emit_msg.choice_click(w)))
      let indicator = case settled_ward {
        Some(x) if x == w -> "✓ "
        _ -> ""
      }
      let is_focused = case focused_index {
        fi if fi > 0 && fi == i + 1 -> True
        _ -> False
      }
      #(
        int.to_string(w.code),
        h.li([a.role("option")], [
          h.button(
            [
              a.classes([
                #(css_classes.choice_button, True),
                #(css_classes.focus_choice, is_focused),
                #(css_classes.unfocus_choice, !is_focused),
              ]),
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
  let focused_ward = case focused_index - 1 {
    fi if fi >= 0 -> {
      filtered_wards |> iv.get(fi) |> option.from_result
    }
    _ -> None
  }
  let keyup_handler = get_combobox_keyup_handler(emit_msg, focused_ward)
  h.div([a.id(id), a.class("relative")], [
    // The Text Input of the combobox
    h.input([
      a.type_("search"),
      a.class(css_classes.input),
      a.role("combobox"),
      a.value(filter_text),
      input_handler,
      ev.on_focus(emit_msg.input_focus),
      keyup_handler,
    ]),
    h.button(
      [
        a.class(css_classes.close_button),
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
        a.class(css_classes.dropdown_container),
        a.classes([#("hidden", !to_show)]),
      ],
      [
        h.div([a.class("max-h-40 overflow-y-auto")], [
          // The dropdown of the combobox
          keyed.ul([a.class("pe-2"), a.role("listbox")], iv.to_list(li_items)),
        ]),
      ],
    ),
  ])
}

pub fn render_post_2025_provinces(
  model: Model,
  id_province_combobox: String,
  id_ward_combobox: String,
  css_classes: ComboboxCss,
) {
  let selected_province = model.province_combobox_state.selected_item
  let selected_ward = model.ward_combobox_state.selected_item
  let cb_msg_1 =
    views.ComboboxEmitMsg(
      fn(s) { PCombobox(province.TextInput(s)) },
      fn(p) { PCombobox(province.Selected(p)) },
      PCombobox(province.Focus),
      PCombobox(province.ClearClick),
      fn(d) { PCombobox(province.Slide(d)) },
    )

  let province_combobox =
    render_province_combobox(
      id_province_combobox,
      model.province_combobox_state,
      cb_msg_1,
      css_classes,
    )
  let cb_msg_2 =
    views.ComboboxEmitMsg(
      fn(s) { WCombobox(ward.TextInput(s)) },
      fn(p) { WCombobox(ward.Selected(p)) },
      WCombobox(ward.Focus),
      WCombobox(ward.ClearClick),
      fn(d) { WCombobox(ward.Slide(d)) },
    )

  let ward_combobox =
    render_ward_combobox(
      id_ward_combobox,
      model.ward_combobox_state,
      cb_msg_2,
      css_classes,
    )
  // Handle "click outside" for our combobox

  h.div([a.class("space-y-8 sm:flex sm:flex-row sm:space-x-8 sm:space-y-0")], [
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
  ])
}
