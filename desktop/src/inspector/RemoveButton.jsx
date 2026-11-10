/**
 * @file The button that clears a key, at the far right of a field whose
 * control saves as soon as it changes.
 */

import { Button } from '@hermes/plugin-sdk';

/**
 * A small "Remove" button, labelled "Remove <label>" for assistive
 * technology.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name.
 * @param {boolean} props.disabled Whether a save is running.
 * @param {() => void} props.onClick Clears the key.
 */
export function RemoveButton({ label, disabled, onClick }) {
  return (
    <Button size="xs" variant="ghost" aria-label={`Remove ${label}`} disabled={disabled} onClick={onClick}>
      Remove
    </Button>
  );
}
