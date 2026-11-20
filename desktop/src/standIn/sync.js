/**
 * @file The stand-in's sync: what every stand-in backend does for POST
 * /store/sync. It builds the entry of each store asked for from the
 * story's own answers to GET /store/query and GET /store/introspect, so a
 * story names its records and its schema once and both the old routes and
 * the sync answer from them.
 *
 * A story's answer to GET /store/query may carry `git` beside its record
 * or records, which becomes the entry's git state; without it the state is
 * null. A story that rejects GET /store/query with a store's own error, as
 * Desktop rejects a 404, puts that error in the entry. Any other rejection
 * rejects the whole sync, as an unreachable backend does.
 */

import * as api from './api.js';

api.register(routes);

/** The sync's route for one stand-in. */
export function routes() {
  return [['/store/sync', (request, backend) => synced(request, backend)]];
}

/**
 * The answer to POST /store/sync: one entry for each store the body asks
 * for, in the order asked.
 *
 * @param request The request.
 * @param request.options The request's options, whose body is `{root, stores}`.
 * @param backend The stand-in, whose `answer` is the story's own backend call.
 */
async function synced({ options }, backend) {
  const { root, stores } = options.body;
  const entries = await Promise.all(stores.map((asked) => entryOf(backend, root, asked)));
  return { data: { stores: entries } };
}

/**
 * The entry of one store: only that it is unchanged when the stamp asked
 * with is its current stamp, else its content under that stamp. The stamp
 * is the content as JSON.
 *
 * @param backend The stand-in.
 * @param {string} root The project's root.
 * @param {{kind: string, source: string, stamp?: string}} asked The store asked for.
 */
async function entryOf(backend, root, { kind, source, stamp }) {
  const content = await contentOf(backend, new URLSearchParams({ kind, root, source }).toString());
  const current = JSON.stringify(content);
  if (stamp && stamp === current) {
    return { kind, source, stamp, unchanged: true };
  }
  return { kind, source, stamp: current, ...content };
}

/**
 * What an entry says about a store: its records, schema and git state from
 * the story's answers, or the store's own error when the story rejected
 * the query with one.
 *
 * @param backend The stand-in.
 * @param {string} search The store, as the query string of the store routes.
 */
async function contentOf(backend, search) {
  try {
    const { data } = await backend.answer(`/store/query?${search}`);
    const described = await backend.answer(`/store/introspect?${search}`);
    return { records: data.records ?? [data.record], schema: described.data.schema ?? {}, git: data.git ?? null };
  } catch (error) {
    return { error: storeErrorIn(error), git: null };
  }
}

/**
 * The store's own error a rejection carries in its `<status>: <body>`
 * message. Throws the rejection again when it carries none.
 *
 * @param error What the story's backend call rejected with.
 */
function storeErrorIn(error) {
  const message = String(error?.message ?? error);
  const body = parsed(message.slice(message.indexOf('{')));
  if (!Array.isArray(body?.errors)) {
    throw error;
  }
  return body.errors[0];
}

/**
 * The value `text` holds as JSON, or null when it is not JSON.
 *
 * @param {string} text The text.
 */
function parsed(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}
