/** @file An effect without a doc block, and one with only a line comment. */

/** The project as state. */
export function useProject(store, useEffect, useState) {
  const [project, setProject] = useState(store.get());
  useEffect(() => store.subscribe(setProject), [store]);
  return project;
}

/** The project, reloaded. */
export function useReload(load, useEffect) {
  // loads
  useEffect(() => load(), [load]);
}
