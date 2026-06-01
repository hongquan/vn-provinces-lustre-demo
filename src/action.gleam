import common.{type Message}
import gleam/dynamic/decode
import gleam/int
import gleam/string
import gleam/uri
import lustre/effect.{type Effect}
import rsvp

import mytype/province.{Province}
import mytype/ward.{SourceWard, Ward}

const base_url = "https://provinces.open-api.vn/api"

pub fn load_provinces() -> Effect(Message) {
  let url = "https://provinces.open-api.vn/api/v2/p/"
  let decoder = {
    use name <- decode.field("name", decode.string)
    use code <- decode.field("code", decode.int)
    decode.success(Province(name, code))
  }
  let handler =
    rsvp.expect_json(decode.list(decoder), common.ApiReturnedProvinces)
  rsvp.get(url, handler)
}

pub fn search_provinces(search: String) -> Effect(Message) {
  let url =
    "https://provinces.open-api.vn/api/v2/p/?{}"
    |> string.replace("{}", uri.query_to_string([#("search", search)]))
  let decoder = {
    use name <- decode.field("name", decode.string)
    use code <- decode.field("code", decode.int)
    decode.success(Province(name, code))
  }
  let handler =
    rsvp.expect_json(decode.list(decoder), common.ApiReturnedSearchedProvinces)
  rsvp.get(url, handler)
}

pub fn search_wards(search: String, province_code: Int) -> Effect(Message) {
  let url =
    "https://provinces.open-api.vn/api/v2/w/?{}"
    |> string.replace(
      "{}",
      uri.query_to_string([
        #("search", search),
        #("province", int.to_string(province_code)),
      ]),
    )
  let decoder = {
    use name <- decode.field("name", decode.string)
    use code <- decode.field("code", decode.int)
    use province_code <- decode.field("province_code", decode.int)
    decode.success(Ward(name, code, province_code))
  }
  let handler =
    rsvp.expect_json(decode.list(decoder), common.ApiReturnedSearchedWards)
  rsvp.get(url, handler)
}

pub fn load_wards(p: Int) -> Effect(Message) {
  let url =
    "https://provinces.open-api.vn/api/v2/p/" <> int.to_string(p) <> "?depth=2"
  let ward_decoder = {
    use name <- decode.field("name", decode.string)
    use code <- decode.field("code", decode.int)
    decode.success(Ward(name, code, p))
  }
  let decoder = {
    use wards <- decode.field("wards", decode.list(ward_decoder))
    decode.success(wards)
  }
  let handler = rsvp.expect_json(decoder, common.ApiReturnedWards)
  rsvp.get(url, handler)
}

pub fn load_legacy_ward_sources(w: Int) {
  let url = base_url <> "/v2/w/" <> int.to_string(w) <> "/to-legacies/"
  // This API will return a list of legacy wards
  let ward_decoder = {
    use name <- decode.field("name", decode.string)
    use code <- decode.field("code", decode.int)
    use district_code <- decode.field("district_code", decode.int)
    use province_code <- decode.field("province_code", decode.int)
    decode.success(SourceWard(name, code, district_code, province_code))
  }
  let decoder = decode.list(ward_decoder)
  let handler = rsvp.expect_json(decoder, common.ApiReturnedSourceWards)
  rsvp.get(url, handler)
}
