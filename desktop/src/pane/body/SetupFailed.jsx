/**
 * @file What the pane body shows when it could not tell how far the
 * selected checkout is set up.
 */

import { cn } from '@hermes/plugin-sdk';
import { FailureNotice } from '../../failures/FailureNotice.jsx';

/**
 * "I couldn't tell whether <name> is set up." with why, what to try and Try
 * again, in place of the body.
 *
 * @param props The component's props.
 * @param {string} props.name The checkout's folder name.
 * @param props.error The error, as client/api.js flattens it.
 * @param {() => void} props.onRetry Asks again.
 */
export function SetupFailed({ name, error, onRetry }) {
  return (
    <div className={cn('workshop-setup-failure', 'px-2', 'py-2')}>
      <FailureNotice what={`I couldn't tell whether ${name} is set up.`} error={error} onRetry={onRetry} />
    </div>
  );
}
