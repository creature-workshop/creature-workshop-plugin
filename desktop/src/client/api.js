/**
 * @file The registry the backend's client is built from. Each route module
 * beside this file registers its calls here, and `client` gathers every
 * registered call under its name, so any part of the app imports `client`
 * and calls the backend without knowing how a call reaches it. `connect`
 * names the backend call every registered call goes through: the plugin's
 * `ctx.rest` in Desktop, and a stand-in in a story or a test.
 *
 * A failed request becomes a failure, which the call's fallback is given,
 * shaped the way a GraphQL server answers an error. Desktop rejects an
 * answer whose status is 400 or more with an Error whose message is
 * `<status>: <body>`; when the body carries errors, the failure is that
 * body, so the backend's reason reaches the pane:
 *
 *   {
 *     "data": null,
 *     "errors": [{
 *       "message": "org cannot be removed: the schema requires it.",
 *       "extensions": { "code": "REFUSED", "status": 400 }
 *     }]
 *   }
 *
 * Any other failure, such as a backend that cannot be reached, is the same
 * shape with the code UNREACHABLE, the status 0, and the error's message.
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
 * Registers a call: the request it makes, and the answer it gives instead
 * when the request fails, whether the request throws at once or rejects
 * later, so a part of the pane draws nothing rather than breaking. A
 * fallback that is a function is given the failure, then the call's own
 * arguments.
 *
 *   export const about = register('about', (rest) => rest('/about'), NO_ABOUT);
 *   client.about()  ->  {version: '0.1.0-dev.9', branch: 'main'}
 *
 * @param name The name the call takes in `client`.
 * @param request A function of the backend call and the call's own arguments that makes the request.
 * @param fallback The answer when the request fails, or a function of the failure and the call's arguments that gives it.
 *
 * @returns The call, which is also `client[name]`.
 */
export function register(name, request, fallback) {
  const call = (...args) => answered(request, fallback, args);
  client[name] = call;
  return call;
}

/**
 * Makes the request with the call's arguments, and answers what it answers,
 * or what fallback gives for its failure.
 *
 * @param request A function of the backend call and the call's own arguments that makes the request.
 * @param fallback The answer when the request fails, or a function of the failure and the call's arguments that gives it.
 * @param {unknown[]} args The call's arguments.
 */
async function answered(request, fallback, args) {
  try {
    return await request(backend, ...args);
  } catch (error) {
    return fallbackFor(fallback, failureOf(error), args);
  }
}

/**
 * The answer for a failed call: the fallback itself, or what it gives for the failure and the call's arguments.
 *
 * @param fallback The answer, or a function of the failure and the call's arguments that gives it.
 * @param failure The failure.
 * @param args The call's arguments.
 */
function fallbackFor(fallback, failure, args) {
  return typeof fallback === 'function' ? fallback(failure, ...args) : fallback;
}

/**
 * The failure an error stands for: the body with errors in its
 * `<status>: <body>` message, or UNREACHABLE with the message.
 *
 * @param error What the request threw or rejected with.
 */
function failureOf(error) {
  const message = String(error?.message ?? error);
  return errorsIn(message) ?? unreachable(message);
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
 * The failure of a request that never reached the backend, or whose answer
 * carried no errors.
 *
 * @param {string} message The error's message.
 */
function unreachable(message) {
  return { data: null, errors: [{ message, extensions: { code: 'UNREACHABLE', status: 0 } }] };
}
