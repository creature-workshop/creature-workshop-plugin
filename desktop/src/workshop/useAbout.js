/**
 * @file The plugin's version and branch, as the pane's shared state holds
 * them.
 */

import { useEffect, useState } from 'react';
import { client } from '../client/index.js';
import { LOADING, remoteOf } from '../remote.js';

/**
 * Returns GET /about's answer as remote data, loaded once and again each
 * time `rest` or `retried` changes.
 *
 * @param rest The backend call the client is connected to.
 * @param {number} retried How many times `about` has been asked for again.
 */
export function useAbout(rest, retried) {
  const [about, setAbout] = useState(LOADING);
  useEffect(askAbout(setAbout), [rest, retried]);
  return about;
}

/**
 * Loads `about` from GET /about.
 *
 * @effect
 * @param setAbout Stores the answer.
 */
function askAbout(setAbout) {
  return () => {
    let open = true;
    setAbout(LOADING);
    client.about().then((result) => open && setAbout(remoteOf(result)));
    return () => { open = false; };
  };
}
