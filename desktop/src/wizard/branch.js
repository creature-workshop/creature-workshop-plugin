/**
 * @file Where a wizard goes after a step, the way blizz's Branch says it in
 * Rust: on to the next step, to the step with a given id, or to the end.
 */

/** Go on to the step after this one, or finish after the last. */
export const NEXT = Object.freeze({ kind: 'next' });

/** End the wizard here, with the answers given so far. */
export const FINISH = Object.freeze({ kind: 'finish' });

/**
 * Go to the step whose id is `id`, earlier or later in the list. A review
 * step uses it to send the user back to a section.
 *
 * @param {string} id The id a step was given with `withId`.
 *
 * @returns {{kind: 'jump', id: string}} The branch.
 */
export function jumpTo(id) {
  return Object.freeze({ kind: 'jump', id });
}
