/**
 * @file Whether the checkout the pane reads has a workshop, as the pane's
 * shared state holds it.
 */

import { useEffect, useState } from 'react';
import { client } from '../client/index.js';
import { LOADING, remoteOf } from '../remote.js';

/**
 * Returns GET /project/setup's answer for `selected` as remote data, loaded
 * each time `selected`, `rest` or `retried` changes; loading while nothing
 * is selected. It is read again every `seconds` without going back to
 * loading, so adding or deleting .ops/config outside the pane shows within
 * that time.
 *
 * @param rest The backend call the client is connected to.
 * @param {string} selected The selected checkout's root, or an empty string.
 * @param {number} retried How many times `setup` has been asked for again.
 * @param {number} seconds How long to wait between quiet reads.
 */
export function useSetup(rest, selected, retried, seconds) {
  const [setup, setSetup] = useState(LOADING);
  useEffect(askSetup(selected, setSetup), [rest, selected, retried]);
  useEffect(rereadSetup(selected, setSetup, seconds), [rest, selected, seconds]);
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

/**
 * Reads GET /project/setup again every `seconds` while a checkout is
 * selected, and stores the answer only when it succeeded with a different
 * state, so a quiet read neither flashes loading nor redraws the pane. A
 * failed quiet read leaves the last answer.
 *
 * @effect
 * @param selected The selected checkout's root, or an empty string.
 * @param setSetup Stores the answer.
 * @param seconds How long to wait between reads.
 */
function rereadSetup(selected, setSetup, seconds) {
  return () => {
    if (!selected) {
      return undefined;
    }
    let open = true;
    const keep = (result) => open && result.ok && setSetup((before) => changedSetup(before, result.data));
    const timer = setInterval(() => client.setup(selected).then(keep), seconds * 1000);
    return () => {
      open = false;
      clearInterval(timer);
    };
  };
}

/**
 * The stored setup after a quiet read answered `data`: the same object when
 * the state has not changed, else the new answer.
 *
 * @param before The stored setup, as remote data.
 * @param data GET /project/setup's answer.
 */
function changedSetup(before, data) {
  return before.state === 'success' && before.data.state === data.state ? before : remoteOf({ ok: true, data });
}
