/**
 * @file One editable inspector field: its name with a pencil button at
 * the far right, and its value below, which the pencil turns into an input.
 */

import { useState } from 'react';
import { Field } from './Field.jsx';
import { FieldEditor } from './FieldEditor.jsx';
import { FieldValue } from './FieldValue.jsx';
import { IconButton } from './IconButton.jsx';

/**
 * Shows `label` with a pencil button labelled "Edit <label>" at the far
 * right, and the value below in its state. Clicking the pencil shows an
 * input holding the text, and hides the pencil until the editor closes.
 * Enter or Save calls `onSave` with the new text; Remove, when `onRemove`
 * is given, calls it; Escape or Cancel goes back without saving. While
 * either runs the input is disabled. When it resolves to a message, the
 * input stays open and shows it; when it resolves to null, the row goes
 * back to showing the value. A read-only field has no pencil.
 *
 * Must sit inside a `<dl>`, like Field.
 *
 * @param props The component's props.
 * @param {string} props.label The field's name.
 * @param {string} [props.hint] Help text for the field, which the (i) icon after the name shows.
 * @param {string} props.text The value as text; empty when untouched or cleared.
 * @param {'untouched' | 'cleared' | 'set'} props.state The key's state.
 * @param {string} [props.fallback] The schema's default as text, shown while the key is untouched.
 * @param {boolean} [props.multiline] Whether to edit in a text area that wraps, instead of a one-line input.
 * @param {boolean} [props.readOnly] Whether the field only shows its value.
 * @param {(text: string) => Promise<string | null>} props.onSave Saves the new text; resolves to a message, or null.
 * @param {(() => Promise<string | null>) | null} [props.onRemove] Clears the key; resolves to a message, or null. No Remove button when null.
 */
export function EditableField({
  label,
  hint = '',
  text,
  state,
  fallback = '',
  multiline = false,
  readOnly = false,
  onSave,
  onRemove = null,
}) {
  const [draft, setDraft] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const editing = draft !== null;

  const cancel = () => {
    setDraft(null);
    setError('');
  };
  const run = async (action) => {
    setSaving(true);
    const message = await action();
    setSaving(false);
    setError(message ?? '');
    if (!message) {
      setDraft(null);
    }
  };
  const pencil = readOnly || editing ? null : <IconButton label={`Edit ${label}`} icon="edit" onClick={() => setDraft(text)} />;
  const remove = onRemove ? () => run(onRemove) : null;

  return (
    <Field label={label} hint={hint} action={pencil} error={editing ? error : ''}>
      {editing
        ? (
          <FieldEditor
            label={label}
            draft={draft}
            multiline={multiline}
            saving={saving}
            onChange={setDraft}
            onSave={() => run(() => onSave(draft))}
            onCancel={cancel}
            onRemove={remove}
          />
        )
        : <FieldValue text={text} state={state} fallback={fallback} />}
    </Field>
  );
}
