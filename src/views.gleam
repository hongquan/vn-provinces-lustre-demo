import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/array
import gleam/option.{type Option, None, Some}
import gleam/result
import iv
import lustre/attribute as a
import lustre/effect
import lustre/element/html as h
import lustre/element/keyed
import lustre/event as ev
import on
import plinth/browser/document
import plinth/browser/element as web_element

import ffi.{is_out_of_view, query_selector_all}
import types/core.{type ComboboxState, ComboboxState}
import types/core.{type SlideDir, SlideDown, SlideUp} as _core
import types/province.{type Province}
import types/ward.{type Ward}

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

pub type ComboboxCss {
  ComboboxCss(
    input: String,
    close_button: String,
    dropdown_container: String,
    choice_button: String,
    focus_choice: String,
    unfocus_choice: String,
  )
}

pub fn get_default_combobox_css() -> ComboboxCss {
  ComboboxCss(
    input: class_combobox_input,
    close_button: class_combobox_close_button,
    dropdown_container: class_combobox_dropdown_container,
    choice_button: class_combobox_choice_button,
    focus_choice: class_combobox_focus_choice,
    unfocus_choice: class_combobox_unfocus_choice,
  )
}

pub fn get_combobox_keyup_handler(
  emit_msg: ComboboxEmitMsg(m, o),
  focused_item: Option(o),
) -> a.Attribute(m) {
  ev.on("keyup", {
    use key_code <- decode.field("key", decode.string)
    let msg = case key_code {
      "ArrowUp" -> Some(emit_msg.option_navigate(SlideUp))
      "ArrowDown" -> Some(emit_msg.option_navigate(SlideDown))
      "Enter" -> focused_item |> option.map(emit_msg.choice_click)
      _ -> None
    }

    msg
    |> option.map(fn(m) { decode.success(m) })
    |> option.lazy_unwrap(fn() {
      decode.failure(emit_msg.option_navigate(SlideUp), "SlideDir")
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
