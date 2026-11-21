/**
 * @file Making a snapshot from the backend's three answers about a file:
 * the records, the schema and the git state together; the backend's error
 * in place of its records; and a file git says nothing about.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { snapshotFrom } from './opsFileSnapshot.js';

/** The manifest. */
const MANIFEST = Object.freeze({ kind: 'document', source: 'config/manifest.yaml' });

/** The record the manifest holds. */
const RECORD = Object.freeze({ id: 'document', revision: 'r1', values: { name: 'Notes' } });

/** The result of a query that answered the manifest's record. */
const QUERIED = Object.freeze({ ok: true, data: { records: [RECORD] } });

/** The result of an introspection that answered an object schema. */
const DESCRIBED = Object.freeze({ ok: true, data: { schema: { type: 'object' } } });

/** The failure of a query for a file that is not there. */
const NOT_FOUND = Object.freeze({ ok: false, error: { message: 'The project has no .ops/config/manifest.yaml.', code: 'NOT_FOUND', status: 404, extensions: {} } });

/** The failure of a call the backend answered with a bug of its own. */
const INTERNAL = Object.freeze({ ok: false, error: { message: 'bug', code: 'INTERNAL', status: 500, extensions: {} } });

/**
 * The result of a file-state call that answered `state`.
 *
 * @param {string} state The state answered.
 */
function inState(state) {
  return { ok: true, data: { state } };
}

describe('snapshotFrom', () => {
  it('puts a file’s records, schema and git state together', () => {
    const snapshot = snapshotFrom(MANIFEST, { queried: QUERIED, described: DESCRIBED, state: inState('modified') });
    assert.deepEqual(snapshot, { ...MANIFEST, records: [RECORD], schema: { type: 'object' }, git: 'modified' });
  });

  it('has an empty schema when the backend describes none', () => {
    const snapshot = snapshotFrom(MANIFEST, { queried: QUERIED, described: { ok: true, data: {} }, state: inState('clean') });
    assert.deepEqual(snapshot.schema, {});
  });

  it('has the backend’s error for a file in place of its records and schema, with the file’s state', () => {
    const snapshot = snapshotFrom(MANIFEST, { queried: NOT_FOUND, described: DESCRIBED, state: inState('deleted') });
    assert.deepEqual(snapshot, { ...MANIFEST, error: NOT_FOUND.error, git: 'deleted' });
  });

  it('has no git state for a file git says nothing about, or when the state could not be read', () => {
    const none = snapshotFrom(MANIFEST, { queried: QUERIED, described: DESCRIBED, state: inState('none') });
    const failed = snapshotFrom(MANIFEST, { queried: QUERIED, described: DESCRIBED, state: INTERNAL });
    assert.deepEqual([none.git, failed.git], [null, null]);
  });
});
