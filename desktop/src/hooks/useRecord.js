/**
 * @file The hook that holds one record of a store, as a part of the pane
 * reads and changes it.
 */

import { useCallback, useEffect, useState } from 'react';
import { client } from '../client/index.js';
import { describe } from '../failures/describe.js';
import { dataOr, LOADING, remoteOf } from '../remote.js';

/** What a mutation that met a change made outside the pane says. */
export const STALE_MESSAGE = 'This changed outside the pane. Cancel to see the current value, or save again to replace it.';

/**
 * Queries one record of a store, and again whenever any part of its address
 * or `attempt` changes, dropping an answer that arrives after a change.
 *
 * - `record` is the query's answer as remote data, as remote.js
 *   describes; once it succeeds, its data is `{id, revision, values}`.
 * - `write(change)` mutates one key (`{op, key, value}`) at the record's
 *   revision, keeps the record the store answers, and resolves to null; to
 *   STALE_MESSAGE when the record changed outside the pane, after keeping
 *   the current record, so saving again replaces it; or to the error's
 *   message when the store refused.
 *
 * @param {import('../client/store.js').Address} address Where the record lives.
 * @param {number} [attempt] How many times the caller has asked again; raising it queries again.
 *
 * @returns {{record: object, write: (change: object) => Promise<string | null>}} The record, and the write.
 */
export function useRecord({ kind, root, source, id }, attempt = 0) {
  const [record, setRecord] = useState(LOADING);
  useEffect(askRecord({ kind, root, source, id }, setRecord), [kind, root, source, id, attempt]);
  const write = useCallback(
    (change) => {
      const revision = dataOr(record, { revision: '' }).revision;
      return written(client.mutate({ kind, root, source }, { ...change, id, revision }), setRecord);
    },
    [kind, root, source, id, record],
  );
  return { record, write };
}

/**
 * Queries the record, loading again in place of the one before it.
 *
 * @effect
 * @param {import('../client/store.js').Address} address Where the record lives.
 * @param setRecord Stores the record, as remote data.
 */
function askRecord({ kind, root, source, id }, setRecord) {
  return () => {
    let open = true;
    setRecord(LOADING);
    client.query({ kind, root, source }, { id }).then((result) => open && setRecord(recordOf(result)));
    return () => { open = false; };
  };
}

/**
 * The remote record a query's result stands for: its record on success,
 * and the failure otherwise.
 *
 * @param result The query's result.
 */
function recordOf(result) {
  return result.ok ? { state: 'success', data: result.data.record } : remoteOf(result);
}

/**
 * Keeps the record a mutation answers, its own or the current one when it
 * was stale, and resolves to what the field should say: null,
 * STALE_MESSAGE, or why it failed and what to try.
 *
 * @param {Promise<object>} request The mutation's result.
 * @param setRecord Stores the record, as remote data.
 */
async function written(request, setRecord) {
  const result = await request;
  if (result.ok) {
    setRecord({ state: 'success', data: result.data.record });
    return null;
  }
  if (result.error.code !== 'STALE') {
    return sentenceOf(result.error);
  }
  setRecord({ state: 'success', data: result.error.extensions.record });
  return STALE_MESSAGE;
}

/**
 * Why a save failed and what to try, as one line under the field.
 *
 * @param error The error, as client/api.js flattens it.
 */
function sentenceOf(error) {
  const { why, hint } = describe(error);
  return `${why} ${hint}`;
}
