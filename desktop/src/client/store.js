/**
 * @file The client's calls for the stores the inspector reads and writes
 * data through, named and shaped after GraphQL's operations so that a
 * GraphQL client can replace them later: `introspect` (GET
 * /store/introspect), `query` (GET /store/query) and `mutate` (POST
 * /store/mutate). Each call names a store: the records in one file of one
 * project, kept by a kind of store, such as `config/manifest.yaml` in the
 * selected repository, kept by the `file` kind.
 *
 * Every call answers `{data}` or `{data: null, errors}` and never throws. A
 * query answers the record:
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
 * When the store refuses or fails, the call answers the failure api.js reads
 * from the error, such as a stale mutation with the current record:
 *
 *   {
 *     "data": null,
 *     "errors": [{
 *       "message": "The document changed since it was read.",
 *       "extensions": {
 *         "code": "STALE",
 *         "status": 409,
 *         "record": { "id": "document", "revision": "...", "values": {} }
 *       }
 *     }]
 *   }
 */

import * as api from './api.js';

/**
 * A store: the records in one file of one project.
 *
 * @typedef {object} Store
 * @property {string} kind The kind of store that keeps them, such as `file`.
 * @property {string} root The project's root folder.
 * @property {string} source The file, such as `config/manifest.yaml`.
 */

/**
 * Where one record lives: its store, and its id.
 *
 * @typedef {Store & {id: string}} Address
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

/** The JSON Schema that describes a store's records: `{data: {schema}}`. */
export const introspect = api.register('introspect', askIntrospect, failed);

/**
 * One record (`{data: {record}}`), or every record (`{data: {records}}`)
 * when the selection names no id. A selection with the record's current
 * revision answers the UNCHANGED error.
 */
export const query = api.register('query', askQuery, failed);

/**
 * One operation: the record after a set, clear or reset, or a create
 * (`{data: {record}}`); the id of a deleted record (`{data: {deleted}}`);
 * or the STALE error with the current record when it changed since the
 * operation's revision.
 */
export const mutate = api.register('mutate', askMutate, failed);

/**
 * GET /store/introspect.
 *
 * @param rest The backend call.
 * @param {Store} store The store.
 */
function askIntrospect(rest, store) {
  return rest(`/store/introspect?${search(storeOf(store))}`);
}

/**
 * GET /store/query.
 *
 * @param rest The backend call.
 * @param {Store} store The store.
 * @param {Selection} [selection] Which record, and the revision the caller has.
 */
function askQuery(rest, store, { id = '', revision = '' } = {}) {
  return rest(`/store/query?${search({ ...storeOf(store), id, revision })}`);
}

/**
 * POST /store/mutate.
 *
 * @param rest The backend call.
 * @param {Store} store The store.
 * @param {Operation} operation The operation.
 */
function askMutate(rest, store, operation) {
  const body = { ...storeOf(store), ...operation };
  return rest('/store/mutate', { method: 'POST', body });
}

/**
 * The fields of a store the routes take, and nothing else.
 *
 * @param {Store} store The store.
 */
function storeOf({ kind, root, source }) {
  return { kind, root, source };
}

/**
 * The answer of a failed store call: the failure itself, which is already
 * `{data: null, errors}`.
 *
 * @param failure Why the call failed.
 */
function failed(failure) {
  return failure;
}

/**
 * A URL query string from the entries of `params`.
 *
 * @param {Record<string, string>} params The parameters.
 */
function search(params) {
  return new URLSearchParams(params).toString();
}
