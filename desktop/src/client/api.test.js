/**
 * @file The client registry without a backend: a registered call answers
 * what its request answers, and a failed request hands the fallback the
 * failure, which is the body with errors in Desktop's `<status>: <body>`
 * rejection when there is one, and UNREACHABLE otherwise.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { connect, register } from './api.js';

/** A refusal as the backend answers it. */
const REFUSAL = { data: null, errors: [{ message: 'org cannot be removed: the schema requires it.', extensions: { code: 'REFUSED', status: 400 } }] };

/** A call that answers its fallback's arguments when it fails. */
const probe = register('probe', (rest, path) => rest(path), (failure, path) => ({ failure, path }));

describe('register', () => {
  it('answers what the request answers', async () => {
    connect(async (path) => ({ asked: path }));
    assert.deepEqual(await probe('/x'), { asked: '/x' });
  });

  it('hands the fallback the errors in a rejection, then the call\'s arguments', async () => {
    connect(async () => { throw new Error(`400: ${JSON.stringify(REFUSAL)}`); });
    assert.deepEqual(await probe('/x'), { failure: REFUSAL, path: '/x' });
  });

  it('hands the fallback UNREACHABLE, with the message, when the rejection carries no errors', async () => {
    connect(() => { throw new Error('bridge unavailable'); });
    const unreachable = { data: null, errors: [{ message: 'bridge unavailable', extensions: { code: 'UNREACHABLE', status: 0 } }] };
    assert.deepEqual((await probe('/x')).failure, unreachable);
  });
});
