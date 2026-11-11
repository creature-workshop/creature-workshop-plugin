/**
 * @file The shellops project of the checkout the pane reads, as the pane's
 * shared state holds it.
 */

import { useEffect, useState } from 'react';
import { client } from '../client/index.js';
import { LOADING, remoteOf } from '../remote.js';
import { changed } from './changed.js';

/**
 * Returns GET /project's answer for `selected` as remote data, loaded each
 * time `selected`, `rest` or `retried` changes; loading while nothing is
 * selected. It is read again every `seconds` without going back to
 * loading, so a change to the project's declaration made outside the pane
 * shows within that time.
 *
 * @param rest The backend call the client is connected to.
 * @param {string} selected The selected checkout's root, or an empty string.
 * @param {number} retried How many times `project` has been asked for again.
 * @param {number} seconds How long to wait between quiet reads.
 */
export function useProject(rest, selected, retried, seconds) {
  const [project, setProject] = useState(LOADING);
  useEffect(askProject(selected, setProject), [rest, selected, retried]);
  useEffect(rereadProject(selected, setProject, seconds), [rest, selected, seconds]);
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

/**
 * Reads GET /project again every `seconds` while a checkout is selected,
 * without the toolchain check, and stores the answer only when it
 * succeeded and differs, so a quiet read neither flashes loading nor
 * redraws the pane. A failed quiet read leaves the last answer.
 *
 * @effect
 * @param selected The selected checkout's root, or an empty string.
 * @param setProject Stores the answer.
 * @param seconds How long to wait between reads.
 */
function rereadProject(selected, setProject, seconds) {
  return () => {
    if (!selected) {
      return undefined;
    }
    let open = true;
    const keep = (result) => open && result.ok && setProject((before) => changed(before, result.data));
    const timer = setInterval(() => client.project(selected, false).then(keep), seconds * 1000);
    return () => {
      open = false;
      clearInterval(timer);
    };
  };
}
