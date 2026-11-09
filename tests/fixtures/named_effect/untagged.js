/** @file An effect without a tag, a layout effect with the other hook's tag, and an effect the file does not define. */

import { logMount } from './elsewhere.js';

/** The project as state. */
export function useProject(store, useEffect, useState) {
  const [project, setProject] = useState(store.get());
  useEffect(subscribeTo(store, setProject), [store]);
  return project;
}

/** The element's width as state. */
export function useWidth(ref, useLayoutEffect, useState) {
  const [width, setWidth] = useState(0);
  useLayoutEffect(measure, [ref]);
  return width;
}

/** Logs that the component mounted. */
export function useMountLog(useEffect) {
  useEffect(logMount, []);
}

/** The effect that keeps the project in step with the store. */
function subscribeTo(store, setProject) {
  return () => store.subscribe(setProject);
}

/**
 * Reads a width.
 *
 * @effect
 */
function measure() {
  return undefined;
}
