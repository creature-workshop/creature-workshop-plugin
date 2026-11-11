/**
 * @file The registry a stand-in backend is built from, for the stories and
 * the tests that mount them: the stand-in's mirror of client/api.js. A
 * story gives `standIn` the answers to the routes the story is about. What
 * every backend does besides, such as keeping each session's selection, is
 * registered here once, by a module beside this file, and every stand-in
 * has it. So a story names only what it is about, and a behaviour
 * registered later reaches every story with no change to any of them.
 */

/** Every registered behaviour: a function that makes its routes for one stand-in. */
const behaviours = [];

/**
 * Registers a behaviour every stand-in has from now on.
 *
 *   register(() => [['/selection', (request, backend) => selectionFor(request, backend)]]);
 *
 * @param routesFor Makes the behaviour's routes for one stand-in, with a
 * state of their own: a list of `[prefix, answer]`, where `answer` takes
 * the request, `{path, options}`, and the stand-in, `{rest, answer}`, and
 * returns the body.
 */
export function register(routesFor) {
  behaviours.push(routesFor);
}

/**
 * A backend call for a story or a test: the registered behaviours answer
 * the paths that start with their prefixes, and `answer` answers every
 * other path.
 *
 *   const rest = standIn(async (path) => (path.startsWith('/about') ? ABOUT : NO_REPOS));
 *
 * @param answer The story's own backend call, `(path, options) => body`.
 */
export function standIn(answer) {
  const backend = { answer };
  const routes = behaviours.flatMap((routesFor) => routesFor());
  backend.rest = async (path, options) => {
    const route = routes.find(([prefix]) => path.startsWith(prefix));
    return route ? route[1]({ path, options }, backend) : answer(path, options);
  };
  return backend.rest;
}
