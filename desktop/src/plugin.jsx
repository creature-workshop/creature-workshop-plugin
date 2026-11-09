/**
 * @file The entry point of the plugin's Desktop side: the one file Desktop
 * loads, through the bundle built from it, and that bundle's only entry. It
 * registers the pane with the SDK. The tree under desktop/src is pane/, the
 * pane and its test, about/, what the pane loads about the plugin, and
 * events.js, the names Hermes and the plugin agree on. This is the source;
 * shell/actions/hermes/build writes desktop/plugin.js from it, which is what
 * Desktop loads.
 */

import { PLUGIN_ID } from './events.js';
import { WorkshopPane } from './pane/WorkshopPane.jsx';

/** The plugin as Desktop loads it: its id, its name and its register hook. */
export default {
  id: PLUGIN_ID,
  name: 'Creature Workshop',
  /**
   * Registers the pane.
   *
   * @param ctx The plugin context the SDK hands over.
   */
  register(ctx) {
    ctx.register({
      id: 'pane',
      area: 'panes',
      title: 'Workshop',
      data: { placement: 'right', width: '340px' },
      render: () => <WorkshopPane rest={(path) => ctx.rest(path)} />,
    });
  },
};
