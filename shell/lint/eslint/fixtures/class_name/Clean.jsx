/**
 * @file A fixture for house/class-name that passes: each className is a cn
 * call with one class to a string, including the strings a condition gives.
 */

import { cn } from '@hermes/plugin-sdk';

/**
 * A row with a class list built one class to an argument.
 *
 * @param props The component's props.
 * @param props.open Whether the row is open.
 */
export function Clean({ open }) {
  return (
    <div
      className={cn(
        'row',
        'flex',
        'text-(--ui-text-tertiary)',
        open && 'border-b',
        open ? 'py-2' : 'py-1',
      )}
    />
  );
}
