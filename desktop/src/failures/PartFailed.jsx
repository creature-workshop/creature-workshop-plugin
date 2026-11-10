/**
 * @file What a part of the pane shows when its code crashed: that it
 * stopped, that the rest of the pane still works, a Try again button, and
 * the details.
 */

import { Button, cn } from '@hermes/plugin-sdk';
import { DetailsToggle } from './DetailsToggle.jsx';
import { REPORT_ADDRESS } from './report.js';
import { ReportLink } from './ReportLink.jsx';

/** What a crashed part says after its name. */
const WHY = "Something in my code went wrong, so I stopped drawing this part. This isn't something you did, and the rest of the pane still works.";

/** What to try after a crash. */
const HINT = `Try again. If it keeps happening, let us know about your issue at ${REPORT_ADDRESS} and we'll look into it.`;

/**
 * An alert saying "<part> stopped working.", why, and what to try, with a
 * Try again button that calls `onRetry`, a Report it button, and a Show
 * details toggle holding the error's stack, which starts with its name and message.
 *
 * @param props The component's props.
 * @param {string} props.part The part's name, such as "The header".
 * @param {Error} props.error What the part threw.
 * @param {() => void} props.onRetry Draws the part again.
 */
export function PartFailed({ part, error, onRetry }) {
  const details = error?.stack || `${error?.name}: ${error?.message}`;

  return (
    <div role="alert" className={cn('workshop-part-failed', 'flex', 'min-w-0', 'flex-col', 'gap-1', 'px-2', 'py-2')}>
      <p className={cn('workshop-failure-what', 'font-semibold', 'text-destructive')}>{`${part} stopped working.`}</p>
      <p className={cn('workshop-failure-why')}>{WHY}</p>
      <p className={cn('workshop-failure-hint', 'text-(--ui-text-tertiary)')}>{HINT}</p>
      <span className={cn('workshop-failure-actions', 'flex', 'flex-wrap', 'items-start', 'gap-1')}>
        <Button size="xs" onClick={onRetry}>Try again</Button>
        <ReportLink what={`${part} stopped working.`} details={details} />
        <DetailsToggle details={details} />
      </span>
    </div>
  );
}
