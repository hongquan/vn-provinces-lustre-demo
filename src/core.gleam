import gleam/option.{type Option}
import rsvp

import router

pub type Province {
  Province(name: String, code: Int)
}

pub type Ward {
  Ward(name: String, code: Int, province_code: Int)
}

pub type Msg {
  ProvinceSelected(Option(Province))
  WardSelected(Option(Ward))
  ProvinceComboboxFocused
  ProvinceComboboxBlur(first: Bool)
  ProvinceComboboxTextInput(String)
  ProvinceComboboxSelected(Province)
  WardComboboxFocused
  WardComboboxBlur(first: Bool)
  WardComboboxTextInput(String)
  WardComboboxSelected(Ward)
  // This is the API response for all provinces
  ApiReturnedProvinces(Result(List(Province), rsvp.Error))
  // This is the API response for searched provinces
  ApiReturnedSearchedProvinces(Result(List(Province), rsvp.Error))
  ApiReturnedWards(Result(List(Ward), rsvp.Error))
  OnRouteChange(router.Route)
}
