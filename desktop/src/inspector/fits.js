/**
 * @file Checks that a component can save to a key of a file someone else
 * owns, such as the manifest: the type the component saves must be one the
 * file's schema accepts for that key. When it is not, the field explains
 * the problem instead of offering an editor; the inspector never swaps in
 * another component.
 */

import { typesOf } from './schema.js';

/** What each JSON Schema type is called in a message to the user. */
const PLAIN = Object.freeze({
  string: 'text',
  number: 'a number',
  integer: 'a whole number',
  boolean: 'on or off',
  array: 'a list',
  object: 'a group of settings',
});

/**
 * Null when the component can save to the key, or the reason it cannot:
 * the component saves a type the key does not accept. A component may save
 * several types, and the key must accept each of them.
 *
 * @param {object} component The component, as register in components.js returns it.
 * @param {string} key The key.
 * @param {object} definition The key's definition in the file's schema.
 *
 * @returns {string | null} The reason, or null.
 */
export function misfit(component, key, definition) {
  const allowed = typesOf(definition).filter((type) => type !== 'null');
  const saved = [component.stores.type].flat();
  if (allowed.length === 0 || saved.every((type) => accepts(allowed, type))) {
    return null;
  }
  return `the pane would save ${saved.map(plain).join(' or ')} here, but ${key} takes ${allowed.map(plain).join(' or ')}.`;
}

/**
 * Whether a key that allows `allowed` accepts a value of `type`. A key that
 * allows only integers accepts a component that saves numbers, since that
 * component reads the key's definition and saves whole numbers to it.
 *
 * @param {string[]} allowed The types the key allows.
 * @param {string} type The type the component saves.
 */
function accepts(allowed, type) {
  return allowed.includes(type) || (type === 'number' && allowed.includes('integer'));
}

/**
 * A type as a message to the user calls it: "text", "a whole number".
 *
 * @param {string} type The JSON Schema type.
 */
function plain(type) {
  return PLAIN[type] ?? type;
}
