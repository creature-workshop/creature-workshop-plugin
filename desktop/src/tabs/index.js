/**
 * @file The Workshop tabs, in the order the strip shows them. A tab is a
 * folder under tabs/ whose tab.js gives its id, its label and its Panel; it
 * joins the strip by being listed here.
 */

import { dependencies } from './dependencies/tab.js';
import { projectInfo } from './project-info/tab.js';

/**
 * A Workshop tab.
 *
 * @typedef {object} Tab
 * @property {string} id The tab's value, unique among the tabs.
 * @property {string} label What the strip says for it, and the panel's name.
 * @property {() => unknown} Panel The component the tab opens.
 */

/** @type {readonly Tab[]} Every tab, first to last; the first is open by default. */
export const TABS = Object.freeze([projectInfo, dependencies]);
