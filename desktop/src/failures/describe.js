/**
 * @file What the pane tells the user about a failed call, in the manner of
 * Elm's error messages: what happened, why, and what to try. The caller
 * says what it was doing; this module sorts the failure by whose problem
 * it is and says why it happened and what to try, from the error's code.
 */

import { REPORT_INVITE } from './report.js';

/**
 * The three kinds of failure, by whose problem it is:
 *
 * - `yours`: something the user can fix, such as a refused value;
 * - `passing`: something that may pass if the user tries again;
 * - `bug`: a bug in the Workshop plugin, which the user can report.
 */
export const KINDS = Object.freeze({ yours: 'yours', passing: 'passing', bug: 'bug' });

/**
 * The kind, why and what to try for each code. A `why` of null means the
 * backend's own message says why.
 */
const EXPLAINED = Object.freeze({
  UNREACHABLE: {
    kind: KINDS.passing,
    why: "The Workshop plugin's backend didn't answer. Hermes may still be starting or restarting.",
    hint: 'Give it a few seconds, then try again.',
  },
  NO_ROUTE: {
    kind: KINDS.yours,
    why: "The Workshop plugin's backend doesn't know this request, so it's older than the pane.",
    hint: 'Quit Hermes from the tray and open it again, so both load the same version.',
  },
  INTERNAL: {
    kind: KINDS.bug,
    why: "The Workshop plugin's backend ran into an unexpected bug. This isn't something you did.",
    hint: REPORT_INVITE,
  },
  UNSUPPORTED: {
    kind: KINDS.bug,
    why: null,
    hint: `This is an unexpected bug in the Workshop plugin, not something you did. ${REPORT_INVITE}`,
  },
  NOT_FOUND: {
    kind: KINDS.yours,
    why: null,
    hint: 'Check that it exists in this repository, then try again.',
  },
  REFUSED: {
    kind: KINDS.yours,
    why: null,
    hint: "Change it and save again, or cancel to keep what's there.",
  },
});

/** The kind and hint for a code this module does not know, whose message says why. */
const UNKNOWN = Object.freeze({ kind: KINDS.passing, why: null, hint: 'Try again in a moment.' });

/**
 * Whose problem `error` is, why it happened, and what to try: the
 * explanation for its code, with the error's own message as the why when
 * the code has none.
 *
 * @param error The error, as client/api.js flattens it.
 *
 * @returns {{kind: string, why: string, hint: string}} The explanation.
 */
export function describe(error) {
  const explained = EXPLAINED[error.code] ?? UNKNOWN;
  return { kind: explained.kind, why: explained.why ?? error.message, hint: explained.hint };
}

/**
 * The error's details for the Show details toggle and a report: its code,
 * its status and its raw message, one to a line.
 *
 * @param error The error, as client/api.js flattens it.
 */
export function detailsOf(error) {
  return [`code: ${error.code}`, `status: ${error.status}`, `message: ${error.message}`].join('\n');
}
