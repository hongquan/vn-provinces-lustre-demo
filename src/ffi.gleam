import gleam/javascript/array.{type Array as JSArray}
import plinth/browser/element.{type Element}

@external(javascript, "./element.ffi.mjs", "querySelectorAll")
pub fn query_selector_all(
  element: Element,
  selector: String,
) -> JSArray(Element)

@external(javascript, "./element.ffi.mjs", "checkVisibility")
pub fn check_visibility(element: Element) -> Bool

@external(javascript, "./element.ffi.mjs", "isOutOfView")
pub fn is_out_of_view(element: Element, scrolled_container: Element) -> Bool
