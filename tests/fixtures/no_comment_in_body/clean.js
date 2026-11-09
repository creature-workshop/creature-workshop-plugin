/** @file Comments above declarations, and a directive inside a body. */

/** Adds one. */
export function addOne(value) {
  // eslint-disable-next-line no-console -- the one place the file prints
  console.log(value);
  return value + 1;
}

/** Doubles. */
const double = (value) => value * 2;

export default double;
