/** @file An effect with its doc block, and a call that is not an effect. */

/** The project as state. */
export function useProject(store, useEffect, useState) {
  const [project, setProject] = useState(store.get());
  /** Subscribes to the store for as long as the component is mounted. */
  useEffect(() => store.subscribe(setProject), [store]);
  return project;
}

/** Reads once. */
export function readOnce(store, useMemo) {
  return useMemo(() => store.get(), [store]);
}
