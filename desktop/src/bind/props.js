/**
 * @file The props a bound component receives for its data, by what its
 * binding names: a store, a record or a key.
 */

/**
 * The data props of a component bound with `bind`:
 *
 * - a key binding gets `value`, the key's value, undefined when untouched
 *   and null when cleared; `onChange(value)`, which sets it; `saving`, true
 *   while a change is being saved; and `error`, what the last change
 *   resolved to, or empty. These are the props of an ordinary controlled
 *   component;
 * - a record binding gets `value`, the record's values; `schema`; `git`;
 *   `write(operation)`, which writes one operation to that record; and
 *   `reread()`;
 * - a store binding gets `value`, every record; `schema`; `git`;
 *   `write(operation)`, which writes one operation to the store; and
 *   `reread()`.
 *
 * `git` is the state of the store's file in git, or null.
 *
 * @param {{record?: string, key?: string}} bind The binding.
 * @param data The data of the binding's target, as target.js narrows it.
 * @param writer How the component changes the store.
 * @param {(operation: object) => Promise<string | null>} writer.write Queues one operation on the store.
 * @param {(operation: object) => Promise<void>} writer.save Queues one operation and keeps its state.
 * @param {boolean} writer.saving Whether a saved operation is in flight.
 * @param {string} writer.error What the last saved operation resolved to, or empty.
 * @param {() => Promise<void>} writer.reread Reads the followed stores again.
 */
export function propsFor(bind, data, writer) {
  if (bind.key !== undefined) {
    return keyProps(bind, data, writer);
  }
  if (bind.record !== undefined) {
    return recordProps(bind, data, writer);
  }
  return { value: data.records, schema: data.schema, git: data.git, write: writer.write, reread: writer.reread };
}

/**
 * The props for one key of a record.
 *
 * @param {{record: string, key: string}} bind The binding.
 * @param data The target's data, with its `record`.
 * @param writer How the component changes the store.
 */
function keyProps({ record, key }, data, writer) {
  return { value: data.record.values[key], onChange: (value) => writer.save({ op: 'set', id: record, key, value }), saving: writer.saving, error: writer.error };
}

/**
 * The props for one record.
 *
 * @param {{record: string}} bind The binding.
 * @param data The target's data, with its `record`.
 * @param writer How the component changes the store.
 */
function recordProps({ record }, data, writer) {
  return { value: data.record.values, schema: data.schema, git: data.git, write: (operation) => writer.write({ ...operation, id: record }), reread: writer.reread };
}
