import gleam/int
import gleam/list
import gleam/option.{type Option, None}
import gleam/result
import gleam/string

// URL
pub type Route {
  Home
  // The first member is province code, the second is ward code.
  Province(Int, Option(Int))
}

/// Parse query string like "p=12&w=456" and return a Route value.
/// Find province first. If no province is found, the "ward" is ignored.
/// Last valid value takes predecence, for example, "w=123&w=456" gives Ward(456).
pub fn parse_to_route(query: List(#(String, String))) -> Route {
  let query = list.reverse(query)
  let value =
    query
    |> list.find_map(fn(q) {
      case q {
        #("p", value) -> {
          use value <- result.try(int.parse(string.trim(value)))
          Ok(Province(value, None))
        }
        _ -> Error(Nil)
      }
    })
  case value {
    Error(_v) -> Home
    Ok(Province(p, None)) -> {
      let w =
        query
        |> list.find_map(fn(q) {
          case q {
            #("w", value) -> int.parse(string.trim(value))
            _ -> Error(Nil)
          }
        })
        |> option.from_result
      Province(p, w)
    }
    Ok(r) -> r
  }
}
