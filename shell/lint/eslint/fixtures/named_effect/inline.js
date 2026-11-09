/** @file An effect written as an arrow, and a layout effect written as a function expression. */

/** The project as state. */
export function useProject(store, useEffect, useState) {
  const [project, setProject] = useState(store.get());
  useEffect(() => store.subscribe(setProject), [store]);
  return project;
}

/** The element's width as state. */
export function useWidth(ref, useLayoutEffect, useState) {
  const [width, setWidth] = useState(0);
  useLayoutEffect(function measure() { setWidth(ref.current.clientWidth); }, [ref]);
  return width;
}
