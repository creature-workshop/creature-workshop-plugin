/**
 * @file The registry the backend's client is built from. Each route module
 * beside this file registers its calls here, and `client` gathers every
 * registered call under its name, so any part of the app imports `client`
 * and calls the backend without knowing how a call reaches it. `connect`
 * names the backend call every registered call goes through: the plugin's
 * `ctx.rest` in Desktop, and a stand-in in a story or a test.
 *
 * Every call answers a result, as Elm's Http does, and never throws: either
 * `{ok: true, data}`, or `{ok: false, error}`, so every caller handles the
 * failure as a value. The backend answers a failure the way a GraphQL server
 * answers an error, and the result's error is that error, flattened:
 *   {message: "No repository at /tmp/gone.", code: "NOT_FOUND", status: 404, extensions: {...}}
 * Desktop rejects an answer whose status is 400 or more with an Error whose
 * message is `<status>: <body>`, and the error is read from that body. A
 * rejection whose body carries no errors is NO_ROUTE when its status is 404,
 * since the plugin's own routes always carry errors, and UNREACHABLE
 * otherwise.
 */

/** Every registered call, by the name it was registered under. */
export const client = {};

/** The backend call the registered calls go through, until connect names another. */
let backend = () => Promise.reject(new Error('the client is not connected to a backend'));

/**
 * Names the backend call every registered call goes through from now on.
 *
 * @param rest The backend call, taking a path under the plugin's API.
 *
 * @returns The client.
 */
export function connect(rest) {
  backend = rest;
  return client;
}

/**
 * Registers a call: the request it makes with the backend call and its own
 * arguments. The call answers the request's result.
 *   export const about = register('about', (rest) => rest('/about'));
 *   await client.about()  ->  {ok: true, data: {version: '0.1.0-dev.9', branch: 'main'}}
 *
 * @param name The name the call takes in `client`.
 * @param request A function of the backend call and the call's own arguments that makes the request.
 *
 * @returns The call, which is also `client[name]`.
 */
export function register(name, request) {
  const call = (...args) => resultOf(request, args);
  client[name] = call;
  return call;
}

/**
 * Makes the request with the call's arguments, and answers its result,
 * whether it resolves, throws at once, or rejects later.
 *
 * @param request A function of the backend call and the call's own arguments that makes the request.
 * @param {unknown[]} args The call's arguments.
 */
async function resultOf(request, args) {
  try {
    return answered(await request(backend, ...args));
  } catch (error) {
    return failed(rejected(error));
  }
}

/**
 * The result of an answer that arrived. A GraphQL-shaped body, which has a
 * `data` key, is a failure when it carries errors, as the store's 3xx
 * outcomes do, and its data otherwise; any other body is the data itself.
 *
 * @param body The answer's body.
 */
function answered(body) {
  if (body === null || typeof body !== 'object' || !('data' in body)) {
    return { ok: true, data: body };
  }
  return Array.isArray(body.errors) && body.errors.length > 0 ? failed(body) : { ok: true, data: body.data };
}

/**
 * The failed result for a body with errors: its first error, flattened.
 *
 * @param body A body with errors.
 */
function failed(body) {
  const [error] = body.errors;
  const extensions = error.extensions ?? {};
  return { ok: false, error: { message: error.message, code: extensions.code, status: extensions.status, extensions } };
}

/**
 * The body a rejection stands for: the one with errors in its
 * `<status>: <body>` message, or one made from the message, NO_ROUTE for a
 * bare 404 and UNREACHABLE for anything else.
 *
 * @param error What the request threw or rejected with.
 */
function rejected(error) {
  const message = String(error?.message ?? error);
  return errorsIn(message) ?? madeFrom(message);
}

/**
 * The body after a message's `<status>: ` prefix when it carries errors, or
 * null when it does not.
 *
 * @param {string} message The error's message.
 */
function errorsIn(message) {
  try {
    const body = JSON.parse(message.slice(message.indexOf('{')));
    return Array.isArray(body?.errors) ? body : null;
  } catch {
    return null;
  }
}

/**
 * The body for a rejection that carried no errors: NO_ROUTE when its
 * message starts with 404, UNREACHABLE otherwise, with the message itself.
 *
 * @param {string} message The error's message.
 */
function madeFrom(message) {
  const status = /^404\b/.test(message) ? 404 : 0;
  const code = status === 404 ? 'NO_ROUTE' : 'UNREACHABLE';
  return { data: null, errors: [{ message, extensions: { code, status } }] };
}
