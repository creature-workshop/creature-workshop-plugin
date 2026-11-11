/**
 * @file The names the pane and Hermes agree on, and how the pane listens
 * for Hermes's events. The plugin's id is defined here once and referenced
 * by name. Hermes names a plugin's events `plugin.<id>.<event>`, so an
 * event the pane listens for is defined beside it. `listenWith` names how
 * events reach the pane, once for its whole life: Desktop's `ctx.onEvent`
 * in the plugin, and a stand-in in a story or a test. Until it is called,
 * nothing is listened to, which is how a story or a test without events runs.
 */

/** The plugin's id, the one plugin.yaml and dashboard/manifest.json declare. */
export const PLUGIN_ID = 'creature-workshop';

/**
 * The event the backend sends when the checkout a session is on changed,
 * whoever changed it: the user in a pane, or the agent.
 */
export const SELECTION_CHANGED = `plugin.${PLUGIN_ID}.selection.changed`;

/** How the pane listens for an event, until listenWith names another way: it listens to nothing. */
let listen = () => () => {};

/**
 * Names how the pane listens for Hermes's events from now on.
 *
 * @param onEvent Takes an event's name and a listener, and returns what stops the listening.
 */
export function listenWith(onEvent) {
  listen = onEvent;
}

/**
 * Calls `listener` each time the checkout a session is on changed.
 *
 * @param {() => void} listener What to call.
 *
 * @returns {() => void} What stops the listening.
 */
export function onSelectionChanged(listener) {
  return listen(SELECTION_CHANGED, () => listener());
}
