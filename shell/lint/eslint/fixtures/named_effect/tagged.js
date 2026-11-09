/** @file Effects passed by name and made by factory calls, each tagged for its hook, and a call that is not an effect. */

/** The project as state. */
export function useProject(store, useEffect, useState) {
  const [project, setProject] = useState(store.get());
  useEffect(subscribeTo(store, setProject), [store]);
  return project;
}

/** Logs that the component mounted. */
export function useMountLog(useEffect) {
  useEffect(logMount, []);
}

/** The element's width as state. */
export function useWidth(ref, useLayoutEffect, useState) {
  const [width, setWidth] = useState(0);
  useLayoutEffect(measure(ref, setWidth), [ref]);
  return width;
}

/** Reads once. */
export function readOnce(store, useMemo) {
  return useMemo(() => store.get(), [store]);
}

/**
 * The effect that keeps the project in step with the store while the component is mounted.
 *
 * @effect
 */
function subscribeTo(store, setProject) {
  return () => store.subscribe(setProject);
}

/**
 * Logs that a component mounted.
 *
 * @effect
 */
const logMount = () => undefined;

/**
 * The layout effect that reads the element's width before paint.
 *
 * @layoutEffect
 */
function measure(ref, setWidth) {
  return () => setWidth(ref.current.clientWidth);
}
