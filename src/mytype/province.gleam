import gleam/json

pub type Province {
  Province(name: String, code: Int)
}

pub fn province_to_json(province: Province) -> json.Json {
  let Province(name:, code:) = province
  json.object([
    #("name", json.string(name)),
    #("code", json.int(code)),
  ])
}

// Legacy (pre-2025) province
pub type LeProvince {
  LeProvince(name: String, code: Int)
}

// Legacy (pre-2025) district
pub type LeDistrict {
  LeDistrict(name: String, code: Int, province_code: Int)
}
