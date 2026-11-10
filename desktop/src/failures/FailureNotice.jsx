/**
 * @file What a part of the pane shows in place of data it could not read:
 * what happened, why, what to try, a Try again button, Report it when the
 * failure is a bug in the plugin, and the details.
 */

import { Button, cn } from '@hermes/plugin-sdk';
import { describe, detailsOf, KINDS } from './describe.js';
import { DetailsToggle } from './DetailsToggle.jsx';
import { ReportLink } from './ReportLink.jsx';

/**
 * An alert saying `what` happened, then why and what to try, from the
 * error's code, with a Try again button that calls `onRetry`, a Report it
 * button when the failure is a bug in the plugin, and a Show details toggle
 * holding the error's code, status and raw message.
 *
 * @param props The component's props.
 * @param {string} props.what What happened and to what, such as "I couldn't read config/manifest.yaml.".
 * @param props.error The error, as client/api.js flattens it.
 * @param {() => void} props.onRetry Asks again.
 */
export function FailureNotice({ what, error, onRetry }) {
  const { kind, why, hint } = describe(error);
  const details = detailsOf(error);

  return (
    <div role="alert" className={cn('workshop-failure', 'flex', 'min-w-0', 'flex-col', 'gap-1')}>
      <p className={cn('workshop-failure-what', 'font-semibold', 'text-destructive')}>{what}</p>
      <p className={cn('workshop-failure-why')}>{why}</p>
      <p className={cn('workshop-failure-hint', 'text-(--ui-text-tertiary)')}>{hint}</p>
      <span className={cn('workshop-failure-actions', 'flex', 'flex-wrap', 'items-start', 'gap-1')}>
        {kind === KINDS.bug && <ReportLink what={what} details={details} />}
        <Button size="xs" variant={kind === KINDS.bug ? 'outline' : 'default'} onClick={onRetry}>Try again</Button>
        <DetailsToggle details={details} />
      </span>
    </div>
  );
}
