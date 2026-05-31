/**
 * @param {Element} element
 * @param {string} selector
 * @returns {Element[]}
 */
export function querySelectorAll(element, selector) {
  return Array.from(element.querySelectorAll(selector));
}

/**
 * @param {Element} element
 * @returns {boolean}
 */
export function checkVisibility(element) {
  return element.checkVisibility()
}

/**
 * @param {Element} element
 * @param {Element} scrolledContainer
 * @returns {boolean}
 */
export function isOutOfView(element, scrolledContainer) {
  const elmRec = element.getBoundingClientRect()
  const conRec = scrolledContainer.getBoundingClientRect()
  // console.info('elmRec ', elmRec)
  // console.info('conRec ', conRec)
  const relYOffset = elmRec.top - conRec.top
  // console.info('relYOffset ', relYOffset )
  const isBelow = scrolledContainer.clientHeight <= relYOffset + elmRec.height
  const isAbove = relYOffset < 0
  return isBelow || isAbove
}

/**
 * @param {ShadowRoot | Element} root
 * @param {() => void} callback
 * @returns {void}
 */
export function addOutsideClickListener(root, callback) {
  // `root` is the component's ShadowRoot (Lustre passes the shadow root to
  // after_paint for components), or a plain Element for non-component apps.
  // We need the host element because, for any click inside the component,
  // composedPath() contains the host — letting us distinguish inside vs outside
  // across the shadow boundary (event.target alone is retargeted to the host).
  const host = root instanceof ShadowRoot ? root.host : root;
  document.addEventListener("click", (event) => {
    if (!event.composedPath().includes(host)) {
      callback();
    }
  });
}
