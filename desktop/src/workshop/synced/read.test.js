/**
 * @file Reading files over a client the test answers: what readFiles
 * asks the client for each file, the snapshots it resolves to, and a call
 * the backend never answered failing the whole read.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFiles } from './read.js';

/** The manifest. */
const MANIFEST = Object.freeze({ kind: 'document', source: 'config/manifest.yaml' });

/** The checkout every test reads. */
const ROOT = '/home/someone/notes';

/** The record the manifest holds. */
const RECORD = Object.freeze({ id: 'document', revision: 'r1', values: { name: 'Notes' } });

/** The failure of a call the backend never answered. */
const UNREACHABLE = Object.freeze({ ok: false, error: { message: 'no answer', code: 'UNREACHABLE', status: 0, extensions: {} } });

/** The failure of a query for a file that is not there. */
const NOT_FOUND = Object.freeze({ ok: false, error: { message: 'The project has no .ops/config/manifest.yaml.', code: 'NOT_FOUND', status: 404, extensions: {} } });

/**
 * A client whose three calls answer what the test names, and record what
 * they were asked.
 *
 * @param answers What each call answers.
 * @param [answers.query] The result of `query`; the manifest's record when left out.
 * @param [answers.introspect] The result of `introspect`; an object schema when left out.
 * @param [answers.fileState] The result of `fileState`; `modified` when left out.
 * @param {unknown[][]} [asked] Takes the arguments of each call.
 */
function clientAnswering({ query, introspect, fileState }, asked = []) {
  const answering = (result) => async (...args) => { asked.push(args); return result; };
  return {
    query: answering(query ?? { ok: true, data: { records: [RECORD] } }),
    introspect: answering(introspect ?? { ok: true, data: { schema: { type: 'object' } } }),
    fileState: answering(fileState ?? { ok: true, data: { state: 'modified' } }),
  };
}

describe('readFiles', () => {
  it('asks for a file’s records, its schema and its state in git, by its path under .ops/', async () => {
    const asked = [];
    await readFiles(clientAnswering({}, asked), ROOT, [MANIFEST]);
    assert.deepEqual(asked, [[{ ...MANIFEST, root: ROOT }], [{ ...MANIFEST, root: ROOT }], [ROOT, '/home/someone/notes/.ops/config/manifest.yaml']]);
  });

  it('resolves to one snapshot for each file, in the order asked', async () => {
    const plan = { kind: 'plan', source: 'data/plan.yaml' };
    const result = await readFiles(clientAnswering({}), ROOT, [MANIFEST, plan]);
    assert.deepEqual(result.data.files.map(({ kind, source }) => ({ kind, source })), [MANIFEST, plan]);
  });

  it('reads a file the backend answered an error for as a snapshot with that error', async () => {
    const result = await readFiles(clientAnswering({ query: NOT_FOUND }), ROOT, [MANIFEST]);
    assert.deepEqual(result, { ok: true, data: { files: [{ ...MANIFEST, error: NOT_FOUND.error, git: 'modified' }] } });
  });

  it('fails the whole read when the backend never answered a call', async () => {
    assert.equal(await readFiles(clientAnswering({ introspect: UNREACHABLE }), ROOT, [MANIFEST]), UNREACHABLE);
  });

  it('reads no file as no snapshots', async () => {
    assert.deepEqual(await readFiles(clientAnswering({}), ROOT, []), { ok: true, data: { files: [] } });
  });
});
