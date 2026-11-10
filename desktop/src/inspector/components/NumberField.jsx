/**
 * @file The built-in `number` component: a number typed into the field,
 * whole when the key's schema allows only integers, and inside the
 * schema's `minimum` and `maximum`.
 */

import { EditableField } from '../EditableField.jsx';
import { canClear, typesOf } from '../schema.js';

/**
 * A number key as an editable field. Saving sets the number typed, and
 * refuses, without a call, text that is not a number, a fraction where the
 * key allows only integers, and a number outside the schema's `minimum` or
 * `maximum`. Remove clears the key, and shows only where the key may be
 * cleared.
 *
 * @param {object} props The props that fieldProps builds.
 */
export function NumberField(props) {
  const { label, hint, schema, value, state, required, readOnly, commit } = props;
  const remove = canClear(schema, required) ? () => commit({ op: 'clear' }) : null;
  const save = async (text) => {
    const checked = numberFrom(text, schema, label);
    return checked.message ?? commit({ op: 'set', value: checked.value });
  };

  return (
    <EditableField
      label={label}
      hint={hint}
      text={typeof value === 'number' ? String(value) : ''}
      state={state}
      fallback={typeof schema.default === 'number' ? String(schema.default) : ''}
      readOnly={readOnly}
      onSave={save}
      onRemove={remove}
    />
  );
}

/**
 * The number in `text` as `{value}`, or `{message}` saying why it cannot be
 * saved to the key.
 *
 * @param {string} text The text typed.
 * @param {object} schema The key's definition.
 * @param {string} label The field's name, for the message.
 */
function numberFrom(text, schema, label) {
  const trimmed = text.trim();
  const value = trimmed === '' ? Number.NaN : Number(trimmed);
  if (!Number.isFinite(value)) {
    return { message: `${label} needs a number.` };
  }
  return { value, message: rangeMessage(value, schema, label) };
}

/**
 * Why `value` cannot be saved to the key, or undefined when it can: a
 * fraction where the key allows only integers, or a number below its
 * `minimum` or above its `maximum`.
 *
 * @param {number} value The number.
 * @param {object} schema The key's definition.
 * @param {string} label The field's name, for the message.
 */
function rangeMessage(value, schema, label) {
  const types = typesOf(schema);
  if (types.includes('integer') && !types.includes('number') && !Number.isInteger(value)) {
    return `${label} needs a whole number.`;
  }
  if (typeof schema.minimum === 'number' && value < schema.minimum) {
    return `${label} must be at least ${schema.minimum}.`;
  }
  if (typeof schema.maximum === 'number' && value > schema.maximum) {
    return `${label} must be at most ${schema.maximum}.`;
  }
  return undefined;
}
