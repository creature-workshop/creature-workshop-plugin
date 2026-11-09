/**
 * @file The client's calls for git repositories: GET /repos, the
 * repositories a folder holds, and GET /repos/status, the state of one.
 */

import * as api from './api.js';

/** How often to read again when GET /repos failed and named no interval, in seconds. */
const DEFAULT_REFRESH_SECONDS = 20;

/** The repositories a folder holds, as GET /repos answers, or none when the call failed. */
export const repos = api.register(
  'repos',
  (rest, folder) => rest(`/repos?path=${encodeURIComponent(folder || '')}`),
  noRepos,
);

/** The state of the repository at a root, as GET /repos/status answers, or one with `ok` false when the call failed. */
export const repoStatus = api.register(
  'repoStatus',
  (rest, root) => rest(`/repos/status?root=${encodeURIComponent(root)}`),
  (root) => ({ root, ok: false }),
);

/**
 * The answer to GET /repos when the call failed: no repositories.
 *
 * @param folder The folder that was asked about.
 */
function noRepos(folder) {
  return { start: folder || '', inside: false, repos: [], refresh_seconds: DEFAULT_REFRESH_SECONDS };
}
