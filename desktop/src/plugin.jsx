/**
 * @file Creature Workshop in Hermes Desktop: registers the pane and the
 * status chip with the SDK. This is the source; shell/actions/hermes/build
 * writes desktop/plugin.js from it, which is what Desktop loads.
 */
import { Chip } from './Chip.jsx';
import { PaneWithSession } from './PaneWithSession.jsx';
import { createStore } from './store.js';

export default {
  id: 'creature-workshop',
  name: 'Creature Workshop',
  register(ctx) {
    const store = createStore();
    ctx.register({
      id: 'pane',
      area: 'panes',
      title: 'Creature Workshop',
      data: { placement: 'right', width: '340px' },
      render: () => <PaneWithSession ctx={ctx} store={store} />,
    });
    ctx.register({
      id: 'chip',
      area: 'statusBar.right',
      order: 125,
      render: () => <Chip store={store} />,
    });
  },
};
