import rsvp

import mytype/core.{type ComboboxState}
import mytype/province.{type Province} as p
import mytype/ward.{type SourceWard, type Ward} as w
import router.{type Route}

pub type Model {
  Model(
    route: Route,
    provinces: List(Province),
    wards: List(Ward),
    // For province non-component combobox
    province_combobox_state: ComboboxState(Province),
    ward_combobox_state: ComboboxState(Ward),
    // For province combobox
    selected_province_code: Int,
    source_wards: List(SourceWard),
  )
}

pub type OutsideObject {
  OutBoth
  OutProvince
  OutWard
}

pub type Msg {
  PCombobox(p.ComboboxMsg)
  WCombobox(w.ComboboxMsg)
  UserFocusedProvinceCbx
  // User selected a province from the combobox component
  UserSelectedProvince(Int)
  // This is the API response for all provinces
  ApiReturnedProvinces(Result(List(Province), rsvp.Error(String)))
  // This is the API response for searched provinces
  ApiReturnedSearchedProvinces(Result(List(Province), rsvp.Error(String)))
  ApiReturnedWards(Result(List(Ward), rsvp.Error(String)))
  ApiReturnedSourceWards(Result(List(SourceWard), rsvp.Error(String)))
  ApiReturnedSearchedWards(Result(List(Ward), rsvp.Error(String)))
  OnRouteChange(router.Route)
  UserClickedOutside(OutsideObject)
}
