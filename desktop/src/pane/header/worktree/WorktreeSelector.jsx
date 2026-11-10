/**
 * @file The selector over the selected repository's worktrees, to the right
 * of the repository, built from the app's own select.
 */

import { cn, Select, SelectContent, SelectItem, SelectTrigger, SelectValue, Tip } from '@hermes/plugin-sdk';
import { useId } from 'react';
import { hasWorktrees, repositoryAt, worktreesOf } from '../../../workshop/selection.js';
import { useWorkshop } from '../../../workshop/WorkshopProvider.jsx';
import { LabelledField } from '../field/LabelledField.jsx';
import { WorktreeOption } from './WorktreeOption.jsx';
import { worktreeTip } from './worktreeDetail.js';

/**
 * A select under a small Session Worktree label with an (i), listing the selected repository's worktrees,
 * main first, each by its folder with its branch in parentheses. The
 * trigger shows the selected worktree's folder alone, since its branch is
 * in the state beside it, and its tooltip gives the path and the branch.
 * Nothing when the repository has only its main worktree. Selecting one
 * makes the whole pane read it.
 */
export function WorktreeSelector() {
  const { repos, repo, selected, selectWorktree } = useWorkshop();
  const label = useId();
  const worktrees = worktreesOf(repositoryAt(repos.data.repos, repo) ?? {});
  const current = worktrees.find((each) => each.root === selected);
  const name = repositoryAt(repos.data.repos, repo)?.name;
  if (!hasWorktrees(repos.data.repos, repo)) {
    return null;
  }

  return (
    <LabelledField
      id={label}
      label="Session Worktree"
      hint={`Which worktree of ${name} would you like to inspect?`}
    >
      <Select value={selected} onValueChange={selectWorktree}>
        <Tip label={current && worktreeTip(current)}>
          <SelectTrigger
            size="xs"
            aria-labelledby={label}
            className={cn(
              'workshop-worktree-selector',
              'w-full',
              'min-w-0',
              'overflow-hidden',
            )}
          >
            <SelectValue
              className={cn(
                'workshop-worktree-selector-value',
                'min-w-0',
                'truncate',
              )}
            >
              {current?.name}
            </SelectValue>
          </SelectTrigger>
        </Tip>
        <SelectContent>
          {worktrees.map((each) => <SelectItem key={each.root} value={each.root}><WorktreeOption worktree={each} /></SelectItem>)}
        </SelectContent>
      </Select>
    </LabelledField>
  );
}
