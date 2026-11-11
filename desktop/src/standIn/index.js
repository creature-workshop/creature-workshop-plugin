/**
 * @file The stand-in backend, with every behaviour registered: the module a
 * story or a test imports. Importing the behaviour modules registers them
 * in api.js, which builds a stand-in that has them all.
 */

import './selection.js';

/** Builds a backend call for a story or a test from the story's own answers. */
export { standIn } from './api.js';
