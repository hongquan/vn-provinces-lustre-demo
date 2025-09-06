import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/array
import gleam/option.{type Option, None, Some}
import gleam/result
import iv
import lustre/attribute as a
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
import lustre/event as ev
import on
import plinth/browser/document
import plinth/browser/element as web_element

import core.{
  type ComboboxState, type Province, type SlideDir, type Ward, ComboboxState,
}
import ffi.{is_out_of_view, query_selector_all}

const class_combobox_input = "border focus-visible:outline-none focus-visible:ring-1 ps-2 pe-6 py-1 w-full rounded"

const class_combobox_choice_button = "w-full text-start px-2 py-1.5 rounded cursor-pointer"

const class_combobox_unfocus_choice = "hover:bg-neutral-200 dark:hover:bg-neutral-600"

const class_indicate_focus = "vn-focus"

const class_combobox_focus_choice = "bg-slate-200 dark:bg-slate-600"
  <> " "
  <> class_indicate_focus

const class_combobox_close_button = "absolute end-0 px-2 text-xl hover:text-red-400 focus:text-red-400 hover:dark:text-red-400 cursor-pointer"

const class_combobox_dropdown_container = "absolute z-1 top-10 start-0 end-0 sm:-end-4 py-2 ps-2 bg-neutral-50 dark:bg-neutral-800 rounded shadow"

pub type ComboboxEmitMsg(msg, obj) {
  ComboboxEmitMsg(
    text_input: fn(String) -> msg,
    choice_click: fn(obj) -> msg,
    input_focus: msg,
    clear_click: msg,
    option_navigate: fn(SlideDir) -> msg,
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
  state: ComboboxState(Province),
  emit_msg: ComboboxEmitMsg(msg, Province),
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
                #(class_combobox_choice_button, True),
                #(class_combobox_focus_choice, is_focused),
                #(class_combobox_unfocus_choice, !is_focused),
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
      a.class(class_combobox_input),
      a.role("combobox"),
      a.value(filter_text),
      input_handler,
      ev.on_focus(emit_msg.input_focus),
      keyup_handler,
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
                #(class_combobox_choice_button, True),
                #(class_combobox_focus_choice, is_focused),
                #(class_combobox_unfocus_choice, !is_focused),
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
      a.class(class_combobox_input),
      a.role("combobox"),
      a.value(filter_text),
      input_handler,
      ev.on_focus(emit_msg.input_focus),
      keyup_handler,
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
          keyed.ul([a.class("pe-2"), a.role("listbox")], iv.to_list(li_items)),
        ]),
      ],
    ),
  ])
}

fn get_combobox_keyup_handler(
  emit_msg: ComboboxEmitMsg(m, o),
  focused_item: Option(o),
) -> a.Attribute(m) {
  ev.on("keyup", {
    use key_code <- decode.field("key", decode.string)
    let msg = case key_code {
      "ArrowUp" -> Some(emit_msg.option_navigate(core.SlideUp))
      "ArrowDown" -> Some(emit_msg.option_navigate(core.SlideDown))
      "Enter" -> focused_item |> option.map(emit_msg.choice_click)
      _ -> None
    }

    msg
    |> option.map(fn(m) { decode.success(m) })
    |> option.lazy_unwrap(fn() {
      decode.failure(emit_msg.option_navigate(core.SlideUp), "SlideDir")
    })
  })
}

pub fn scroll_to_see_focused_item(combobox_id: String, focused_index: Int) {
  // The focused_index is 1-based, so we return early if it is <= 0
  use <- bool.guard(focused_index <= 0, effect.none())
  use _dispatch, _root_element <- effect.after_paint

  // Convert focused_index to 0-based.
  let index = focused_index - 1
  let scrolled_container = document.get_element_by_id(combobox_id)
  let focused_list_item =
    scrolled_container
    |> result.map(query_selector_all(_, "li"))
    |> result.try(array.get(_, index))

  case scrolled_container, focused_list_item {
    Ok(cont), Ok(elm) -> {
      use <- on.true(is_out_of_view(elm, cont))
      web_element.scroll_into_view(elm)
      True
    }
    _, _ -> False
  }
  Nil
}
