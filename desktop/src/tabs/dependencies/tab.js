/**
 * @file The Dependencies tab: what the strip shows for it and the panel it opens.
 */

import { DependenciesPanel } from './DependenciesPanel.jsx';

/** The Dependencies tab: the tools the project declares, and which are installed. */
export const dependencies = Object.freeze({ id: 'dependencies', label: 'Dependencies', Panel: DependenciesPanel });
