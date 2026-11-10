/**
 * @file What a field shows in place of a value it does not have: the words
 * for an untouched key and for a cleared one.
 */

/**
 * "Not set", with the default that applies when there is one, for an
 * untouched key; "Cleared" for a cleared one; empty for a key that is set.
 *
 * @param {'untouched' | 'cleared' | 'set'} state The key's state.
 * @param {string} fallback The schema's default as text, or empty.
 */
export function stateText(state, fallback) {
  if (state === 'untouched') {
    return fallback ? `Not set (default: ${fallback})` : 'Not set';
  }
  return state === 'cleared' ? 'Cleared' : '';
}
