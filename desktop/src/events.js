/**
 * @file The names the pane and Hermes agree on: the plugin's id, and the
 * events the pane listens for, each defined here once and referenced by
 * name. Hermes names a plugin's events `plugin.<id>.<event>`.
 */

/** The plugin's id, the one plugin.yaml and dashboard/manifest.json declare. */
export const PLUGIN_ID = 'creature-workshop';

/** Broadcast by Hermes when the plugin's settings are saved, from any surface. */
export const SETTINGS_CHANGED = `plugin.${PLUGIN_ID}.settings.changed`;
