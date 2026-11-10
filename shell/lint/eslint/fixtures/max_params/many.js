/**
 * @file Functions past the limit: a declaration with six parameters, and an
 * arrow function with five and a rest parameter.
 */

/**
 * Six parameters.
 *
 * @param kind The store's kind.
 * @param root The project's root.
 * @param source What the store reads.
 * @param id The record's id.
 * @param revision The revision.
 * @param change The change.
 */
export function write(kind, root, source, id, revision, change) {
  return [kind, root, source, id, revision, change];
}

/**
 * Five parameters and a rest parameter.
 *
 * @param kind The store's kind.
 * @param root The project's root.
 * @param source What the store reads.
 * @param id The record's id.
 * @param revision The revision.
 * @param {...unknown} rest The rest.
 */
export const call = (kind, root, source, id, revision, ...rest) => [kind, root, source, id, revision, rest];
