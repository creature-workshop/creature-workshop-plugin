/**
 * @file A Project Info field's value as text.
 */

import { cn } from '@hermes/plugin-sdk';

/**
 * Shows the value, or "Not set" in the tertiary text color when it is empty.
 *
 * @param props The component's props.
 * @param {string} props.value The value.
 */
export function FieldValue({ value }) {
  return <span className={cn('workshop-field-text', !value && 'text-(--ui-text-tertiary)')}>{value || 'Not set'}</span>;
}
