/**
 * @file An inspector field's editor: its input, Save and Cancel, and Remove
 * where the key may be cleared.
 */

import { Button, cn, Input, Textarea } from '@hermes/plugin-sdk';

/**
 * The input, with Save and Cancel, and Remove when `onRemove` is given. The
 * Field around it shows the message from the last save.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name, for the input's label.
 * @param {string} props.draft The text being edited.
 * @param {boolean} props.multiline Whether to use a text area.
 * @param {boolean} props.saving Whether a save is running.
 * @param {(text: string) => void} props.onChange Takes the new text.
 * @param {() => void} props.onSave Saves the draft.
 * @param {() => void} props.onCancel Closes the editor without saving.
 * @param {(() => void) | null} [props.onRemove] Clears the key; no Remove button when null.
 */
export function FieldEditor({
  label,
  draft,
  multiline,
  saving,
  onChange,
  onSave,
  onCancel,
  onRemove = null,
}) {
  const Control = multiline ? Textarea : Input;
  const onKeyDown = (event) => keyAction(event, onSave, onCancel);

  return (
    <span className={cn('workshop-field-editor', 'flex', 'flex-col', 'gap-1')}>
      <Control
        aria-label={label}
        size="xs"
        value={draft}
        disabled={saving}
        autoFocus
        onChange={(event) => onChange(event.target.value)}
        onKeyDown={onKeyDown}
      />
      <span className={cn('workshop-field-actions', 'flex', 'gap-1')}>
        <Button size="xs" disabled={saving} onClick={onSave}>Save</Button>
        <Button size="xs" variant="ghost" disabled={saving} onClick={onCancel}>Cancel</Button>
        {onRemove && <Button size="xs" variant="ghost" disabled={saving} onClick={onRemove}>Remove</Button>}
      </span>
    </span>
  );
}

/**
 * Saves on Enter and cancels on Escape. Enter with Shift is left alone, and
 * a text area's Enter saves too, because the stores write one line.
 *
 * @param {KeyboardEvent} event The key event from the input.
 * @param {() => void} onSave Saves the draft.
 * @param {() => void} onCancel Closes the editor.
 */
function keyAction(event, onSave, onCancel) {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    onSave();
  } else if (event.key === 'Escape') {
    event.preventDefault();
    onCancel();
  }
}
