/**
 * @file What the pane says about a checkout that is not set up for shellops,
 * for each state GET /project/setup answers other than ready.
 */

/** The message for each state that is not ready, by state. */
const MESSAGES = Object.freeze({
  'no-workshop': noWorkshop,
  'not-set-up': notSetUp,
});

/**
 * What to say about the checkout named `name` in `state`: what is missing,
 * and why or what to do about it; null when the checkout is ready.
 *
 *     setupMessage('no-workshop', 'notes')  ->  { what: "notes doesn't have a workshop yet.", ... }
 *
 * @param {'no-workshop' | 'not-set-up' | 'ready'} state How far the checkout is set up.
 * @param {string} name The checkout's folder name.
 *
 * @returns {{what: string, why: string, code?: string} | null} The message; `code` is a command the message names.
 */
export function setupMessage(state, name) {
  return MESSAGES[state]?.(name) ?? null;
}

/**
 * The message for a checkout whose branch has no .ops/config.
 *
 * @param {string} name The checkout's folder name.
 */
function noWorkshop(name) {
  return {
    what: `${name} doesn't have a workshop yet.`,
    why: "Its branch has no .ops/config, so there's nothing here for me to show. Another branch may have one.",
  };
}

/**
 * The message for a checkout whose branch has a workshop that this checkout has not set up.
 *
 * @param {string} name The checkout's folder name.
 */
function notSetUp(name) {
  return {
    what: `${name} isn't set up yet.`,
    why: "Its branch has a workshop, but this checkout doesn't have shellops yet. To set it up, run this in it:",
    code: '.ops/boot',
  };
}
