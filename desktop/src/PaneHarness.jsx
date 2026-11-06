/**
 * @file The pane and the chip as one component with plain data for props, for
 * the Playwright tests. Playwright serialises props on their way into the
 * browser, so the test hands over the project the backend would answer with,
 * and the harness turns it into the store, the backend call, the timer and
 * the settings subscription that Pane and Chip take. The refresh timer never
 * fires; the harness shows the interval it was last scheduled with.
 */
import { useState } from 'react';
import { Chip } from './Chip.jsx';
import { Pane } from './Pane.jsx';
import { createStore } from './store.js';

/**
 * The pane and the chip over one backend answer.
 * @param props The component's props.
 * @param props.project The project the backend answers with.
 * @param props.cwd The session's directory.
 */
export function PaneHarness({ project, cwd }) {
  const [store] = useState(createStore);
  const [scheduledMs, setScheduledMs] = useState(null);
  const rest = async () => project;
  const every = (fn, ms) => {
    setScheduledMs(ms);
    return () => {};
  };
  const whenSettingsChange = () => () => {};
  return (
    <div>
      <div data-testid="status-bar"><Chip store={store} /></div>
      <div data-testid="refresh">{scheduledMs === null ? '' : `every ${scheduledMs} ms`}</div>
      <Pane store={store} cwd={cwd} rest={rest} every={every} whenSettingsChange={whenSettingsChange} />
    </div>
  );
}
