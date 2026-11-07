/**
 * @file The pane and the chip as one component with plain data for props, for
 * the Playwright tests. Playwright serialises props on their way into the
 * browser, so the test hands over the answer the backend would give, and the
 * harness turns it into the store, the backend call, the timer and the
 * settings subscription that WorkshopPane and ToolchainChip take. The timer is a real
 * setInterval, and when the test gives a second answer, `later`, the backend
 * gives it to every call after the first, so a test can watch the pane
 * change on its refresh.
 */

import { useRef, useState } from 'react';
import { ToolchainChip } from '../chip/ToolchainChip.jsx';
import { createStore } from '../project/store.js';
import { WorkshopPane } from './WorkshopPane.jsx';

/**
 * Schedules a function on an interval and returns the function that stops it.
 * @param fn What to run.
 * @param ms The interval in milliseconds.
 */
function every(fn, ms) {
  const id = setInterval(fn, ms);
  return () => clearInterval(id);
}

/**
 * The pane and the chip over the backend's answers.
 * @param props The component's props.
 * @param props.answer The answer the backend gives to the first call.
 * @param props.later The answer the backend gives to every call after the first; the first again when absent.
 * @param props.cwd The session's directory.
 */
export function PaneHarness({ answer, later, cwd }) {
  const [store] = useState(createStore);
  const calls = useRef(0);
  const rest = async () => {
    calls.current += 1;
    return calls.current === 1 ? answer : later || answer;
  };
  const whenSettingsChange = () => () => {};
  return (
    <div className="workshop-harness">
      <ToolchainChip store={store} />
      <WorkshopPane store={store} cwd={cwd} rest={rest} every={every} whenSettingsChange={whenSettingsChange} />
    </div>
  );
}
