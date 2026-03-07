import gleam/option.{type Option, None}
import iv.{type Array}

pub type SlideDir {
  SlideUp
  SlideDown
}

pub type ComboboxState(obj) {
  ComboboxState(
    is_shown: Bool,
    filter_text: String,
    filtered_items: Array(obj),
    // Used when the province value has been settled from combobox.
    selected_item: Option(obj),
    // 1-based index of the item to focus when navigating with keyboard.
    // Zero means no one is focused.
    focused_index: Int,
  )
}

pub fn create_empty_combobox_state() -> ComboboxState(obj) {
  ComboboxState(False, "", iv.new(), None, 0)
}
