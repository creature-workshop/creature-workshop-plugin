/**
 * @file A fixture for house/class-name that fails four times: strings given to
 * cn that hold several classes, directly and inside a condition, and an
 * empty one.
 */

import { cn } from '@hermes/plugin-sdk';

/** A row whose cn arguments group classes together. */
export function Grouped() {
  return <div className={cn('flex min-w-0',
    'border-b border-(--ui-stroke-tertiary)')} />;
}

/**
 * A row whose condition gives several classes, and nothing when closed.
 *
 * @param props The component's props.
 * @param props.open Whether the row is open.
 */
export function Conditional({ open }) {
  return <div className={cn('row', open ? 'px-3 py-1' : '')} />;
}
