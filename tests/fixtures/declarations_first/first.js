/** @file Constants first, then the functions, then the export. */

/** The limit. */
const LIMIT = 3;

/** A name per limit. */
export const NAMES = ['a', 'b', 'c'];

/** Adds the limit. */
export function addLimit(value) {
  return value + LIMIT;
}

/** The rule object, which is an export and not a constant. */
export default { addLimit, names: NAMES };
