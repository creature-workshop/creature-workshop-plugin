/**
 * @file How far the checkout the pane reads is set up for shellops, as the
 * pane's shared state holds it.
 */

import { useEffect, useState } from 'react';
import { client } from '../client/index.js';
import { LOADING, remoteOf } from '../remote.js';

/**
 * Returns GET /project/setup's answer for `selected` as remote data, loaded
 * each time `selected`, `rest` or `retried` changes; loading while nothing
 * is selected.
 *
 * @param rest The backend call the client is connected to.
 * @param {string} selected The selected checkout's root, or an empty string.
 * @param {number} retried How many times `setup` has been asked for again.
 */
export function useSetup(rest, selected, retried) {
  const [setup, setSetup] = useState(LOADING);
  useEffect(askSetup(selected, setSetup), [rest, selected, retried]);
  return setup;
}

/**
 * Loads `setup` from GET /project/setup for the selected checkout. It stays
 * loading while no checkout is selected. An answer that arrives after the
 * selection changes is dropped.
 *
 * @effect
 * @param selected The selected checkout's root, or an empty string.
 * @param setSetup Stores the answer.
 */
function askSetup(selected, setSetup) {
  return () => {
    let open = true;
    setSetup(LOADING);
    if (selected) {
      client.setup(selected).then((result) => open && setSetup(remoteOf(result)));
    }
    return () => { open = false; };
  };
}
