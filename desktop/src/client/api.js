/**
 * @file The registry the backend's client is built from. Each route module
 * beside this file registers its calls here, and `client` gathers every
 * registered call under its name, so any part of the app imports `client`
 * and calls the backend without knowing how a call reaches it. `connect`
 * names the backend call every registered call goes through: the plugin's
 * `ctx.rest` in Desktop, and a stand-in in a story or a test.
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
 * later, so a part of the pane draws nothing rather than breaking.
 *
 *   export const about = register('about', (rest) => rest('/about'), NO_ABOUT);
 *   client.about()  ->  {version: '0.1.0-dev.9', branch: 'main'}
 *
 * @param name The name the call takes in `client`.
 * @param request A function of the backend call and the call's own arguments that makes the request.
 * @param fallback The answer when the request fails, or a function of the call's arguments that gives it.
 *
 * @returns The call, which is also `client[name]`.
 */
export function register(name, request, fallback) {
  const call = (...args) => answerOr(() => request(backend, ...args), () => fallbackFor(fallback, args));
  client[name] = call;
  return call;
}

/**
 * What a request answers, or what fallback gives when it fails.
 *
 * @param request A function that makes the request.
 * @param fallback A function that gives the answer for a failed request.
 */
async function answerOr(request, fallback) {
  try {
    return await request();
  } catch {
    return fallback();
  }
}

/**
 * The answer for a failed call: the fallback itself, or what it gives for the call's arguments.
 *
 * @param fallback The answer, or a function of the call's arguments that gives it.
 * @param args The call's arguments.
 */
function fallbackFor(fallback, args) {
  return typeof fallback === 'function' ? fallback(...args) : fallback;
}
