/**
 * @file What a part of the pane reads for one file: the snapshot the last
 * sync answered, with the writes the backend has not confirmed yet applied
 * on top, as remote data. The view is computed and never stored as the
 * truth, so nothing is ever merged: once the backend answers a write, the
 * snapshot holds its answer and the write is no longer applied.
 */

import { LOADING } from '../../remote.js';

/** What each operation on one key does to a record's values. */
const CHANGES = Object.freeze({ set: withKey, clear: withNull, reset: withoutKey });

/**
 * The view of one file, as remote.js describes remote data:
 *
 * - loading, while no sync has answered for the file;
 * - failure, when the sync failed before any answer, or when the backend
 *   answered an error for the file, such as NOT_FOUND for a file that is
 *   not there;
 * - success, with `{records, schema, git}`: the snapshot's records with each
 *   of `operations` applied in order, its schema, and the file's state in
 *   git.
 *
 * A set, a clear and a reset change one key of their record, and a delete
 * removes its record. A create is not applied, because only the
 * backend knows the id the new record takes.
 *
 * @param {import('./opsFileSnapshot.js').OpsFileSnapshot | null} snapshot What the last sync answered, or null before the first.
 * @param {object | null} failure Why the sync failed, as client/api.js flattens an error, or null.
 * @param {import('../../client/store.js').Operation[]} operations The file's writes in flight, oldest first.
 */
export function viewOf(snapshot, failure, operations) {
  if (!snapshot) {
    return failure ? { state: 'failure', error: failure } : LOADING;
  }
  if (snapshot.error) {
    return { state: 'failure', error: snapshot.error };
  }
  return { state: 'success', data: { records: operations.reduce(applied, snapshot.records), schema: snapshot.schema, git: snapshot.git } };
}

/**
 * The records after one operation in flight.
 *
 * @param {object[]} records The records.
 * @param {import('../../client/store.js').Operation} operation The operation.
 */
function applied(records, operation) {
  if (operation.op === 'delete') {
    return records.filter((record) => record.id !== operation.id);
  }
  const change = CHANGES[operation.op];
  if (!change) {
    return records;
  }
  return records.map((record) => (record.id === operation.id ? { ...record, values: change(record.values, operation) } : record));
}

/**
 * The values with the operation's key set to its value.
 *
 * @param {Record<string, unknown>} values The record's values.
 * @param {{key: string, value: unknown}} operation The set.
 */
function withKey(values, { key, value }) {
  return { ...values, [key]: value };
}

/**
 * The values with the operation's key cleared, which reads as null.
 *
 * @param {Record<string, unknown>} values The record's values.
 * @param {{key: string}} operation The clear.
 */
function withNull(values, { key }) {
  return { ...values, [key]: null };
}

/**
 * The values without the operation's key, which reads as untouched.
 *
 * @param {Record<string, unknown>} values The record's values.
 * @param {{key: string}} operation The reset.
 */
function withoutKey(values, { key }) {
  return Object.fromEntries(Object.entries(values).filter(([name]) => name !== key));
}
