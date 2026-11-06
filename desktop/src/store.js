/**
 * @file The one place the loaded project lives, and the hook that reads it.
 * The pane and the chip are two separate render roots, so they cannot share
 * React state; they share this store, made once in register() and handed to
 * both.
 */
import { useEffect, useState } from 'react';

/** A new store holding no project, with get, set and subscribe. */
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

/**
 * The store's project as React state, re-rendering the caller on every set.
 * @param store The store the pane and the chip share.
 */
export function useProject(store) {
  const [project, setProject] = useState(store.get());
  /** Subscribes to the store for as long as the caller is mounted, and again if the store changes. */
  useEffect(() => {
    const unsubscribe = store.subscribe(setProject);
    return unsubscribe;
  }, [store]);
  return project;
}
