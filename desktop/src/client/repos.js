/**
 * @file The client's calls for git repositories: GET /repos, the
 * repositories a session's folder holds and which of them the session is
 * on; GET /repos/status, the state of one; and GET /repos/file-state, the
 * state of one file in git.
 */

import * as api from './api.js';

/** The repositories a subject's folder holds and what its session is on, as GET /repos answers. */
export const repos = api.register(
  'repos',
  (rest, subject) => rest(`/repos?path=${encodeURIComponent(subject.folder)}&session=${encodeURIComponent(subject.id)}`),
);

/** The state of the repository at a root, as GET /repos/status answers. */
export const repoStatus = api.register('repoStatus', (rest, root) => rest(`/repos/status?root=${encodeURIComponent(root)}`));

/**
 * The state in git of the file at `path`, in the checkout at `root`, as
 * GET /repos/file-state answers: `{root, path, state}`, where `state` is
 * `clean`, `modified`, `new`, `deleted` or `conflict`, or `none` when git
 * has nothing to say about the file.
 */
export const fileState = api.register('fileState', (rest, root, path) => rest(`/repos/file-state?root=${encodeURIComponent(root)}&path=${encodeURIComponent(path)}`));
