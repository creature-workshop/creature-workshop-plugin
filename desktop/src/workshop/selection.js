/**
 * @file Which checkout the pane reads: the worktree picked for the selected
 * repository, or its main worktree when none is picked or the picked one is
 * gone. Each repository in GET /repos carries its worktrees, main first.
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
 * The repository one of whose worktrees is rooted at `checkout`, or undefined.
 *
 * @param {object[]} repos GET /repos's repositories.
 * @param {string} checkout A worktree's root.
 */
export function repositoryHolding(repos, checkout) {
  return repos.find((repo) => worktreesOf(repo).some((each) => each.root === checkout));
}

/**
 * The root of the checkout the pane reads for `repo`: the worktree `picks`
 * names for it while that worktree is still listed, else its main worktree,
 * else its first, else the repository's own root; "" without a repository.
 *
 *     checkoutOf(demo, {})                           ->  "/code/demo"
 *     checkoutOf(demo, {"/code/demo": "/code/fix"})  ->  "/code/fix"
 *
 * @param {object | undefined} repo The selected repository.
 * @param {Record<string, string>} picks The worktree picked for each repository, by its root.
 */
export function checkoutOf(repo, picks) {
  if (!repo) {
    return '';
  }
  const worktrees = worktreesOf(repo);
  const picked = worktrees.find((each) => each.root === picks[repo.root]);
  return (picked ?? worktrees.find((each) => each.main) ?? worktrees[0] ?? repo).root;
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
