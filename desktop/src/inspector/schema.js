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
 * The types a definition allows, including those of each alternative in
 * its `anyOf` or `oneOf`; empty when it, or any alternative, names none,
 * which allows any.
 *
 * @param definition The key's definition.
 *
 * @returns {string[]} The types.
 */
export function typesOf(definition) {
  const alternatives = definition?.anyOf ?? definition?.oneOf;
  if (alternatives) {
    return alternativeTypes(alternatives);
  }
  const declared = definition?.type ?? [];
  return Array.isArray(declared) ? declared : [declared];
}

/**
 * The types a list of alternatives allows together; empty when any of them
 * allows any.
 *
 * @param {object[]} alternatives The alternatives.
 *
 * @returns {string[]} The types.
 */
function alternativeTypes(alternatives) {
  const each = alternatives.map(typesOf);
  return each.some((types) => types.length === 0) ? [] : [...new Set(each.flat())];
}

/**
 * The string options a definition lists in its `enum`, or in the `enum` of
 * the first of its alternatives that has one; empty when there are none.
 *
 * @param definition The key's definition.
 *
 * @returns {string[]} The options, in order.
 */
export function optionsOf(definition) {
  const listed = definition?.enum ?? (definition?.anyOf ?? definition?.oneOf ?? []).find((branch) => branch.enum)?.enum ?? [];
  return listed.filter((option) => typeof option === 'string');
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
