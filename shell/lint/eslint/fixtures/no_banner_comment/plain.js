/** @file Ordinary comments: a doc block, a directive, a note with a dash in it. */

/**
 * Adds one.
 * @param value The number - any number.
 */
export function addOne(value) {
  // eslint-disable-next-line no-console -- the one place the file prints
  console.log(value);
  return value + 1;
}
