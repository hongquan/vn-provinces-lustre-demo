import gleam/json

pub type Ward {
  Ward(name: String, code: Int, province_code: Int)
}

pub fn ward_to_json(ward: Ward) -> json.Json {
  let Ward(name:, code:, ..) = ward
  json.object([
    #("name", json.string(name)),
    #("code", json.int(code)),
  ])
}

// Legacy (pre-2025) ward
pub type SourceWard {
  SourceWard(name: String, code: Int, district_code: Int, province_code: Int)
}
