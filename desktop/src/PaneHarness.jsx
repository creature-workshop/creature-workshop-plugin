/**
 * @file The pane and the chip as one component with plain data for props, for
 * the Playwright tests. Playwright serialises props on their way into the
 * browser, so the test hands over the project the backend would answer with,
 * and the harness turns it into the store, the backend call and the timer
 * that Pane and Chip take. The refresh timer never fires.
 */
import { Chip } from './Chip.jsx';
import { Pane } from './Pane.jsx';
import { createStore } from './store.js';

export function PaneHarness({ project, cwd }) {
  const store = createStore();
  const rest = async () => project;
  const every = () => () => {};
  return (
    <div>
      <div data-testid="status-bar"><Chip store={store} /></div>
      <Pane store={store} cwd={cwd} rest={rest} every={every} />
    </div>
  );
}
