/**
 * @file The list of field components: the editors the inspector can draw.
 * Each one is registered under a name, along with the type of value it
 * saves. A binding says which one to use for each field, by that name; the
 * inspector never picks one on its own.
 */

/** Every registered component, by name. */
const components = new Map();

/**
 * Adds a component to the list under its name, replacing any component
 * already there under that name, and returns it, made read-only. Throws a
 * TypeError when the name is missing, when the type it saves names no
 * JSON Schema type, or when there is no React component.
 *
 * @param {object} component The component.
 * @param {string} component.id The name a binding uses for it.
 * @param {object} component.stores The type of value it saves, as JSON Schema, such as `{type: 'string'}`; a list of types when it saves several.
 * @param {(props: object) => unknown} component.Component The React component that draws it; it receives the props that fieldProps builds.
 *
 * @returns {Readonly<{id: string, stores: object, Component: (props: object) => unknown}>} The registered component.
 */
export function register({ id, stores, Component }) {
  check(typeof id === 'string' && id !== '', 'A field component needs a name.');
  check([stores?.type].flat().every((type) => typeof type === 'string') && stores?.type !== undefined, `The field component ${id} needs the type of value it saves.`);
  check(typeof Component === 'function', `The field component ${id} needs a React component.`);
  const frozen = Object.freeze({ id, stores: Object.freeze({ ...stores }), Component });
  components.set(id, frozen);
  return frozen;
}

/**
 * The component listed under the name `id`, as register returned it, or
 * null when there is none.
 *
 * @param {string} id The component's name.
 */
export function componentFor(id) {
  return components.get(id) ?? null;
}

/**
 * Throws a TypeError with `message` unless `holds`.
 *
 * @param {boolean} holds Whether the condition holds.
 * @param {string} message What is wrong when it does not.
 */
function check(holds, message) {
  if (!holds) {
    throw new TypeError(message);
  }
}
