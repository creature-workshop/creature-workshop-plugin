/**
 * @file The client's calls for shellops projects: GET /project, the project
 * a folder belongs to; GET /project/setup, whether one checkout has a
 * workshop;
 * GET /project/adoption, what the adoption form starts with; GET
 * /project/adoption/guess, the agent's guesses for it; POST /project/adopt,
 * which writes a branch's first manifest; and POST /project/approve, which
 * records the user's approval of a project.
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

/** Whether the checkout at a root has a workshop, as GET /project/setup answers. */
export const setup = api.register('setup', (rest, root) => rest(`/project/setup?root=${encodeURIComponent(root)}`));

/** What the adoption form starts with for the checkout at a root, as GET /project/adoption answers. */
export const adoption = api.register('adoption', (rest, root) => rest(`/project/adoption?root=${encodeURIComponent(root)}`));

/** How long the pane waits for the agent's guesses, in milliseconds: the backend's 30-second model call and a margin. */
const GUESS_TIMEOUT_MS = 40_000;

/** The agent's guesses for the adoption form, as GET /project/adoption/guess answers. */
export const adoptionGuess = api.register(
  'adoptionGuess',
  (rest, root) => rest(`/project/adoption/guess?root=${encodeURIComponent(root)}`, { timeoutMs: GUESS_TIMEOUT_MS }),
);

/**
 * Writes the checkout's .ops/config/manifest.yaml from `manifest`, and
 * commits it alone when `commit` is true, as POST /project/adopt answers.
 */
export const adopt = api.register('adopt', (rest, root, manifest, commit) => rest('/project/adopt', { method: 'POST', body: { root, manifest, commit } }));

/** Records the user's approval of the project at a root, as POST /project/approve answers. */
export const approve = api.register('approve', (rest, root) => rest('/project/approve', { method: 'POST', body: { root } }));
