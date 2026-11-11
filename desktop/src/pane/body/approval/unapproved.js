/**
 * @file Whether the selected repository is a project waiting for the
 * user's approval.
 */

/**
 * Whether the selected repository is the root of a shellops project that
 * the user has not approved.
 *
 * @param project GET /project's answer for the selected repository, as remote data.
 * @param {string} selected The selected repository's root, or an empty string.
 *
 * @returns {boolean} Whether the pane asks for approval.
 */
export function unapproved(project, selected) {
  return Boolean(selected && project.state === 'success' && project.data.found && project.data.root === selected && !project.data.approved);
}
