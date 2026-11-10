/**
 * @file The client's calls for the stores the inspector reads and writes
 * data through, named and shaped after GraphQL's operations so that a
 * GraphQL client can replace them later: `introspect` (GET
 * /store/introspect), `query` (GET /store/query) and `mutate` (POST
 * /store/mutate). A place names the store's kind, the project's root, and
 * what the store reads there, such as `config/manifest.yaml` for the `file`
 * store.
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
 * Where records live: the store's kind, the project's root, and what the
 * store reads there.
 *
 * @typedef {object} Place
 * @property {string} kind The store's kind, such as `file`.
 * @property {string} root The project's root.
 * @property {string} source What the store reads, such as `config/manifest.yaml`.
 */

/**
 * Where one record lives: its place, and its id.
 *
 * @typedef {Place & {id: string}} Address
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

/** The JSON Schema of the records at a place: `{data: {schema}}`. */
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
 * @param {Place} place Where the records live.
 */
function askIntrospect(rest, place) {
  return rest(`/store/introspect?${search(placeOf(place))}`);
}

/**
 * GET /store/query.
 *
 * @param rest The backend call.
 * @param {Place} place Where the records live.
 * @param {Selection} [selection] Which record, and the revision the caller has.
 */
function askQuery(rest, place, { id = '', revision = '' } = {}) {
  return rest(`/store/query?${search({ ...placeOf(place), id, revision })}`);
}

/**
 * POST /store/mutate.
 *
 * @param rest The backend call.
 * @param {Place} place Where the records live.
 * @param {Operation} operation The operation.
 */
function askMutate(rest, place, operation) {
  const body = { ...placeOf(place), ...operation };
  return rest('/store/mutate', { method: 'POST', body });
}

/**
 * The fields of a place the routes take, and nothing else.
 *
 * @param {Place} place The place.
 */
function placeOf({ kind, root, source }) {
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
