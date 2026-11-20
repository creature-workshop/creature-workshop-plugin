/**
 * @file The stand-in's record list: what every stand-in backend does for
 * GET /store/query when it names no record. A story answers the query with
 * the one record its store holds, as `{data: {record}}`, whichever way it
 * is asked. The backend answers a query without an id with every record,
 * as `{data: {records}}`, so the stand-in turns the story's one record into
 * that list. A query that names a record, and a story that already answers
 * a list, pass through as they are.
 */

import * as api from './api.js';

api.register(routes);

/** The record list's route for one stand-in. */
export function routes() {
  return [['/store/query', (request, backend) => queried(request, backend)]];
}

/**
 * The story's answer to the query, as a list of records when the query
 * names no record and the story answered one.
 *
 * @param request The request.
 * @param {string} request.path The path asked for, with its query.
 * @param request.options The request's options.
 * @param backend The stand-in, whose `answer` is the story's own backend call.
 */
async function queried({ path, options }, backend) {
  const body = await backend.answer(path, options);
  if (namesRecord(path) || !body?.data?.record) {
    return body;
  }
  const { record, ...rest } = body.data;
  return { ...body, data: { ...rest, records: [record] } };
}

/**
 * Whether the query names one record by its id.
 *
 * @param {string} path The path asked for, with its query.
 */
function namesRecord(path) {
  return Boolean(new URLSearchParams(path.slice(path.indexOf('?') + 1)).get('id'));
}
