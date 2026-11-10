/**
 * @file The hook that holds one record of a store, as a part of the pane
 * reads and changes it.
 */

import { useCallback, useEffect, useState } from 'react';
import { client } from '../client/index.js';

/** What a mutation that met a change made outside the pane says. */
export const STALE_MESSAGE = 'This changed outside the pane. Cancel to see the current value, or save again to replace it.';

/**
 * Queries one record of a store, and again whenever any part of its address
 * changes, dropping an answer that arrives after a change.
 *
 * - `record` is null until the first answer, then `{id, revision, values}`.
 * - `failure` is the error of a query that failed (`{message, extensions}`),
 *   or null.
 * - `write(change)` mutates one key (`{op, key, value}`) at the record's
 *   revision, keeps the record the store answers, and resolves to null; to
 *   STALE_MESSAGE when the record changed outside the pane, after keeping
 *   the current record, so saving again replaces it; or to the error's
 *   message when the store refused.
 *
 * @param {import('../client/store.js').Address} address Where the record lives.
 *
 * @returns {{record: object | null, failure: object | null, write: (change: object) => Promise<string | null>}} The record, a failed query, and the write.
 */
export function useRecord({ kind, root, source, id }) {
  const [record, setRecord] = useState(null);
  const [failure, setFailure] = useState(null);
  useEffect(askRecord({ kind, root, source, id }, { setRecord, setFailure }), [kind, root, source, id]);
  const write = useCallback(
    (change) => {
      const request = client.mutate({ kind, root, source }, { ...change, id, revision: record?.revision ?? '' });
      return written(request, setRecord);
    },
    [kind, root, source, id, record],
  );
  return { record, failure, write };
}

/**
 * Queries the record, clearing the one before it.
 *
 * @effect
 * @param {import('../client/store.js').Address} address Where the record lives.
 * @param {{setRecord: (record: object | null) => void, setFailure: (error: object | null) => void}} setters Store the record, or the error.
 */
function askRecord({ kind, root, source, id }, { setRecord, setFailure }) {
  return () => {
    let open = true;
    setRecord(null);
    setFailure(null);
    client.query({ kind, root, source }, { id }).then((answer) => open && keep(answer, { setRecord, setFailure }));
    return () => { open = false; };
  };
}

/**
 * Keeps a query's record, or its error.
 *
 * @param answer The answer: `{data: {record}}` or `{data: null, errors}`.
 * @param {{setRecord: (record: object | null) => void, setFailure: (error: object | null) => void}} setters Store the record, or the error.
 */
function keep(answer, { setRecord, setFailure }) {
  if (answer.data?.record) {
    setRecord(answer.data.record);
    return;
  }
  setFailure(answer.errors?.[0] ?? null);
}

/**
 * Keeps the record a mutation answers, its own or the current one when it
 * was stale, and resolves to what the field should say: null,
 * STALE_MESSAGE, or the error's message.
 *
 * @param {Promise<object>} request The mutation.
 * @param setRecord Stores the record.
 */
async function written(request, setRecord) {
  const answer = await request;
  if (answer.data?.record) {
    setRecord(answer.data.record);
    return null;
  }
  const error = answer.errors?.[0];
  if (error?.extensions?.code !== 'STALE') {
    return error?.message ?? null;
  }
  setRecord(error.extensions.record);
  return STALE_MESSAGE;
}
