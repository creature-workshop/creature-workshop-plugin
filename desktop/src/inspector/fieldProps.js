/**
 * @file The props the inspector passes to every field component. Each
 * component draws one key of a record from them, and saves through
 * `commit`.
 */

/**
 * Builds a field component's props, made read-only.
 *
 * @param {object} props The props.
 * @param {string} props.label The field's name.
 * @param {string} props.hint Help text for the field: the schema's description, or empty.
 * @param {object} props.schema The key's definition in the file's schema.
 * @param {unknown} props.value The key's value: undefined when untouched, null when cleared.
 * @param {'untouched' | 'cleared' | 'set'} props.state Which of the three states the key is in.
 * @param {boolean} props.required Whether the file's schema requires the key.
 * @param {boolean} props.readOnly Whether the field only shows its value.
 * @param {(operation: {op: 'set', value: unknown} | {op: 'clear'}) => Promise<string | null>} props.commit Saves one change to the key; resolves to null, or to the message to show.
 */
export function fieldProps({ label, hint, schema, value, state, required, readOnly, commit }) {
  return Object.freeze({ label, hint, schema, value, state, required, readOnly, commit });
}
