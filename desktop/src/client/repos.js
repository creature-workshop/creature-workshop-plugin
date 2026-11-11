/**
 * @file The client's calls for git repositories: GET /repos, the
 * repositories a session's folder holds and which of them the session is
 * on, and GET /repos/status, the state of one.
 */

import * as api from './api.js';

/** The repositories a subject's folder holds and what its session is on, as GET /repos answers. */
export const repos = api.register(
  'repos',
  (rest, subject) => rest(`/repos?path=${encodeURIComponent(subject.folder)}&session=${encodeURIComponent(subject.id)}`),
);

/** The state of the repository at a root, as GET /repos/status answers. */
export const repoStatus = api.register('repoStatus', (rest, root) => rest(`/repos/status?root=${encodeURIComponent(root)}`));
