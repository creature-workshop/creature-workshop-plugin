/**
 * @file A snapshot: one file under the checkout's .ops/ folder, such as
 * `.ops/config/manifest.yaml`, as the pane last read it. The pane keeps one
 * snapshot for each file a part follows, and replaces it on each read.
 * address.js describes these files as an OpsFile. This module says what a
 * snapshot has in it, how the backend's three answers about a file make
 * one, and how a confirmed write changes it before the next read.
 */

/**
 * One file as the pane last read it: every record in the file with the
 * schema that describes them, or the backend's error in their place, and
 * the state of the file in git.
 *
 *     {kind: 'document', source: 'config/manifest.yaml', records: [{id: 'document', revision: 'r1', values: {name: 'Notes'}}], schema: {type: 'object'}, git: 'modified'}
 *
 * @typedef {object} OpsFileSnapshot
 * @property {string} kind The file's kind, such as `document`.
 * @property {string} source The file's source, such as `config/manifest.yaml`.
 * @property {object[]} [records] Every record, each `{id, revision, values}`.
 * @property {object} [schema] The JSON Schema that describes the records.
 * @property {object} [error] The backend's error for the file, as client/api.js flattens one, in place of the records and the schema.
 * @property {string | null} git `clean`, `modified`, `new`, `deleted` or `conflict`; null when git has nothing to say about the file.
 */

/** What GET /repos/file-state answers for a file git has nothing to say about. */
const NO_STATE = 'none';

/**
 * The snapshot of a file, from the backend's three answers about it. A file
 * the backend answered with an error, such as NOT_FOUND for a file that is
 * not there, has that error in place of its records and schema.
 *
 *     snapshotFrom({kind: 'document', source: 'config/manifest.yaml'}, {
 *       queried: {ok: true, data: {records: [{id: 'document', revision: 'r1', values: {}}]}},
 *       described: {ok: true, data: {schema: {type: 'object'}}},
 *       state: {ok: true, data: {state: 'modified'}},
 *     })
 *       ->  {kind: 'document', source: 'config/manifest.yaml', records: [{id: 'document', revision: 'r1', values: {}}], schema: {type: 'object'}, git: 'modified'}
 *
 * @param {import('./address.js').OpsFile} file The file.
 * @param answers The results of the three calls, as client/api.js answers one.
 * @param answers.queried The result of GET /file/query with no id.
 * @param answers.described The result of GET /file/introspect.
 * @param answers.state The result of GET /repos/file-state.
 */
export function snapshotFrom({ kind, source }, { queried, described, state }) {
  return { kind, source, ...heldBy(queried, described), git: gitOf(state) };
}

/**
 * The revision the snapshot holds for the record `id`, or an empty string when
 * there is no snapshot yet or it holds no such record.
 *
 * @param {OpsFileSnapshot | null} snapshot The snapshot.
 * @param {string} [id] The record's id.
 */
export function revisionOf(snapshot, id) {
  return snapshot?.records?.find((record) => record.id === id)?.revision ?? '';
}

/**
 * The snapshot after the backend confirmed a write: with the record the write
 * answered in place of the one it held, or added when it held none, or
 * without the record a delete removed. A snapshot that holds no records, and
 * no snapshot, stay as they are.
 *
 *     afterWrite({records: [{id: 'document', revision: 'r1', values: {}}], git: 'clean'}, {record: {id: 'document', revision: 'r2', values: {name: 'Notes'}}})
 *       ->  {records: [{id: 'document', revision: 'r2', values: {name: 'Notes'}}], git: 'clean'}
 *
 * @param {OpsFileSnapshot | null} snapshot The snapshot.
 * @param {{record?: object, deleted?: {id: string}}} data What the write answered.
 */
export function afterWrite(snapshot, data) {
  if (!snapshot?.records) {
    return snapshot;
  }
  const records = data.deleted ? without(snapshot.records, data.deleted.id) : withRecord(snapshot.records, data.record);
  return { ...snapshot, records };
}

/**
 * The records without the one `id` names.
 *
 * @param {object[]} records The records.
 * @param {string} id The record to leave out.
 */
function without(records, id) {
  return records.filter((each) => each.id !== id);
}

/**
 * The records with `record` in the place of the one that has its id, or at
 * the end when none has.
 *
 * @param {object[]} records The records.
 * @param {{id: string}} record The record to keep.
 */
function withRecord(records, record) {
  if (!records.some((each) => each.id === record.id)) {
    return [...records, record];
  }
  return records.map((each) => (each.id === record.id ? record : each));
}

/**
 * What a file holds, from the backend's two answers about it: its records
 * and its schema, or the first error the backend answered.
 *
 * @param queried The result of GET /file/query with no id.
 * @param described The result of GET /file/introspect.
 */
function heldBy(queried, described) {
  const failed = [queried, described].find((each) => !each.ok);
  if (failed) {
    return { error: failed.error };
  }
  return { records: queried.data.records, schema: described.data.schema ?? {} };
}

/**
 * The state of a file in git, from GET /repos/file-state's result:
 * the state it names, or null when it names none or the call failed.
 *
 * @param state The result of GET /repos/file-state.
 */
function gitOf(state) {
  if (!state.ok || state.data.state === NO_STATE) {
    return null;
  }
  return state.data.state;
}
