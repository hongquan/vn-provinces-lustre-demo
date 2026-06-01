import gleam/dynamic.{type Dynamic}
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

// `root` is the component's ShadowRoot, which Lustre's `effect.after_paint`
// passes as a `Dynamic`. It must NOT be cast to a plinth `Element` first:
// a ShadowRoot is not `instanceof Element`, so the cast would fail and the
// listener would never be registered. The JS side derives the host element.
@external(javascript, "./element.ffi.mjs", "addOutsideClickListener")
pub fn add_outside_click_listener(
  root: Dynamic,
  callback: fn() -> Nil,
) -> Nil
