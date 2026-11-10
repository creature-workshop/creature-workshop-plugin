/**
 * @file The short line that tethers the worktree selector to the repository
 * selector, so the worktree reads as part of the repository.
 */

import { cn } from '@hermes/plugin-sdk';
import { INPUT_STROKE } from '../field/inputChrome.js';

/**
 * As tall as the selectors, so the line runs level with their middle, and
 * pulled into the header's gaps on both sides, so it runs from one trigger's
 * edge to the other's without taking room of its own. Inline because
 * Desktop's stylesheet has no classes for these sizes.
 */
const TETHER_STYLE = { height: '1.375rem', width: '1rem', marginInline: '-0.5rem' };

/** The line itself: one pixel in the selectors' own outline color. */
const LINE_STYLE = { height: '1px', width: '100%', background: INPUT_STROKE };

/** A decorative line between the two selectors, hidden from assistive technology. */
export function WorktreeTether() {
  return (
    <span
      aria-hidden="true"
      className={cn(
        'workshop-worktree-tether',
        'flex',
        'shrink-0',
        'items-center',
      )}
      style={TETHER_STYLE}
    >
      <span className={cn('workshop-worktree-tether-line')} style={LINE_STYLE} />
    </span>
  );
}
