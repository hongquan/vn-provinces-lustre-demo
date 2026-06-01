import gleam/option.{type Option}

import rsvp

import mytype/province.{type Province}
import mytype/ward.{type SourceWard, type Ward}
import router.{type Route}

pub type Model {
  Model(
    route: Route,
    provinces: List(Province),
    filtered_provinces: List(Province),
    wards: List(Ward),
    filtered_wards: List(Ward),
    selected_province: Option(Province),
    selected_ward: Option(Ward),
    source_wards: List(SourceWard),
  )
}

pub type Message {
  // For combobox component.
  UserFocusedProvinceCbx
  UserTextInputProvince(String)
  UserSelectedProvince(Int)
  UserClickedClearOnProvinceCbx
  UserFocusedWardCbx
  UserTextInputWard(String)
  UserSelectedWard(Int)
  UserClickedClearOnWardCbx
  // This is the API response for all provinces
  ApiReturnedProvinces(Result(List(Province), rsvp.Error(String)))
  // This is the API response for searched provinces
  ApiReturnedSearchedProvinces(Result(List(Province), rsvp.Error(String)))
  ApiReturnedWards(Result(List(Ward), rsvp.Error(String)))
  ApiReturnedSourceWards(Result(List(SourceWard), rsvp.Error(String)))
  ApiReturnedSearchedWards(Result(List(Ward), rsvp.Error(String)))
  OnRouteChange(router.Route)
}
