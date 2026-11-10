/**
 * @file The client's calls for shellops projects: GET /project, the project
 * a folder belongs to, and GET /project/setup, how far one checkout is set
 * up.
 */

import * as api from './api.js';

/**
 * The shellops project at or above a folder, as GET /project answers; with
 * `check` false it leaves the toolchain out.
 */
export const project = api.register(
  'project',
  (rest, folder, check = true) => rest(`/project?path=${encodeURIComponent(folder || '')}&check=${check ? '1' : '0'}`),
);

/** How far the checkout at a root is set up for shellops, as GET /project/setup answers. */
export const setup = api.register('setup', (rest, root) => rest(`/project/setup?root=${encodeURIComponent(root)}`));
