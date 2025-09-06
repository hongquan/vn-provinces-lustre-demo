export function querySelectorAll(element, selector) {
  return Array.from(element.querySelectorAll(selector));
}

export function checkVisibility(element) {
  return element.checkVisibility()
}

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
