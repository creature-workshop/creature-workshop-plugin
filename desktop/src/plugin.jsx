/**
 * @file Creature Workshop in Hermes Desktop: registers the pane and the
 * status chip with the SDK. The tree under desktop/src is one folder per
 * surface Desktop registers, pane/ and chip/, plus project/, the loaded
 * project both of them read, and events.js, the names Hermes and the plugin
 * agree on. This is the source; shell/actions/hermes/build writes
 * desktop/plugin.js from it, which is what Desktop loads.
 */
import { ToolchainChip } from './chip/ToolchainChip.jsx';
import { PLUGIN_ID } from './events.js';
import { PaneBoundary } from './pane/PaneBoundary.jsx';
import { SessionPane } from './pane/SessionPane.jsx';
import { createStore } from './project/store.js';

/** The plugin as Desktop loads it: its id, its name and its register hook. */
export default {
  id: PLUGIN_ID,
  name: 'Creature Workshop',
  /**
   * Registers the pane and the chip, sharing one store between them.
   * @param ctx The plugin context the SDK hands over.
   */
  register(ctx) {
    const store = createStore();
    ctx.register({
      id: 'pane',
      area: 'panes',
      title: 'Creature Workshop',
      data: { placement: 'right', width: '340px' },
      render: () => <PaneBoundary><SessionPane ctx={ctx} store={store} /></PaneBoundary>,
    });
    ctx.register({
      id: 'chip',
      area: 'statusBar.right',
      order: 125,
      render: () => <ToolchainChip store={store} />,
    });
  },
};
