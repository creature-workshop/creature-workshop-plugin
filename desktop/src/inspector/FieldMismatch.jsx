/**
 * @file A field whose component cannot save to its key: its name and the
 * reason, with no way to edit it.
 */

import { cn } from '@hermes/plugin-sdk';
import { Field } from './Field.jsx';

/**
 * Shows `label`, and below it the reason the field cannot be edited, in the
 * error color, with no pencil.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name.
 * @param {string} props.reason Why the component cannot save to the key.
 */
export function FieldMismatch({ label, reason }) {
  return (
    <Field label={label}>
      <span role="alert" className={cn('workshop-field-mismatch', 'text-destructive')}>{reason}</span>
    </Field>
  );
}
