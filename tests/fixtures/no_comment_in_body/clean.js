/** @file Comments above declarations, a directive inside a body, and an effect's doc block. */

/** Adds one. */
export function addOne(value) {
  // eslint-disable-next-line no-console -- the one place the file prints
  console.log(value);
  return value + 1;
}

/** Doubles. */
const double = (value) => value * 2;

/** The project as state. */
export function useProject(store, useEffect, useState) {
  const [project, setProject] = useState(store.get());
  /** Subscribes to the store for as long as the component is mounted. */
  useEffect(() => store.subscribe(setProject), [store]);
  return project;
}

export default double;
