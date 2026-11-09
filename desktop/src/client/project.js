/**
 * @file The client's calls for the shellops project a folder belongs to:
 * GET /project, and POST /project/manifest, which changes one field of its
 * manifest.
 */

import * as api from './api.js';

/**
 * The shellops project at or above a folder, as GET /project answers; with
 * `check` false it leaves the toolchain out, and when the call failed it
 * answers that no project was found.
 */
export const project = api.register(
  'project',
  (rest, folder, check = true) => rest(`/project?path=${encodeURIComponent(folder || '')}&check=${check ? '1' : '0'}`),
  noProject,
);

/**
 * Sets one field of the manifest of the project rooted at `root`.
 * Answers the project as it reads after the change, or `{error}` with the
 * reason when the change was refused or the call failed.
 */
export const changeManifest = api.register(
  'changeManifest',
  (rest, root, key, value) => rest('/project/manifest', { method: 'POST', body: { root, key, value } }),
  unchanged,
);

/**
 * The answer to GET /project when the call failed: no project.
 *
 * @param folder The folder that was asked about.
 */
function noProject(folder) {
  return { found: false, start: folder || '', refresh_seconds: 20 };
}

/**
 * The answer to POST /project/manifest when the call failed.
 */
function unchanged() {
  return { error: 'The change could not be saved.' };
}
