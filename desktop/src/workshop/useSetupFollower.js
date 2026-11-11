/**
 * @file Keeping the pane's project in step with its checkout's setup, when
 * a workshop is added or deleted outside the pane.
 */

import { useEffect, useRef } from 'react';

/**
 * Asks for `project` again whenever the setup state of the selected
 * checkout changes from one known state to another, as when .ops/ is
 * deleted or added outside the pane. The first state read for a checkout,
 * and a change of checkout, ask for nothing, since `project` loads for a
 * new checkout on its own.
 *
 * @param {string} selected The selected checkout's root, or an empty string.
 * @param setup GET /project/setup's answer, as remote data.
 * @param {(name: string) => void} retry Asks for one of the pane's remote pieces again.
 */
export function useSetupFollower(selected, setup, retry) {
  const last = useRef({ selected: '', state: '' });
  const state = setup.state === 'success' ? setup.data.state : '';
  useEffect(followSetup(last, { selected, state }, retry), [selected, state, retry]);
}

/**
 * Compares the checkout's setup state with the last one seen for the same
 * checkout, asks for `project` again when both are known and differ, and
 * remembers the current one.
 *
 * @effect
 * @param last The last checkout and setup state seen.
 * @param seen The current checkout and setup state.
 * @param retry Asks for one of the pane's remote pieces again.
 */
function followSetup(last, seen, retry) {
  return () => {
    if (!seen.state) {
      return;
    }
    if (last.current.selected === seen.selected && last.current.state && last.current.state !== seen.state) {
      retry('project');
    }
    last.current = seen;
  };
}
