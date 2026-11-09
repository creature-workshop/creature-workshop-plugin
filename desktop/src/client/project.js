/**
 * @file The client's call for the shellops project a folder belongs to:
 * GET /project.
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
 * The answer to GET /project when the call failed: no project.
 *
 * @param folder The folder that was asked about.
 */
function noProject(folder) {
  return { found: false, start: folder || '', refresh_seconds: 20 };
}
