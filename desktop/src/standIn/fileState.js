/**
 * @file The stand-in's file state: what every stand-in backend answers GET
 * /repos/file-state. A story's folder is not a repository, so git has
 * nothing to say about any file in it, and the state is `none`.
 */

import * as api from './api.js';

api.register(routes);

/** The file state's route for one stand-in. */
export function routes() {
  return [['/repos/file-state', (request) => fileState(request)]];
}

/**
 * The answer to GET /repos/file-state: the root and the path asked about,
 * and the state `none`.
 *
 * @param request The request.
 * @param {string} request.path The path asked for, with its query.
 */
function fileState({ path }) {
  const asked = new URLSearchParams(path.slice(path.indexOf('?') + 1));
  return { root: asked.get('root'), path: asked.get('path'), state: 'none' };
}
