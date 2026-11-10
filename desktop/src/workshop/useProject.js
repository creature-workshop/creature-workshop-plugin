/**
 * @file The shellops project of the checkout the pane reads, as the pane's
 * shared state holds it.
 */

import { useEffect, useState } from 'react';
import { client } from '../client/index.js';
import { LOADING, remoteOf } from '../remote.js';

/**
 * Returns GET /project's answer for `selected` as remote data, loaded each
 * time `selected`, `rest` or `retried` changes; loading while nothing is
 * selected.
 *
 * @param rest The backend call the client is connected to.
 * @param {string} selected The selected checkout's root, or an empty string.
 * @param {number} retried How many times `project` has been asked for again.
 */
export function useProject(rest, selected, retried) {
  const [project, setProject] = useState(LOADING);
  useEffect(askProject(selected, setProject), [rest, selected, retried]);
  return project;
}

/**
 * Loads `project` from GET /project for the selected checkout, without
 * the toolchain check. It stays loading while no repository is selected.
 * An answer that arrives after the selection changes is dropped.
 *
 * @effect
 * @param selected The selected checkout's root, or an empty string.
 * @param setProject Stores the answer.
 */
function askProject(selected, setProject) {
  return () => {
    let open = true;
    setProject(LOADING);
    if (selected) {
      client.project(selected, false).then((result) => open && setProject(remoteOf(result)));
    }
    return () => { open = false; };
  };
}
