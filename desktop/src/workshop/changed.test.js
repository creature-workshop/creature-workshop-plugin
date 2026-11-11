/**
 * @file A quiet read keeps the stored answer unless it differs.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { changed } from './changed.js';

describe('changed', () => {
  it('keeps the stored object when the answer is equal', () => {
    const before = { state: 'success', data: { declared: [{ tool: 'uv' }] } };
    assert.equal(changed(before, { declared: [{ tool: 'uv' }] }), before);
  });

  it('stores the new answer when it differs', () => {
    const before = { state: 'success', data: { declared: [] } };
    assert.deepEqual(changed(before, { declared: [{ tool: 'uv' }] }), { state: 'success', data: { declared: [{ tool: 'uv' }] } });
  });

  it('stores the answer over a loading or failed read', () => {
    assert.deepEqual(changed({ state: 'loading' }, { a: 1 }), { state: 'success', data: { a: 1 } });
    assert.deepEqual(changed({ state: 'failure', error: {} }, { a: 1 }), { state: 'success', data: { a: 1 } });
  });
});
