/**
 * @file Creature Workshop in Hermes Desktop: registers the pane and the
 * status chip with the SDK. This is the source; shell/actions/hermes/build
 * writes desktop/plugin.js from it, which is what Desktop loads.
 */
import { Chip } from './Chip.jsx';
import { PLUGIN_ID } from './events.js';
import { PaneBoundary } from './PaneBoundary.jsx';
import { PaneWithSession } from './PaneWithSession.jsx';
import { createStore } from './store.js';

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
      render: () => <PaneBoundary><PaneWithSession ctx={ctx} store={store} /></PaneBoundary>,
    });
    ctx.register({
      id: 'chip',
      area: 'statusBar.right',
      order: 125,
      render: () => <Chip store={store} />,
    });
  },
};
