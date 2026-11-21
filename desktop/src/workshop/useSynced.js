/**
 * @file The synced files of the checkout the pane reads, as the pane's
 * shared state holds them.
 */

import { useEffect, useMemo } from 'react';
import { client } from '../client/index.js';
import { readFiles } from './synced/read.js';
import { create } from './synced/synced.js';

/**
 * Returns the synced files of `selected`, as synced/synced.js describes
 * them: new ones each time `selected` or `rest` changes, read again every
 * `seconds` for as long as a checkout is selected. With nothing selected
 * they hold nothing and read nothing.
 *
 * @param rest The backend call the client is connected to.
 * @param {string} selected The selected checkout's root, or an empty string.
 * @param {number} seconds How long to wait between reads.
 */
export function useSynced(rest, selected, seconds) {
  const synced = useMemo(() => create({ root: selected, sync: syncThroughClient, mutate: mutateThroughClient }), [rest, selected]);
  useEffect(readOnTimer(synced, selected, seconds), [synced, selected, seconds]);
  return synced;
}

/**
 * Reads the followed files every `seconds` while a checkout is selected,
 * until the files, the checkout or the interval changes.
 *
 * @effect
 * @param synced The synced files.
 * @param {string} selected The selected checkout's root, or an empty string.
 * @param {number} seconds How long to wait between reads.
 */
function readOnTimer(synced, selected, seconds) {
  return () => {
    if (!selected) {
      return undefined;
    }
    return synced.every(seconds);
  };
}

/**
 * Reads the files named into snapshots, through the client as it is
 * connected when the call is made.
 *
 * @param {string} root The checkout's root.
 * @param {object[]} files The files to read.
 */
function syncThroughClient(root, files) {
  return readFiles(client, root, files);
}

/**
 * POST /store/mutate through the client as it is connected when the call
 * is made.
 *
 * @param {object} file The file to write to.
 * @param {object} operation The operation.
 */
function mutateThroughClient(file, operation) {
  return client.mutate(file, operation);
}
