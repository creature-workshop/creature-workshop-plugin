/**
 * @file The header's mode when the session's folder is inside a git
 * repository: the repository's name, its worktrees when it has several,
 * and the state of the checkout the pane reads.
 */

import { useId } from 'react';
import { hasWorktrees } from '../../../workshop/selection.js';
import { useWorkshop } from '../../../workshop/WorkshopProvider.jsx';
import { CheckoutStatus } from '../CheckoutStatus.jsx';
import { LabelledField } from '../field/LabelledField.jsx';
import { RepositoryName } from '../repository/RepositoryName.jsx';
import { WorktreeSelector } from '../worktree/WorktreeSelector.jsx';
import { WorktreeTether } from '../worktree/WorktreeTether.jsx';

/** What the Repository label's (i) says when the session's folder is inside a repository. */
const HINT = "The git repository this chat session's folder is in, which the pane inspects.";

/**
 * The repository's name in a box that reads as a disabled selector, under
 * a small Session Repository label with an (i), with its path in a tooltip;
 * when it has several worktrees, a tether and the worktree selector; then
 * the selected checkout's state the way a shell prompt shows it.
 */
export function InsideRepository() {
  const { repos, selected } = useWorkshop();
  const label = useId();
  const [repo] = repos.data.repos;

  return (
    <>
      <LabelledField id={label} qualifier="Session" label="Repository" hint={HINT}>
        <RepositoryName name={repo.name} root={repo.root} labelledBy={label} />
      </LabelledField>
      {hasWorktrees(repos.data.repos, repo.root) && <WorktreeTether />}
      <WorktreeSelector />
      <CheckoutStatus root={selected} />
    </>
  );
}
