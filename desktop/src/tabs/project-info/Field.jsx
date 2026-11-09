/**
 * @file The layout of one Project Info field: its name on a row of its own,
 * with an optional action at the far right, a thin line under that row, and
 * the value below.
 */

import { cn } from '@hermes/plugin-sdk';

/**
 * Lays out one field as a group named `label`: a `<dt>` row holding the
 * label in semibold and `action` at the far right, underlined by the
 * theme's tertiary stroke, and a `<dd>` below holding `children`. Must sit
 * inside a `<dl>`.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name.
 * @param [props.action] What goes at the far right of the name row, such as an edit button.
 * @param props.children The field's value.
 */
export function Field({ label, action = null, children }) {
  return (
    <div role="group" aria-label={label} className={cn('workshop-field', 'flex', 'flex-col', 'gap-1')}>
      <dt
        className={cn(
          'workshop-field-name',
          'flex',
          'min-h-6',
          'items-center',
          'justify-between',
          'gap-2',
          'border-b',
          'border-(--ui-stroke-tertiary)',
          'font-semibold',
          'text-(--ui-text-tertiary)',
        )}
      >
        {label}
        {action}
      </dt>
      <dd className={cn('workshop-field-value', 'min-w-0')}>{children}</dd>
    </div>
  );
}
