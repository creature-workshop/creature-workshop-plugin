/**
 * @file The client's call for what the plugin is: GET /about.
 */

import * as api from './api.js';

/** The answer to GET /about when the call failed. */
const NO_ABOUT = { version: '', branch: '' };

/** The plugin's version and the branch of the checkout it was loaded from, both empty when the call failed. */
export const about = api.register('about', (rest) => rest('/about'), NO_ABOUT);
