/**
 * @file How the pane asks for a piece of its shared state again.
 */

import { useCallback, useState } from 'react';

/** How many times each piece has been asked for again, before anyone has. */
const NOT_RETRIED = Object.freeze({ about: 0, repos: 0, project: 0 });

/**
 * Returns `[retried, retry]`: how many times `about`, `repos` and `project`
 * have each been asked for again, and `retry(name)`, which asks for one of
 * them again. A piece reloads whenever its count changes.
 */
export function useRetry() {
  const [retried, setRetried] = useState(NOT_RETRIED);
  const retry = useCallback((name) => setRetried((before) => ({ ...before, [name]: before[name] + 1 })), []);
  return [retried, retry];
}
