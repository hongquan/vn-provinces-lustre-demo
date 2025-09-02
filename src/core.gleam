import gleam/option.{type Option, None}
import rsvp

import router

pub type Province {
  Province(name: String, code: Int)
}

pub type Ward {
  Ward(name: String, code: Int, province_code: Int)
}

pub type OutsideObject {
  OutBoth
  OutProvince
  OutWard
}

pub type SlideDir {
  SlideUp
  SlideDown
}

pub type Msg {
  ProvinceComboboxFocused
  ProvinceComboboxClearClick
  ProvinceComboboxTextInput(String)
  ProvinceComboboxSlide(SlideDir)
  ProvinceComboboxSelected(Province)
  WardComboboxFocused
  WardComboboxClearClick
  WardComboboxTextInput(String)
  WardComboboxSlide(SlideDir)
  WardComboboxSelected(Ward)
  // This is the API response for all provinces
  ApiReturnedProvinces(Result(List(Province), rsvp.Error))
  // This is the API response for searched provinces
  ApiReturnedSearchedProvinces(Result(List(Province), rsvp.Error))
  ApiReturnedWards(Result(List(Ward), rsvp.Error))
  ApiReturnedSearchedWards(Result(List(Ward), rsvp.Error))
  OnRouteChange(router.Route)
  UserClickedOutside(OutsideObject)
}

pub type ComboboxState(obj) {
  ComboboxState(
    is_shown: Bool,
    filter_text: String,
    filtered_items: List(obj),
    // Used when the province value has been settled from combobox.
    selected_item: Option(obj),
    // Index of the item to focus when navigating with keyboard
    focused_index: Int,
  )
}

pub fn create_empty_combobox_state() -> ComboboxState(obj) {
  ComboboxState(False, "", [], None, 0)
}
