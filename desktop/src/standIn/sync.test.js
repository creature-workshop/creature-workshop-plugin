/**
 * @file The stand-in's POST /store/sync over a story's own answers: an
 * entry built from the story's query and introspect answers, a current
 * stamp answered as unchanged, a store's own error put in its entry, and
 * any other rejection rejecting the sync.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { standIn } from './index.js';

/** The manifest's store, as a sync asks for it. */
const MANIFEST = Object.freeze({ kind: 'file', source: 'config/manifest.yaml' });

/** The record the story's backend answers. */
const RECORD = Object.freeze({ id: 'document', revision: 'r1', values: { name: 'Notes' } });

/**
 * POST /store/sync on a stand-in over `answer`, for the manifest with `stamp`.
 *
 * @param answer The story's backend call.
 * @param {string} [stamp] The stamp to ask with.
 */
function sync(answer, stamp = '') {
  return standIn(answer)('/store/sync', { method: 'POST', body: { root: '/home/someone/notes', stores: [{ ...MANIFEST, stamp }] } });
}

/**
 * A story's backend call that answers the manifest's record and schema.
 *
 * @param {string} [git] The git state the query answer carries.
 */
function reading(git) {
  return async (path) => (path.startsWith('/store/query') ? { data: { record: RECORD, git } } : { data: { schema: { type: 'object' } } });
}

describe('the stand-in sync', () => {
  it('builds an entry from the story’s query and introspect answers', async () => {
    const [entry] = (await sync(reading('modified'))).data.stores;
    assert.deepEqual({ ...entry, stamp: '' }, { ...MANIFEST, stamp: '', records: [RECORD], schema: { type: 'object' }, git: 'modified' });
  });

  it('gives no git state when the story names none', async () => {
    const [entry] = (await sync(reading())).data.stores;
    assert.equal(entry.git, null);
  });

  it('answers only unchanged for the stamp it gave', async () => {
    const [entry] = (await sync(reading())).data.stores;
    assert.deepEqual((await sync(reading(), entry.stamp)).data.stores, [{ ...MANIFEST, stamp: entry.stamp, unchanged: true }]);
  });

  it('puts a store’s own error in its entry', async () => {
    const refusal = { data: null, errors: [{ message: 'The project has no .ops/config/manifest.yaml.', extensions: { code: 'NOT_FOUND', status: 404 } }] };
    const [entry] = (await sync(async () => { throw new Error(`404: ${JSON.stringify(refusal)}`); })).data.stores;
    assert.deepEqual([entry.error.extensions.code, entry.git], ['NOT_FOUND', null]);
  });

  it('rejects when the story’s backend rejects with no store error', async () => {
    await assert.rejects(sync(async () => { throw new Error('never reached the backend'); }), /never reached the backend/);
  });
});
