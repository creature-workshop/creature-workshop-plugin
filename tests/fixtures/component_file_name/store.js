/** @file A file that declares no component passes whatever its name. */

/** A store. */
export function createStore() {
  return { get: () => 1 };
}
