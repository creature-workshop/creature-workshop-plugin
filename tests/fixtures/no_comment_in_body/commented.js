/** @file Comments inside function bodies. */

/** Adds one. */
export function addOne(value) {
  const next = value + 1;
  return next;
  // unreachable, kept for the test
}

/** Doubles. */
const double = (value) => {
  /* twice */
  return value * 2;
};

export default double;
