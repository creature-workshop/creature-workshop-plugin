/**
 * @file A component that throws while rendering, for the boundary's test and
 * nothing else; plugin.jsx never imports it.
 */

/** Throws on render. */
export function Broken() {
  throw new Error('broken on purpose');
}
