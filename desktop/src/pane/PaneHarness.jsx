/**
 * @file The pane with plain data for props, for the Playwright tests.
 * Playwright serialises props on their way into the browser, so a test hands
 * over the answer the backend would give, and the harness turns it into the
 * backend call WorkshopPane takes.
 */

import { useCallback } from 'react';
import { WorkshopPane } from './WorkshopPane.jsx';

/**
 * The pane over the backend's answers.
 *
 * @param props The component's props.
 * @param props.about The answer the backend gives to GET /about.
 * @param props.width The pane's width in pixels, 320 unless given, the way Desktop sizes it.
 */
export function PaneHarness({ about, width = 320 }) {
  const rest = useCallback(async () => about, [about]);
  return (
    <div className="workshop-harness" style={{ width, height: 200, display: 'flex', flexDirection: 'column' }}>
      <WorkshopPane rest={rest} />
    </div>
  );
}
