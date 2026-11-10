/**
 * @file Functions within the limit: five parameters, an options object, and a rest parameter.
 */

/**
 * Five parameters.
 *
 * @param kind The store's kind.
 * @param root The project's root.
 * @param source What the store reads.
 * @param id The record's id.
 * @param revision The revision.
 */
export function place(kind, root, source, id, revision) {
  return [kind, root, source, id, revision];
}

/**
 * An options object and a change.
 *
 * @param address Where the record lives.
 * @param change The change.
 */
export const write = (address, change) => ({ ...address, ...change });

/**
 * One named parameter and the rest.
 *
 * @param first The first.
 * @param {...unknown} rest The rest.
 */
export function gather(first, ...rest) {
  return [first, ...rest];
}
