/**
 * @file One editable Project Info field: its name with a pencil button at
 * the far right, and its value below, which the pencil turns into an input.
 */

import { useState } from 'react';
import { EditButton } from './EditButton.jsx';
import { Field } from './Field.jsx';
import { FieldEditor } from './FieldEditor.jsx';
import { FieldValue } from './FieldValue.jsx';

/**
 * Shows `label` with a pencil button labelled "Edit <label>" at the far
 * right, and `value` below. Clicking the pencil shows an input holding the
 * value, and hides the pencil until the editor closes. Enter or Save calls
 * `onSave` with the new text; Escape or Cancel goes back without saving.
 * While `onSave` runs the input is disabled. When `onSave` resolves to a
 * message, the input stays open and shows it; when it resolves to null,
 * the row goes back to showing the value.
 *
 * Must sit inside a `<dl>`, like Field.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name.
 * @param {string} props.value The field's current value, or an empty string when it is not set.
 * @param {boolean} [props.multiline] Whether to edit in a text area that wraps, instead of a one-line input.
 * @param {(value: string) => Promise<string | null>} props.onSave Saves the new value; resolves to an error message, or null.
 */
export function EditableField({ label, value, multiline = false, onSave }) {
  const [draft, setDraft] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const editing = draft !== null;

  const cancel = () => {
    setDraft(null);
    setError('');
  };
  const save = async () => {
    setSaving(true);
    const message = await onSave(draft);
    setSaving(false);
    setError(message ?? '');
    if (!message) {
      setDraft(null);
    }
  };

  return (
    <Field label={label} action={editing ? null : <EditButton label={label} onClick={() => setDraft(value)} />}>
      {editing
        ? <FieldEditor label={label} draft={draft} multiline={multiline} saving={saving} error={error} onChange={setDraft} onSave={save} onCancel={cancel} />
        : <FieldValue value={value} />}
    </Field>
  );
}
