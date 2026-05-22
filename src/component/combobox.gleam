import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import iv
import lustre
import lustre/attribute.{type Attribute} as a
import lustre/component
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
import lustre/event as ev

pub type Item {
  Item(name: String, code: Int)
}

type Model {
  Model(
    choices: List(Item),
    is_input_focused: Bool,
    filter_text: String,
    // Should be updated to `True` if the input is focused.
    // TODO: Is it duplicate with `is_input_focused`?
    is_list_container_shown: Bool,
    filtered_choices: iv.Array(Item),
    selected_item: Option(Item),
    // 1-based index of the item to focus when navigating with keyboard.
    // Zero means no one is focused.
    focused_index: Int,
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
  UserTypedText(String)
}

// Message that we will emit to parent
pub type EmitMessage {
  Focused
  Selected(Int)
}

const component_name = "combo-box"

const class_input = "border focus-visible:outline-none focus-visible:ring-1 ps-2 pe-6 py-1 w-full rounded"

const class_choice_button = "w-full text-start px-2 py-1.5 rounded cursor-pointer"

const class_indicate_focus = "vn-focus"

const class_focused_choice = "bg-slate-200 dark:bg-slate-600"
  <> " "
  <> class_indicate_focus

const class_unfocused_choice = "hover:bg-neutral-200 dark:hover:bg-neutral-600"

const class_close_button = "absolute end-0 px-2 text-xl hover:text-red-400 focus:text-red-400 hover:dark:text-red-400 cursor-pointer"

const class_dropdown_container = "absolute z-1 top-10 start-0 end-0 sm:-end-4 py-2 ps-2 bg-neutral-50 dark:bg-neutral-800 rounded shadow"

fn default_model() {
  Model([], False, "", False, iv.new(), None, 0)
}

pub fn register() -> Result(Nil, lustre.Error) {
  let component = lustre.component(init, update, view, [])
  lustre.register(component, component_name)
}

pub fn element(attributes: List(Attribute(m))) -> Element(m) {
  element.element(component_name, attributes, [])
}

fn emit(message: EmitMessage) {
  case message {
    Focused -> ev.emit("focused", json.null())
    Selected(code) -> ev.emit("selected", json.int(code))
  }
}

fn init(_: a) -> #(Model, effect.Effect(Message)) {
  #(default_model(), effect.none())
}

fn update(model: Model, message: Message) -> #(Model, effect.Effect(a)) {
  case message {
    UserFocusedInput -> {
      let model =
        Model(..model, is_input_focused: True, is_list_container_shown: True)
      #(model, emit(Focused))
    }
    UserPickedChoice(it) -> {
      let model =
        Model(
          ..model,
          selected_item: Some(it),
          // If an item is picked, close the suggestion list
          is_list_container_shown: False,
        )
      #(model, emit(Selected(it.code)))
    }
    _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Message) {
  let Model(
    choices:,
    filter_text:,
    focused_index:,
    selected_item:,
    is_list_container_shown: to_show_list_container,
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
      a.class(class_input),
      a.role("combobox"),
      a.value(filter_text),
      // Event handlers
      ev.on_focus(UserFocusedInput),
      ev.on_input(UserTypedText) |> ev.debounce(200),
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
        a.classes([#("hidden", !to_show_list_container)]),
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
