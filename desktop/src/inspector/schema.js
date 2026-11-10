/**
 * @file Helpers that read a JSON Schema for one key: how the key is
 * described, which types it accepts, whether it is required or can be
 * cleared; and whether a key is untouched (missing), cleared (null) or set.
 */

/**
 * The schema's definition of a key, or undefined when the schema does not
 * describe it.
 *
 * @param schema The document's schema.
 * @param {string} key The key.
 */
export function definitionOf(schema, key) {
  return schema?.properties?.[key];
}

/**
 * The types a definition allows; empty when it names none, which allows any.
 *
 * @param definition The key's definition.
 *
 * @returns {string[]} The types.
 */
export function typesOf(definition) {
  const declared = definition?.type ?? [];
  return Array.isArray(declared) ? declared : [declared];
}

/**
 * Whether the schema requires the key.
 *
 * @param schema The document's schema.
 * @param {string} key The key.
 */
export function isRequired(schema, key) {
  return (schema?.required ?? []).includes(key);
}

/**
 * Whether the key may be cleared: it is not required, and its definition
 * allows null.
 *
 * @param definition The key's definition.
 * @param {boolean} required Whether the schema requires the key.
 */
export function canClear(definition, required) {
  return !required && typesOf(definition).includes('null');
}

/**
 * Which state a key is in: untouched when absent, cleared when null, set
 * otherwise, including false, 0 and an empty string.
 *
 * @param {Record<string, unknown>} values The record's values.
 * @param {string} key The key.
 *
 * @returns {'untouched' | 'cleared' | 'set'} The state.
 */
export function stateOf(values, key) {
  if (!(key in values)) {
    return 'untouched';
  }
  return values[key] === null ? 'cleared' : 'set';
}
