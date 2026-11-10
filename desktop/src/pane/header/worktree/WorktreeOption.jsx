/**
 * @file One entry in the worktree selector's list.
 */

import { cn } from '@hermes/plugin-sdk';
import { worktreeDetail } from './worktreeDetail.js';

/**
 * The worktree's folder name, then its branch, or its short commit when
 * detached, in parentheses in the tertiary color; the folder alone when it
 * is named for its branch.
 *
 * @param props The component's props.
 * @param props.worktree A worktree from GET /repos.
 */
export function WorktreeOption({ worktree }) {
  const detail = worktreeDetail(worktree);

  return (
    <>
      {worktree.name}
      {detail && <span className={cn('workshop-worktree-detail', 'text-(--ui-text-tertiary)')}>{` (${detail})`}</span>}
    </>
  );
}
