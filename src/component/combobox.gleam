import ffi.{is_out_of_view, query_selector_all}
import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/array
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import iv
import lustre
import lustre/attribute.{type Attribute} as a
import lustre/component
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
import lustre/event as ev
import on
import plinth/browser/document
import plinth/browser/element as web_element
import typeid

// This component will be used as `<combo-box>`
const component_name = "combo-box"

pub type Item {
  Item(name: String, code: Int)
}

fn item_decoder() -> decode.Decoder(Item) {
  use name <- decode.field("name", decode.string)
  use code <- decode.field("code", decode.int)
  decode.success(Item(name:, code:))
}

pub fn item_to_json(item: Item) -> json.Json {
  let Item(name:, code:) = item
  json.object([
    #("name", json.string(name)),
    #("code", json.int(code)),
  ])
}

type Model {
  Model(
    // The HTML `id` attribute. We need it to find the node in real DOM,
    // then do `scrollIntoView`
    id: String,
    choices: List(Item),
    is_input_focused: Bool,
    filter_text: String,
    // Should be updated to `True` if the input is focused.
    // TODO: Is it duplicate with `is_input_focused`?
    is_list_shown: Bool,
    filtered_choices: iv.Array(Item),
    selected_item: Option(Item),
    // 1-based index of the item to focus when navigating with keyboard.
    // Zero means no one is focused.
    focused_index: Int,
    // Preselected item code (used when choices arrive later)
    preselect_code: Option(Int),
  )
}

pub type SlideDir {
  SlideUp
  SlideDown
}

type Message {
  UserFocusedInput
  UserClickedClear
  UserNavigate(SlideDir)
  // Pick an item in suggested list, either via click or "Enter"
  UserPickedChoice(Item)
  UserWroteText(String)
  ParentSetId(String)
  ParentChangedChoices(List(Item))
  ParentPreselectedItem(Int)
}

// Message that we will emit to parent
pub type EmitMessage {
  Focused
  Selected(Int)
  TextInput(String)
  ClearClicked
}

const payload_name = "detail"

const attr_preselect_code = "preselect-code"

const class_input = "border focus-visible:outline-none focus-visible:ring-1 ps-2 pe-6 py-1 w-full rounded"

const class_choice_button = "w-full text-start px-2 py-1.5 rounded cursor-pointer"

const class_indicate_focus = "vn-focus"

const class_focused_choice = "bg-slate-200 dark:bg-slate-600"
  <> " "
  <> class_indicate_focus

const class_unfocused_choice = "hover:bg-neutral-200 dark:hover:bg-neutral-600"

const class_close_button = "absolute end-0 px-2 text-xl hover:text-red-400 focus:text-red-400 hover:dark:text-red-400 cursor-pointer"

const class_dropdown_container = "absolute z-1 top-10 start-0 end-0 sm:-end-4 py-2 ps-2 bg-neutral-50 dark:bg-neutral-800 rounded shadow"

pub fn register() -> Result(Nil, lustre.Error) {
  let component =
    lustre.component(init, update, view, [
      component.on_attribute_change("id", fn(value) { Ok(ParentSetId(value)) }),
      component.on_attribute_change(attr_preselect_code, fn(value) {
        echo attr_preselect_code <> "changed to " <> value
        int.parse(value) |> result.map(ParentPreselectedItem)
      }),
      component.on_property_change("choices", {
        item_decoder() |> decode.list |> decode.map(ParentChangedChoices)
      }),
    ])
  lustre.register(component, component_name)
}

pub fn element(attributes: List(Attribute(m))) -> Element(m) {
  element.element(component_name, attributes, [])
}

// -- Shortcuts to let parent element set attributes / properties to pass data

pub fn preselect_code(code: Int) -> Attribute(m) {
  a.attribute(attr_preselect_code, int.to_string(code))
}

// -- Shortcuts to let parent element easily register event handlers --

pub fn on_focused(message: message) -> Attribute(message) {
  ev.on(get_message_name(Focused), {
    use _detail <- decode.field(payload_name, decode.optional(decode.bool))
    decode.success(message)
  })
}

pub fn on_selected(handler: fn(Int) -> message) -> Attribute(message) {
  ev.on(get_message_name(Selected(0)), {
    use code <- decode.field(payload_name, decode.int)
    decode.success(handler(code))
  })
}

pub fn on_text_input(handler: fn(String) -> message) -> Attribute(message) {
  ev.on(get_message_name(TextInput("")), {
    use value <- decode.field(payload_name, decode.string)
    decode.success(handler(value))
  })
}

pub fn on_clear_clicked(message: message) -> Attribute(message) {
  ev.on(get_message_name(ClearClicked), {
    use _detail <- decode.field(payload_name, decode.optional(decode.bool))
    decode.success(message)
  })
}

fn emit(message: EmitMessage) {
  let name = get_message_name(message)
  case message {
    Focused -> ev.emit(name, json.null())
    Selected(code) -> ev.emit(name, json.int(code))
    TextInput(value) -> ev.emit(name, json.string(value))
    ClearClicked -> ev.emit(name, json.null())
  }
}

fn get_message_name(message: EmitMessage) {
  case message {
    Focused -> "focused"
    Selected(_) -> "selected"
    TextInput(_) -> "text-input"
    ClearClicked -> "clear-clicked"
  }
}

fn init(_) -> #(Model, effect.Effect(Message)) {
  let assert Ok(id) = typeid.new("cbox")
  let model =
    Model(
      id: typeid.to_string(id),
      choices: [],
      is_input_focused: False,
      filter_text: "",
      is_list_shown: False,
      filtered_choices: iv.new(),
      selected_item: None,
      focused_index: 0,
      preselect_code: None,
    )
  #(model, effect.none())
}

fn update(model: Model, message: Message) -> #(Model, effect.Effect(a)) {
  case message {
    UserFocusedInput -> {
      let model = Model(..model, is_input_focused: True, is_list_shown: True)
      #(model, emit(Focused))
    }
    UserPickedChoice(it) -> {
      let model =
        Model(
          ..model,
          selected_item: Some(it),
          // If an item is picked, close the suggestion list
          is_list_shown: False,
        )
      #(model, emit(Selected(it.code)))
    }
    UserWroteText(text) -> {
      let Model(choices:, filtered_choices:, ..) = model
      let #(filtered_choices, whatnext) = case string.trim(text) {
        "" -> #(iv.from_list(choices), effect.none())
        value -> #(filtered_choices, emit(TextInput(value)))
      }
      let model = Model(..model, filtered_choices:)
      #(model, whatnext)
    }
    UserClickedClear -> {
      #(model, emit(ClearClicked))
    }
    UserNavigate(direction) -> {
      let Model(id:, focused_index:, filtered_choices:, ..) = model
      let i = case direction {
        // The lower item has higher index, so pressing ↑ means to go to lower index.
        SlideUp -> focused_index - 1
        SlideDown -> focused_index + 1
      }
      let focused_index = int.clamp(i, 0, iv.size(filtered_choices))
      let scroll_effect = scroll_to_see_focused_item(id, focused_index)
      let model = Model(..model, focused_index:)
      #(model, scroll_effect)
    }
    ParentSetId(id) -> #(Model(..model, id:), effect.none())
    ParentChangedChoices(choices) -> {
      let model = Model(..model, choices:)
      // If there's a pending preselect_code, apply it now that choices are available
      case model.preselect_code {
        Some(code) -> apply_preselection(code, model)
        None -> #(model, effect.none())
      }
    }
    ParentPreselectedItem(code) -> {
      let model = Model(..model, preselect_code: Some(code))
      // If choices are already available, apply immediately
      case model.choices {
        [] -> #(model, effect.none())
        _ -> apply_preselection(code, model)
      }
    }
  }
}

fn apply_preselection(code: Int, model: Model) -> #(Model, effect.Effect(a)) {
  let selected_item =
    list.find(model.choices, fn(it) { it.code == code })
    |> option.from_result
  let filter_text =
    selected_item |> option.map(fn(it) { it.name }) |> option.unwrap("")
  let model = Model(..model, selected_item:, filter_text:)
  #(model, effect.none())
}

fn view(model: Model) -> Element(Message) {
  let Model(
    id:,
    choices:,
    filter_text:,
    focused_index:,
    selected_item:,
    is_list_shown: to_show_list,
    ..,
  ) = model
  let focused_item = {
    use <- bool.guard(when: focused_index < 1, return: None)
    model.filtered_choices |> iv.get(focused_index - 1) |> option.from_result
  }
  h.div([a.class("relative")], [
    // The Text Input of the combobox
    h.input([
      a.type_("search"),
      a.id(id),
      a.class(class_input),
      a.role("combobox"),
      a.value(filter_text),
      // Event handlers
      ev.on_focus(UserFocusedInput),
      ev.on_input(UserWroteText) |> ev.debounce(200),
      setup_keyup_handler(focused_item),
    ]),
    h.button(
      [
        a.class(class_close_button),
        a.aria_label("Close"),
        a.aria_hidden(True),
        ev.on_click(UserClickedClear),
      ],
      [h.text("⨯")],
    ),

    // We need some container div elements to make paddings and create scroll view for the dropdown.
    h.div(
      [
        a.class(class_dropdown_container),
        a.classes([#("hidden", !to_show_list)]),
      ],
      [
        h.div([a.class("max-h-40 overflow-y-auto")], [
          // The dropdown of the combobox
          keyed.ul(
            [a.class("pe-2"), a.role("listbox")],
            build_li_elements(choices, selected_item, focused_index),
          ),
        ]),
      ],
    ),
  ])
}

/// When user is typing in the "<input>", a list of suggestion will appear,
/// user then can use ↑, ↓ keys to move the highlight, press Enter to select
fn setup_keyup_handler(focused_item: Option(Item)) -> Attribute(Message) {
  ev.on("keyup", {
    use key_code <- decode.field("key", decode.string)
    let message = case key_code {
      "ArrowUp" -> Some(UserNavigate(SlideUp))
      "ArrowDown" -> Some(UserNavigate(SlideDown))
      "Enter" -> focused_item |> option.map(UserPickedChoice)
      _ -> None
    }

    message
    |> option.map(decode.success)
    |> option.lazy_unwrap(fn() {
      decode.failure(UserNavigate(SlideUp), "SlideDir")
    })
  })
}

fn build_li_elements(
  choices: List(Item),
  settled_item: Option(Item),
  focused_index: Int,
) -> List(#(String, Element(Message))) {
  choices
  |> list.index_map(fn(item, i) {
    let click_handler = ev.on("click", decode.success(UserPickedChoice(item)))
    let indicator = case settled_item {
      Some(x) if x == item -> "✓ "
      _ -> ""
    }
    let is_focused = case focused_index {
      fi if fi > 0 && fi == i + 1 -> True
      _ -> False
    }
    #(
      int.to_string(item.code),
      h.li([a.role("option")], [
        h.button(
          [
            a.classes([
              #(class_choice_button, True),
              #(class_focused_choice, is_focused),
              #(class_unfocused_choice, !is_focused),
            ]),
            click_handler,
          ],
          [
            h.text(indicator <> item.name),
          ],
        ),
      ]),
    )
  })
}

/// Scroll the focused list item into view if it is out of the scrollable container.
fn scroll_to_see_focused_item(combobox_id: String, focused_index: Int) {
  // The focused_index is 1-based, so we return early if it is <= 0
  use <- bool.guard(focused_index <= 0, effect.none())
  use _dispatch, _root_element <- effect.after_paint

  // Convert focused_index to 0-based.
  let index = focused_index - 1
  let combobox_el = document.get_element_by_id(combobox_id)
  let focused_list_item =
    combobox_el
    |> result.map(query_selector_all(_, "li"))
    |> result.try(array.get(_, index))

  let containers = case combobox_el, focused_list_item {
    Ok(_cb), Ok(li) -> {
      // Find the nearest scrollable ancestor (the dropdown's inner div with overflow-y-auto)
      // li > ul > div.overflow-y-auto
      web_element.parent_element(li)
      |> result.map(web_element.parent_element)
      |> result.flatten
      |> option.from_result
      |> option.map(fn(cont) { #(cont, li) })
    }
    _, _ -> None
  }
  case containers {
    Some(#(container, li)) -> {
      use <- on.true(is_out_of_view(li, container))
      web_element.scroll_into_view(li)
      True
    }
    None -> False
  }
  Nil
}
