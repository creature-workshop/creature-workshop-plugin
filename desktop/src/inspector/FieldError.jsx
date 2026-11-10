/**
 * @file The message from a field's last save, under its control.
 */

import { cn } from '@hermes/plugin-sdk';

/**
 * Shows `message` in the error color, announced as an alert; nothing when
 * it is empty.
 *
 * @param props The component's props.
 * @param {string} props.message The message, or empty.
 */
export function FieldError({ message }) {
  if (!message) {
    return null;
  }
  return <p role="alert" className={cn('workshop-field-error', 'text-destructive')}>{message}</p>;
}
