/**
 * @file The one place the loaded project lives, and the hook that reads it.
 * The pane and the chip are two separate render roots, so they cannot share
 * React state; they share this store, made once in register() and handed to
 * both.
 */
import { useEffect, useState } from 'react';

export function createStore() {
  let project = { found: false };
  const listeners = new Set();
  return {
    get: () => project,
    set(next) {
      project = next;
      for (const listener of listeners) listener(project);
    },
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
  };
}

/** The store's project as React state, re-rendering the caller on every set. */
export function useProject(store) {
  const [project, setProject] = useState(store.get());
  useEffect(() => store.subscribe(setProject), [store]);
  return project;
}
