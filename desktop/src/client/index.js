/**
 * @file The backend's client, with every call registered: the module the
 * rest of the app imports. Importing the route modules registers their
 * calls in api.js, which holds the client and connects it to a backend.
 * There is one module here for each module under workshop/routes/, with
 * the same name and the same paths, which tests/python/workshop/test_route_mirror.py holds.
 */

import './about.js';
import './project.js';
import './repos.js';

/** The client every part of the app calls, and the function that connects it to a backend call. */
export { client, connect } from './api.js';
