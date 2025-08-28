import filepath
import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import simplifile

import router.{parse_to_route}

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`

pub fn parse_wards_json_test() {
  let assert Ok(dir) = simplifile.current_directory()
  let assert Ok(content) = simplifile.read(filepath.join(dir, "test/hue.json"))
  let ward_decoder = {
    use name <- decode.field("name", decode.string)
    use code <- decode.field("code", decode.int)
    decode.success(#(name, code))
  }
  let decoder = {
    use wards <- decode.field("wards", decode.list(ward_decoder))
    decode.success(wards)
  }
  let resu = json.parse(content, decoder)
  let assert Ok(_a) = resu
}

pub fn parse_query_test() {
  assert parse_to_route([#("p", "1")]) == router.Province(1, None)
  assert parse_to_route([#("p", "1"), #("p", "")]) == router.Province(1, None)
  assert parse_to_route([#("w", "9")]) == router.Home
  assert parse_to_route([#("p", "1"), #("w", "9")])
    == router.Province(1, Some(9))
  assert parse_to_route([#("w", "9"), #("p", "1"), #("w", "1")])
    == router.Province(1, Some(1))
}

pub fn split_string_test() {
  let text = "abc def  ghi"
  let words = string.split(text, " ")
  assert words == ["abc", "def", "", "ghi"]
}
