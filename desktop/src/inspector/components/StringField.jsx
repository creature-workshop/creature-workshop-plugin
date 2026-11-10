/**
 * @file What both built-in string components draw: an EditableField, wired
 * to the props every field component receives.
 */

import { EditableField } from '../EditableField.jsx';
import { canClear } from '../schema.js';

/**
 * A string key as an editable field: its text, its state, and the schema's
 * default while it is untouched. Saving sets the trimmed text; a required
 * key saved empty is refused here, without a call. Remove clears the key,
 * and shows only where the key may be cleared.
 *
 * @param props The component's props.
 * @param {object} props.field The props that fieldProps builds.
 * @param {boolean} props.multiline Whether to edit in a text area that wraps.
 */
export function StringField({ field, multiline }) {
  const { label, hint, schema, value, state, required, readOnly, commit } = field;
  const remove = canClear(schema, required) ? () => commit({ op: 'clear' }) : null;

  return (
    <EditableField
      label={label}
      hint={hint}
      text={typeof value === 'string' ? value : ''}
      state={state}
      fallback={schema?.default === undefined ? '' : String(schema.default)}
      multiline={multiline}
      readOnly={readOnly}
      onSave={(text) => setText({ text, label, required, commit })}
      onRemove={remove}
    />
  );
}

/**
 * Sets the trimmed text, unless the key is required and the text is empty.
 *
 * @param options What to save, and how.
 * @param {string} options.text The new text.
 * @param {string} options.label The field's name, for the message.
 * @param {boolean} options.required Whether the schema requires the key.
 * @param options.commit Writes one operation.
 */
async function setText({ text, label, required, commit }) {
  const trimmed = text.trim();
  if (required && !trimmed) {
    return `${label} cannot be empty.`;
  }
  return commit({ op: 'set', value: trimmed });
}
