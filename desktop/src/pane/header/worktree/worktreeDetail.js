/**
 * @file What the worktree selector says about a worktree after its folder
 * name, and what its tooltip says.
 */

/**
 * The worktree's branch, "detached at <short commit>" on a detached HEAD,
 * or "" when the folder is named for the branch, whole or by its last part,
 * so the branch would only repeat it.
 *
 *     worktreeDetail({name: "rig-timers", branch: "docs/timer-enable-line"})  ->  "docs/timer-enable-line"
 *     worktreeDetail({name: "hotfix", branch: "fix/hotfix"})                  ->  ""
 *     worktreeDetail({name: "old", branch: "", head: "1a2b3c4d5e"})           ->  "detached at 1a2b3c4"
 *
 * @param {{name: string, branch: string, head?: string}} worktree A worktree from GET /repos.
 */
export function worktreeDetail({ name, branch, head = '' }) {
  if (!branch) {
    return `detached at ${head.slice(0, 7)}`;
  }
  return namedFor(name, branch) ? '' : branch;
}

/**
 * The worktree's tooltip: its folder's path, then its branch or detached commit.
 *
 *     worktreeTip({root: "/code/rig-timers", name: "rig-timers", branch: "docs/x"})  ->  "/code/rig-timers, on docs/x"
 *
 * @param {{root: string, branch: string, head?: string}} worktree A worktree from GET /repos.
 */
export function worktreeTip({ root, branch, head = '' }) {
  return branch ? `${root}, on ${branch}` : `${root}, detached at ${head.slice(0, 7)}`;
}

/**
 * Whether a folder is named for a branch: its whole name, or the part after its last slash.
 *
 * @param {string} name The folder's name.
 * @param {string} branch The branch.
 */
function namedFor(name, branch) {
  return name === branch || name === branch.split('/').pop();
}
