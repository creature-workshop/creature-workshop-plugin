/**
 * @file How often the pane re-runs the check: the pane_refresh_seconds
 * setting once the backend has answered, and a fixed interval until then.
 * Pane calls refreshMs while rendering.
 */

/** The interval the pane refreshes on until the backend's first answer names one. */
export const REFRESH_UNTIL_ANSWERED_MS = 20000;

/**
 * The refresh interval in milliseconds: the backend's pane_refresh_seconds, once it has answered.
 * @param project The loaded project.
 */
export function refreshMs(project) {
  return typeof project.refresh_seconds === 'number' ? project.refresh_seconds * 1000 : REFRESH_UNTIL_ANSWERED_MS;
}
