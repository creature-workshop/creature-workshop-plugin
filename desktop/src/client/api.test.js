/**
 * @file The client registry without a backend: a registered call answers
 * a result and never throws. A plain body is the data, a GraphQL-shaped
 * body is its data or its first error, and a rejection is the error in
 * Desktop's `<status>: <body>` message when there is one, NO_ROUTE for a
 * bare 404, and UNREACHABLE otherwise.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { connect, register } from './api.js';

/** A refusal as the backend answers it. */
const REFUSAL = { data: null, errors: [{ message: 'org cannot be removed: the schema requires it.', extensions: { code: 'REFUSED', status: 400 } }] };

/** A call that asks for whatever path it is given. */
const probe = register('probe', (rest, path) => rest(path));

describe('register', () => {
  it('answers a plain body as the data', async () => {
    connect(async (path) => ({ asked: path }));
    assert.deepEqual(await probe('/x'), { ok: true, data: { asked: '/x' } });
  });

  it('answers a GraphQL-shaped body as its data', async () => {
    connect(async () => ({ data: { record: { id: 'document' } } }));
    assert.deepEqual(await probe('/x'), { ok: true, data: { record: { id: 'document' } } });
  });

  it('answers a GraphQL-shaped body with errors as its first error, as the store answers a 3xx', async () => {
    connect(async () => ({ data: null, errors: [{ message: 'Nothing changed.', extensions: { code: 'UNCHANGED', status: 304 } }] }));
    const result = await probe('/x');
    assert.equal(result.ok, false);
    assert.deepEqual([result.error.code, result.error.status, result.error.message], ['UNCHANGED', 304, 'Nothing changed.']);
  });

  it('reads the error from the body of a rejection', async () => {
    connect(async () => { throw new Error(`400: ${JSON.stringify(REFUSAL)}`); });
    const { error } = await probe('/x');
    assert.deepEqual([error.code, error.status, error.message], ['REFUSED', 400, 'org cannot be removed: the schema requires it.']);
  });

  it('answers NO_ROUTE for a 404 whose body carries no errors', async () => {
    connect(async () => { throw new Error('404: {"detail":"Not Found"}'); });
    const { error } = await probe('/x');
    assert.deepEqual([error.code, error.status], ['NO_ROUTE', 404]);
  });

  it('answers UNREACHABLE, with the message, when the request throws at once without a body', async () => {
    connect(() => { throw new Error('bridge unavailable'); });
    const { error } = await probe('/x');
    assert.deepEqual([error.code, error.status, error.message], ['UNREACHABLE', 0, 'bridge unavailable']);
  });
});
