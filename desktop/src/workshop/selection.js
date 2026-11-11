/**
 * @file Reading GET /repos's repositories, each of which carries its
 * worktrees, main first: finding one by its root, and whether it has
 * worktrees to choose between. Which checkout a session is on is the
 * backend's to decide, in workshop/selection.py.
 */

/**
 * The repository in `repos` whose root is `root`, or undefined.
 *
 * @param {object[]} repos GET /repos's repositories.
 * @param {string} root A repository's root.
 */
export function repositoryAt(repos, root) {
  return repos.find((repo) => repo.root === root);
}

/**
 * Whether the repository at `root` has worktrees to choose between: more than its main one.
 *
 * @param {object[]} repos GET /repos's repositories.
 * @param {string} root A repository's root.
 */
export function hasWorktrees(repos, root) {
  return worktreesOf(repositoryAt(repos, root) ?? {}).length > 1;
}

/**
 * A repository's worktrees, none when the answer lists none.
 *
 * @param {object} repo A repository from GET /repos.
 */
export function worktreesOf(repo) {
  return repo.worktrees ?? [];
}
