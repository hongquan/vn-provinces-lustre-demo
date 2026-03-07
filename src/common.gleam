import rsvp

import router.{type Route}
import types/core.{type ComboboxState}
import types/province.{type Province} as p
import types/ward.{type Ward} as w

pub type Model {
  Model(
    route: Route,
    provinces: List(Province),
    wards: List(Ward),
    // For province combobox
    province_combobox_state: ComboboxState(Province),
    ward_combobox_state: ComboboxState(Ward),
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
  // This is the API response for all provinces
  ApiReturnedProvinces(Result(List(Province), rsvp.Error))
  // This is the API response for searched provinces
  ApiReturnedSearchedProvinces(Result(List(Province), rsvp.Error))
  ApiReturnedWards(Result(List(Ward), rsvp.Error))
  ApiReturnedSearchedWards(Result(List(Ward), rsvp.Error))
  OnRouteChange(router.Route)
  UserClickedOutside(OutsideObject)
}
