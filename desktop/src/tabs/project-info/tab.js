/**
 * @file The Project Info tab: what the strip shows for it and the panel it opens.
 */

import { ProjectInfoPanel } from './ProjectInfoPanel.jsx';

/** The Project Info tab: what the project is, starting with its release record. */
export const projectInfo = Object.freeze({ id: 'project-info', label: 'Project Info', Panel: ProjectInfoPanel });
