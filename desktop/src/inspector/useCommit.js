/**
 * @file The hook a field uses to save as soon as its control changes: the
 * save, whether one is running, and the message from the last one.
 */

import { useState } from 'react';

/**
 * Wraps `commit` so a field can save as soon as its control changes. Answers
 * `save`, which commits one operation; `saving`, true while a save runs;
 * and `error`, the message the last save resolved to, or empty.
 *
 * @param {(operation: object) => Promise<string | null>} commit Saves one change to the key.
 */
export function useCommit(commit) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const save = async (operation) => {
    setSaving(true);
    const message = await commit(operation);
    setSaving(false);
    setError(message ?? '');
  };
  return { save, saving, error };
}
