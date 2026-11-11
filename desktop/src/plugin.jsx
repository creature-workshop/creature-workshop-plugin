/**
 * @file The entry point of the plugin's Desktop side: the one file Desktop
 * loads, through the bundle built from it, and that bundle's only entry. It
 * registers the pane with the SDK. The tree under desktop/src is pane/, the
 * pane, its parts and its tests; workshop/, the state the pane shares;
 * client/, the backend's routes; hooks/, the hooks the parts share, such as
 * polling the backend; repos/, how a repository's state reads; tabs/, the
 * Workshop tabs, one folder each; wizard/,
 * the contract every wizard implementation fills and the one Wizard the
 * pane renders; standIn/, the backend the stories and tests run against;
 * and events.js, the names Hermes and the plugin agree on and how the pane
 * listens for its events.
 * This is the source; shell/actions/hermes/bundle writes desktop/plugin.js
 * from it, which is what Desktop loads.
 */

import { listenWith, PLUGIN_ID } from './events.js';
import { SessionPane } from './pane/SessionPane.jsx';

/** The plugin as Desktop loads it: its id, its name and its register hook. */
export default {
  id: PLUGIN_ID,
  name: 'Creature Workshop',
  /**
   * Registers the pane, with one backend call for its whole life, so the
   * pane's effects that depend on it run once and not on every render, and
   * names Desktop's event stream as the way the pane listens for events.
   *
   * @param ctx The plugin context the SDK hands over.
   */
  register(ctx) {
    const rest = (path, options) => ctx.rest(path, options);
    listenWith((type, listener) => ctx.onEvent(type, listener));
    ctx.register({
      id: 'pane',
      area: 'panes',
      title: 'Workshop',
      data: { placement: 'right', width: '340px' },
      render: () => <SessionPane rest={rest} />,
    });
  },
};
