/**
 * @file What the pane says about a checkout that has no workshop, the one
 * state GET /project/setup answers other than ready.
 */

/** The message for each state that is not ready, by state. */
const MESSAGES = Object.freeze({
  'no-workshop': noWorkshop,
});

/**
 * What to say about the checkout named `name` in `state`: what is missing,
 * and why or what to do about it; null when the checkout is ready.
 *
 *     setupMessage('no-workshop', 'notes')  ->  { what: "notes doesn't have a workshop yet.", ... }
 *
 * @param {'no-workshop' | 'ready'} state Whether the checkout has a workshop.
 * @param {string} name The checkout's folder name.
 *
 * @returns {{what: string, why: string} | null} The message.
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
    why: "Its branch has no .ops/config, so there's nothing here for me to show.",
  };
}
