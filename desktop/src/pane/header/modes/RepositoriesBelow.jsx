/**
 * @file The header's mode when the session's folder is inside no git
 * repository and holds some below it, even only one: a selector over them,
 * none selected until the user selects one, the selected one's worktrees
 * tethered to it, and the state of the checkout the pane reads.
 */

import { hasWorktrees } from '../../../workshop/selection.js';
import { useWorkshop } from '../../../workshop/WorkshopProvider.jsx';
import { RepositorySelector } from '../repository/RepositorySelector.jsx';
import { CheckoutStatus } from '../CheckoutStatus.jsx';
import { WorktreeSelector } from '../worktree/WorktreeSelector.jsx';
import { WorktreeTether } from '../worktree/WorktreeTether.jsx';

/** The selector, a short line tethering it to the worktree selector when the selected repository has several worktrees, then the selected checkout's state the way a shell prompt shows it. */
export function RepositoriesBelow() {
  const { repos, repo, selected } = useWorkshop();
  return (
    <>
      <RepositorySelector />
      {hasWorktrees(repos.data.repos, repo) && <WorktreeTether />}
      {selected && <WorktreeSelector />}
      {selected && <CheckoutStatus root={selected} />}
    </>
  );
}
