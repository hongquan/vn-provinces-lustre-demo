import gleam/option.{type Option, None}
import rsvp

import router

pub type Province {
  Province(name: String, code: Int)
}

pub type Ward {
  Ward(name: String, code: Int, province_code: Int)
}

pub type Msg {
  ProvinceComboboxFocused
  ProvinceComboboxTextInput(String)
  ProvinceComboboxSelected(Province)
  WardComboboxFocused
  WardComboboxTextInput(String)
  WardComboboxSelected(Ward)
  // This is the API response for all provinces
  ApiReturnedProvinces(Result(List(Province), rsvp.Error))
  // This is the API response for searched provinces
  ApiReturnedSearchedProvinces(Result(List(Province), rsvp.Error))
  ApiReturnedWards(Result(List(Ward), rsvp.Error))
  ApiReturnedSearchedWards(Result(List(Ward), rsvp.Error))
  OnRouteChange(router.Route)
  UserClickedOutside
}

pub type ComboboxState(obj) {
  ComboboxState(
    is_shown: Bool,
    filter_text: String,
    filtered_items: List(obj),
    // Used when the province value has been settled from combobox.
    // If this value is "Some", the text input should not generate message.
    selected_item: Option(obj),
  )
}

pub fn create_empty_combobox_state() -> ComboboxState(obj) {
  ComboboxState(False, "", [], None)
}
