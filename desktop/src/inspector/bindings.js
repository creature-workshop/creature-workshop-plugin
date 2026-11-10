/**
 * @file The bindings the inspector knows. A binding says what a part of
 * the pane shows: which record, which of its keys, and which component
 * draws each key. It plays the part a GraphQL query plays. Keys it does not
 * list are not shown.
 */

/** Every registered binding, by id. */
const bindings = new Map();

/**
 * Adds a binding to the list under its id, replacing any binding already
 * there under that id, and returns it, made read-only, with each of its
 * fields built by boundField.
 *
 * @param {object} binding The binding.
 * @param {string} binding.id The binding's name, unique across the pane.
 * @param {string} binding.title The heading of its group of fields.
 * @param {{kind: string, source: string}} binding.collection The collection the record is in, less the project's root, which the inspector adds.
 * @param {string} binding.record The record's id.
 * @param {object[]} binding.fields The keys to show, in order, each as boundField takes it.
 */
export function register({ id, title, collection, record, fields }) {
  const frozen = Object.freeze({
    id,
    title,
    collection: Object.freeze({ kind: collection.kind, source: collection.source }),
    record,
    fields: Object.freeze(fields.map(boundField)),
  });
  bindings.set(id, frozen);
  return frozen;
}

/**
 * One key a binding shows, made read-only. Throws a TypeError when the key
 * or the component's name is missing.
 *
 * @param {object} field The field.
 * @param {string} field.key The record's top-level key.
 * @param {string} field.component The name of the field component that draws it.
 * @param {string} [field.label] The field's name; the schema's title, or the key, when left out.
 * @param {boolean} [field.readOnly] Whether the field only shows its value; false when left out.
 */
export function boundField({ key, component, label, readOnly = false }) {
  if (typeof key !== 'string' || typeof component !== 'string') {
    throw new TypeError('A bound field needs a key and the name of its component.');
  }
  return Object.freeze({ key, component, label, readOnly });
}

/**
 * The binding registered under `id`, as register returned it, or null when
 * there is none.
 *
 * @param {string} id The binding's id.
 */
export function registered(id) {
  return bindings.get(id) ?? null;
}
