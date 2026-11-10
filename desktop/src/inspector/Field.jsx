/**
 * @file The layout of one inspector field: its name on a row of its own,
 * with an optional action at the far right, a thin line under that row, and
 * the value below.
 */

import { cn } from '@hermes/plugin-sdk';
import { FieldError } from './FieldError.jsx';
import { InfoTip } from './InfoTip.jsx';

/**
 * Lays out one field as a group named `label`: a `<dt>` row holding the
 * label in semibold, followed by an (i) icon that shows `hint` when there
 * is one, or Desktop's red error glyph that shows `problem` when the field
 * has one, and `action` at the far right, underlined by the theme's
 * tertiary stroke; and a `<dd>` below holding `children`, with the message
 * from the field's last save under them when there is one. Must sit inside
 * a `<dl>`.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name.
 * @param {string} [props.hint] Help text for the field, which the (i) icon shows.
 * @param {string} [props.problem] Why the field cannot work, which the error glyph shows in place of the (i).
 * @param [props.action] What goes at the far right of the name row, such as an edit button.
 * @param {string} [props.error] The message from the field's last save, or empty.
 * @param props.children The field's value.
 */
export function Field({ label, hint = '', problem = '', action = null, error = '', children }) {
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
        <span className={cn('workshop-field-label', 'flex', 'items-center', 'gap-1')}>
          {label}
          {(problem || hint) && <InfoTip label={label} hint={problem || hint} error={Boolean(problem)} />}
        </span>
        {action}
      </dt>
      <dd className={cn('workshop-field-value', 'flex', 'min-w-0', 'flex-col', 'gap-1')}>
        {children}
        <FieldError message={error} />
      </dd>
    </div>
  );
}
