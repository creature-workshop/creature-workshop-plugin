/**
 * @file The client's calls for git repositories: GET /repos, the
 * repositories a folder holds, and GET /repos/status, the state of one.
 */

import * as api from './api.js';

/** The repositories a folder holds, as GET /repos answers. */
export const repos = api.register('repos', (rest, folder) => rest(`/repos?path=${encodeURIComponent(folder || '')}`));

/** The state of the repository at a root, as GET /repos/status answers. */
export const repoStatus = api.register('repoStatus', (rest, root) => rest(`/repos/status?root=${encodeURIComponent(root)}`));
