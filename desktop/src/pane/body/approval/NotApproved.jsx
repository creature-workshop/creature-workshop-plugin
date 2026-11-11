/**
 * @file What the pane body shows, alone and in its middle, for a project
 * that is set up and that the user has not approved: that approval is
 * needed, what approving agrees to, and a button that approves it.
 */

import { Button, cn } from '@hermes/plugin-sdk';
import { FailureNotice } from '../../../failures/FailureNotice.jsx';
import { CentredNotice } from '../CentredNotice.jsx';
import { LoadingDots } from '../LoadingDots.jsx';
import { useApprove } from './useApprove.js';

/** What approving the project agrees to. */
export const APPROVE_NOTICE = 'By approving, you agree to let Creature Workshop run commands to manage this repository.';

/**
 * A status in the middle of the pane body saying "Approval needed for
 * <name>." and what approving agrees to, with an Approve project button
 * that adds the project to the approved_projects setting; "Approving" with
 * dots while it is recorded, and why with Try again when Hermes did not
 * save it.
 *
 * @param props The component's props.
 * @param {string} props.root The project's root.
 * @param {string} props.name The project's folder name.
 */
export function NotApproved({ root, name }) {
  const { attempt, approve } = useApprove(root);
  if (attempt.phase === 'failed') {
    return (
      <div className={cn('workshop-not-approved-failure', 'px-2', 'py-2')}>
        <FailureNotice what={`I couldn't record your approval of ${name}.`} error={attempt.error} onRetry={approve} />
      </div>
    );
  }

  return (
    <CentredNotice name="workshop-not-approved" what={`Approval needed for ${name}.`} why={APPROVE_NOTICE}>
      {attempt.phase === 'approving'
        ? <p className={cn('workshop-not-approved-running', 'text-(--ui-text-secondary)')}><LoadingDots>Approving</LoadingDots></p>
        : <Button size="xs" className={cn('workshop-approve-button')} onClick={approve}>Approve project</Button>}
    </CentredNotice>
  );
}
