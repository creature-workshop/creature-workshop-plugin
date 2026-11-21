/**
 * @file What a write that the backend did not keep says to the user, as one
 * line under the field that made it.
 */

import { describe } from '../../failures/describe.js';

/** What a write that met a change made outside the pane says. */
export const STALE_MESSAGE = 'This changed outside the pane. Cancel to see the current value, or save again to replace it.';

/**
 * Why a write failed and what to try, in one line.
 *
 * @param error The error, as client/api.js flattens it.
 */
export function failureMessage(error) {
  const { why, hint } = describe(error);
  return `${why} ${hint}`;
}
