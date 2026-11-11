/**
 * @file Approving the selected project from the pane: the approval in
 * progress and how it ended.
 */

import { useCallback, useState } from 'react';
import { approveProject } from '../../../modules/approval/approval.js';
import { useWorkshop } from '../../../workshop/WorkshopProvider.jsx';

/** Before the user approves, and after an approval that went through. */
const IDLE = Object.freeze({ phase: 'idle' });

/** While the approval is being recorded. */
const APPROVING = Object.freeze({ phase: 'approving' });

/**
 * Returns `{attempt, approve}` for the project at `root`. `approve()`
 * adds the project to the approved_projects setting and, when that goes
 * through, asks for the project again, so the pane shows it as approved.
 * `attempt.phase` is `idle`, `approving`, or `failed` with the `error`.
 *
 * @param {string} root The project's root.
 */
export function useApprove(root) {
  const { retry } = useWorkshop();
  const [attempt, setAttempt] = useState(IDLE);
  const approve = useCallback(async () => {
    setAttempt(APPROVING);
    const approved = await approveProject(root);
    setAttempt(approved.ok ? IDLE : { phase: 'failed', error: approved.error });
    if (approved.ok) {
      retry('project');
    }
  }, [root, retry]);

  return { attempt, approve };
}
