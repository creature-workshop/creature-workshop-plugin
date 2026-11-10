/**
 * @file The story the error boundary's tests mount: a part that crashes
 * the first time it draws, inside a PartBoundary, beside a part that does
 * not, and the footer, whose boundary draws one quiet line instead. The
 * tests are in failures.ct.jsx beside this file.
 */

import { cn } from '@hermes/plugin-sdk';
import { useRef } from 'react';
import { FooterFailed } from '../pane/FooterFailed.jsx';
import { PartBoundary } from './PartBoundary.jsx';

/**
 * A part that throws "Boom" while `crashes` has crashes left, taking one
 * each time, and says "Back again" once they are used up.
 *
 * @param props The component's props.
 * @param {{current: number}} props.crashes How many more times to crash.
 */
function Fragile({ crashes }) {
  if (crashes.current > 0) {
    crashes.current -= 1;
    throw new Error('Boom');
  }
  return <p className={cn('workshop-story-fragile')}>Back again</p>;
}

/** The tabs, crashing once inside their boundary, above a footer that keeps drawing. */
export function CrashingOnce() {
  const crashes = useRef(1);

  return (
    <div className={cn('workshop-story', 'flex', 'flex-col')}>
      <PartBoundary part="The tabs">
        <Fragile crashes={crashes} />
      </PartBoundary>
      <footer className={cn('workshop-story-footer')}>Still here</footer>
    </div>
  );
}

/** The footer, crashing inside its boundary, which draws FooterFailed in its place. */
export function FooterCrashing() {
  const crashes = useRef(1);

  return (
    <div className={cn('workshop-story', 'flex', 'flex-col')}>
      <PartBoundary part="The footer" fallback={FooterFailed}>
        <Fragile crashes={crashes} />
      </PartBoundary>
    </div>
  );
}
