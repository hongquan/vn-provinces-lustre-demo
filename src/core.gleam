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
  ApiReturnedProvinces(Result(List(Province), rsvp.Error))
  ApiReturnedWards(Result(List(Ward), rsvp.Error))
  OnRouteChange(router.Route)
}
