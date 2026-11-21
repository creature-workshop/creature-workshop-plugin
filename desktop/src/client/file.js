/**
 * @file The client's calls for the files under a project's .ops/ folder
 * that the pane reads and writes as records, named and shaped after
 * GraphQL's operations so that a GraphQL client can replace them later:
 * `introspect` (GET /file/introspect), `query` (GET /file/query) and
 * `mutate` (POST /file/mutate). Each call names one file of one project,
 * such as `config/manifest.yaml` in the selected repository, and its kind,
 * which says how the backend reads the file as records.
 *
 * Every call answers a result, as api.js describes, and never throws. The
 * backend answers a query with the record:
 *
 *   {
 *     "data": {
 *       "record": {
 *         "id": "document",
 *         "revision": "b90d221a...",
 *         "values": { "name": "Notes" }
 *       }
 *     }
 *   }
 *
 * so the result is `{ok: true, data: {record}}`. When the backend refuses or
 * fails, the result's error carries the backend's code, and anything the
 * backend sent with it in `extensions`, such as the current record of a
 * stale mutation:
 *
 *   {
 *     "ok": false,
 *     "error": {
 *       "message": "The document changed since it was read.",
 *       "code": "STALE",
 *       "status": 409,
 *       "extensions": { "record": { "id": "document", "revision": "...", "values": {} } }
 *     }
 *   }
 */

import * as api from './api.js';

/**
 * One file under a project's .ops/ folder, read as records.
 *
 * @typedef {object} ProjectFile
 * @property {string} kind How the backend reads the file as records: `document` or `plan`.
 * @property {string} root The project's root folder.
 * @property {string} source The file's path under .ops/, such as `config/manifest.yaml`.
 */

/**
 * Where one record is: its file, and its id.
 *
 * @typedef {ProjectFile & {id: string}} Address
 */

/**
 * What a query asks for: one record by id, with the revision the caller
 * has if any; or, with no id, every record.
 *
 * @typedef {object} Selection
 * @property {string} [id] The record's id.
 * @property {string} [revision] The revision the caller has.
 */

/**
 * A set: `key` takes `value` in the record `id` read at `revision`.
 *
 * @typedef {{op: 'set', id: string, revision: string, key: string, value: unknown}} SetOperation
 */

/**
 * A clear or a reset of `key` in the record `id` read at `revision`: a clear
 * leaves it null, a reset leaves it absent.
 *
 * @typedef {{op: 'clear' | 'reset', id: string, revision: string, key: string}} KeyOperation
 */

/**
 * A create: a new record holding `values`.
 *
 * @typedef {{op: 'create', values: Record<string, unknown>}} CreateOperation
 */

/**
 * A delete of the record `id` read at `revision`.
 *
 * @typedef {{op: 'delete', id: string, revision: string}} DeleteOperation
 */

/**
 * One operation of a mutation, told apart by `op`.
 *
 * @typedef {SetOperation | KeyOperation | CreateOperation | DeleteOperation} Operation
 */

/** The JSON Schema that describes a file's records: a result whose data is `{schema}`. */
export const introspect = api.register('introspect', askIntrospect);

/**
 * One record (data `{record}`), or every record (data `{records}`) when the
 * selection names no id. A selection with the record's current revision
 * fails with the code UNCHANGED.
 */
export const query = api.register('query', askQuery);

/**
 * One operation: the record after a set, clear or reset, or a create (data
 * `{record}`); the id of a deleted record (data `{deleted}`); or a failure
 * with the code STALE, whose extensions carry the current record, when it
 * changed since the operation's revision.
 */
export const mutate = api.register('mutate', askMutate);

/**
 * GET /file/introspect.
 *
 * @param rest The backend call.
 * @param {ProjectFile} file The file.
 */
function askIntrospect(rest, file) {
  return rest(`/file/introspect?${search(fileOf(file))}`);
}

/**
 * GET /file/query.
 *
 * @param rest The backend call.
 * @param {ProjectFile} file The file.
 * @param {Selection} [selection] Which record, and the revision the caller has.
 */
function askQuery(rest, file, { id = '', revision = '' } = {}) {
  return rest(`/file/query?${search({ ...fileOf(file), id, revision })}`);
}

/**
 * POST /file/mutate.
 *
 * @param rest The backend call.
 * @param {ProjectFile} file The file.
 * @param {Operation} operation The operation.
 */
function askMutate(rest, file, operation) {
  const body = { ...fileOf(file), ...operation };
  return rest('/file/mutate', { method: 'POST', body });
}

/**
 * The fields of a file the routes take, and nothing else.
 *
 * @param {ProjectFile} file The file.
 */
function fileOf({ kind, root, source }) {
  return { kind, root, source };
}

/**
 * A URL query string from the entries of `params`.
 *
 * @param {Record<string, string>} params The parameters.
 */
function search(params) {
  return new URLSearchParams(params).toString();
}
