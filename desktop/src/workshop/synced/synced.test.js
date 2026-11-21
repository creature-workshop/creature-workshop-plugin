/**
 * @file The pane's synced files against a backend the test answers by
 * hand: what a file's view is before and after a read, which files a read
 * asks for, whose listeners an answer calls and when, and how a
 * write shows, is sent, is confirmed, is refused, and makes an older read's
 * answer be dropped.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { create } from './synced.js';
import { STALE_MESSAGE } from './writeMessage.js';

/** The manifest. */
const MANIFEST = Object.freeze({ kind: 'file', source: 'config/manifest.yaml' });

/** The plan. */
const PLAN = Object.freeze({ kind: 'plan', source: 'data/plan.yaml' });

/** The checkout every test reads. */
const ROOT = '/home/someone/notes';

/**
 * A record of the manifest.
 *
 * @param {string} revision The record's revision.
 * @param {Record<string, unknown>} values The record's values.
 */
function record(revision, values) {
  return { id: 'document', revision, values };
}

/**
 * A snapshot for the manifest, as read.js reads one.
 *
 * @param {object} held The record it holds.
 * @param {string} [git] The state of its file in git.
 */
function snapshot(held, git = 'clean') {
  return { ...MANIFEST, records: [held], schema: { type: 'object' }, git };
}

/**
 * A backend whose calls the test answers by hand. `calls` lists every call
 * made, as `{name, args, answer}`, where `answer(result)` resolves the
 * call. `synced` is the synced files of ROOT over it.
 */
function backend() {
  const calls = [];
  const call = (name) => (...args) => new Promise((answer) => calls.push({ name, args, answer }));
  return { calls, synced: create({ root: ROOT, sync: call('sync'), mutate: call('mutate') }) };
}

/**
 * Lets every promise that is ready run, so a call's answer has been kept
 * before the test reads the view.
 */
function settled() {
  return new Promise((resolve) => setImmediate(resolve));
}

/**
 * Answers a call with a successful result, and waits for it to be kept.
 *
 * @param call The call, from a backend's `calls`.
 * @param data The result's data.
 */
async function answer(call, data) {
  call.answer({ ok: true, data });
  await settled();
}

/**
 * A backend whose manifest has been followed and read once, holding
 * `held`. `heard` counts the calls of the listener.
 *
 * @param {object} held The record the first read answers.
 */
async function reading(held) {
  const made = backend();
  const heard = { count: 0 };
  made.synced.follow(MANIFEST, () => { heard.count += 1; });
  await answer(made.calls[0], { files: [snapshot(held)] });
  return { ...made, heard };
}

describe('follow and view', () => {
  it('view is loading until the first read answers, then holds the snapshot', async () => {
    const { synced, calls } = backend();
    assert.equal(synced.view(MANIFEST).state, 'loading');
    synced.follow(MANIFEST, () => {});
    assert.deepEqual(calls[0].args, [ROOT, [MANIFEST]]);
    await answer(calls[0], { files: [snapshot(record('r1', { name: 'Notes' }), 'modified')] });
    assert.deepEqual(synced.view(MANIFEST), { state: 'success', data: { records: [record('r1', { name: 'Notes' })], schema: { type: 'object' }, git: 'modified' } });
  });

  it('view is the same object until the file changes', async () => {
    const { synced } = await reading(record('r1', { name: 'Notes' }));
    assert.equal(synced.view(MANIFEST), synced.view(MANIFEST));
  });

  it('view is a failure for a file the backend answered an error for', async () => {
    const { synced, calls } = backend();
    synced.follow(MANIFEST, () => {});
    await answer(calls[0], { files: [{ ...MANIFEST, error: { message: 'The project has no .ops/config/manifest.yaml.', code: 'NOT_FOUND', status: 404, extensions: {} }, git: null }] });
    const view = synced.view(MANIFEST);
    assert.deepEqual([view.state, view.error.code, view.error.status], ['failure', 'NOT_FOUND', 404]);
  });
});

describe('read', () => {
  it('read asks for each followed file, and for no file nobody follows', async () => {
    const { synced, calls } = await reading(record('r1', { name: 'Notes' }));
    synced.view(PLAN);
    synced.read();
    assert.deepEqual(calls[1].args, [ROOT, [MANIFEST]]);
  });

  it('read keeps the view and calls no listener when the same snapshot is answered again', async () => {
    const { synced, calls, heard } = await reading(record('r1', { name: 'Notes' }));
    const before = synced.view(MANIFEST);
    const count = heard.count;
    synced.read();
    await answer(calls[1], { files: [snapshot(record('r1', { name: 'Notes' }))] });
    assert.equal(synced.view(MANIFEST), before);
    assert.equal(heard.count, count);
  });

  it('read keeps a snapshot whose git state alone changed', async () => {
    const { synced, calls } = await reading(record('r1', { name: 'Notes' }));
    synced.read();
    await answer(calls[1], { files: [snapshot(record('r1', { name: 'Notes' }), 'modified')] });
    assert.equal(synced.view(MANIFEST).data.git, 'modified');
  });

  it('read calls only the listeners of the file whose snapshot changed', async () => {
    const { synced, calls, heard } = await reading(record('r1', { name: 'Notes' }));
    const plan = { count: 0 };
    synced.follow(PLAN, () => { plan.count += 1; });
    const count = heard.count;
    await answer(calls[1], { files: [snapshot(record('r1', { name: 'Notes' })), { ...PLAN, records: [], schema: {}, git: null }] });
    assert.deepEqual([heard.count - count, plan.count], [0, 1]);
  });

  it('read asks nothing once the last listener of every file has stopped', async () => {
    const { synced, calls } = backend();
    const stop = synced.follow(MANIFEST, () => {});
    await answer(calls[0], { files: [snapshot(record('r1', {}))] });
    stop();
    await synced.read();
    assert.equal(calls.length, 1);
  });

  it('a failed read is the view of a file never read, and leaves a file that was read as it is', async () => {
    const unreachable = { ok: false, error: { message: 'no answer', code: 'UNREACHABLE', status: 0, extensions: {} } };
    const fresh = backend();
    fresh.synced.follow(MANIFEST, () => {});
    fresh.calls[0].answer(unreachable);
    await settled();
    assert.deepEqual([fresh.synced.view(MANIFEST).state, fresh.synced.view(MANIFEST).error.code], ['failure', 'UNREACHABLE']);

    const read = await reading(record('r1', { name: 'Notes' }));
    const before = read.synced.view(MANIFEST);
    read.synced.read();
    read.calls[1].answer(unreachable);
    await settled();
    assert.equal(read.synced.view(MANIFEST), before);
  });

  it('a file followed while a read is under way is read as soon as that read is over', async () => {
    const { synced, calls } = backend();
    synced.follow(MANIFEST, () => {});
    synced.follow(PLAN, () => {});
    assert.equal(calls.length, 1);
    await answer(calls[0], { files: [snapshot(record('r1', {}))] });
    assert.deepEqual(calls[1].args[1], [MANIFEST, PLAN]);
  });
});

describe('write', () => {
  it('write shows in the view at once, and calls the listeners', async () => {
    const { synced, heard } = await reading(record('r1', { name: 'Notes', org: 'a' }));
    const count = heard.count;
    synced.write(MANIFEST, { op: 'set', id: 'document', key: 'name', value: 'Field notes' });
    assert.deepEqual(synced.view(MANIFEST).data.records[0].values, { name: 'Field notes', org: 'a' });
    assert.equal(heard.count, count + 1);
  });

  it('write is sent at the revision the record has, and resolves to null once the backend kept it', async () => {
    const { synced, calls } = await reading(record('r1', { name: 'Notes' }));
    const written = synced.write(MANIFEST, { op: 'set', id: 'document', key: 'name', value: 'Field notes' });
    assert.deepEqual(calls[1].args, [{ ...MANIFEST, root: ROOT }, { op: 'set', id: 'document', key: 'name', value: 'Field notes', revision: 'r1' }]);
    await answer(calls[1], { record: record('r2', { name: 'Field notes' }) });
    assert.equal(await written, null);
    assert.deepEqual(synced.view(MANIFEST).data.records, [record('r2', { name: 'Field notes' })]);
  });

  it('a clear reads as null, a reset as untouched and a delete as no record, while in flight', async () => {
    const { synced } = await reading(record('r1', { name: 'Notes', org: 'a' }));
    synced.write(MANIFEST, { op: 'clear', id: 'document', key: 'name' });
    assert.deepEqual(synced.view(MANIFEST).data.records[0].values, { name: null, org: 'a' });
    synced.write(MANIFEST, { op: 'reset', id: 'document', key: 'org' });
    assert.deepEqual(synced.view(MANIFEST).data.records[0].values, { name: null });
    synced.write(MANIFEST, { op: 'delete', id: 'document' });
    assert.deepEqual(synced.view(MANIFEST).data.records, []);
  });

  it('writes are sent one at a time, the second at the revision the first one answered', async () => {
    const { synced, calls } = await reading(record('r1', { name: 'Notes' }));
    synced.write(MANIFEST, { op: 'set', id: 'document', key: 'name', value: 'Field notes' });
    synced.write(MANIFEST, { op: 'set', id: 'document', key: 'org', value: 'a' });
    assert.equal(calls.length, 2);
    assert.deepEqual(synced.view(MANIFEST).data.records[0].values, { name: 'Field notes', org: 'a' });
    await answer(calls[1], { record: record('r2', { name: 'Field notes' }) });
    assert.equal(calls[2].args[1].revision, 'r2');
  });

  it('a stale write keeps the record as the file has it, and resolves to STALE_MESSAGE', async () => {
    const { synced, calls } = await reading(record('r1', { name: 'Notes' }));
    const written = synced.write(MANIFEST, { op: 'set', id: 'document', key: 'name', value: 'Field notes' });
    calls[1].answer({ ok: false, error: { message: 'The document changed since it was read.', code: 'STALE', status: 409, extensions: { record: record('r9', { name: 'Theirs' }) } } });
    assert.equal(await written, STALE_MESSAGE);
    assert.deepEqual(synced.view(MANIFEST).data.records, [record('r9', { name: 'Theirs' })]);
  });

  it('a refused write shows what the snapshot holds again, and resolves to why', async () => {
    const { synced, calls } = await reading(record('r1', { name: 'Notes' }));
    const written = synced.write(MANIFEST, { op: 'reset', id: 'document', key: 'name' });
    calls[1].answer({ ok: false, error: { message: 'name cannot be removed: the schema requires it.', code: 'REFUSED', status: 400, extensions: {} } });
    assert.match(await written, /^name cannot be removed: the schema requires it\./);
    assert.deepEqual(synced.view(MANIFEST).data.records, [record('r1', { name: 'Notes' })]);
  });

  it('once the queue is empty the followed files are read again, and that answer is kept even when it is the one before the write', async () => {
    const { synced, calls } = await reading(record('r1', { name: 'Notes' }));
    synced.write(MANIFEST, { op: 'set', id: 'document', key: 'name', value: 'Field notes' });
    await answer(calls[1], { record: record('r2', { name: 'Field notes' }) });
    assert.deepEqual([calls[2].name, calls[2].args[1]], ['sync', [MANIFEST]]);
    await answer(calls[2], { files: [snapshot(record('r1', { name: 'Notes' }))] });
    assert.deepEqual(synced.view(MANIFEST).data.records, [record('r1', { name: 'Notes' })]);
  });

  it('the answer to a read asked for before a write was confirmed is dropped, and the files are read again', async () => {
    const { synced, calls } = await reading(record('r1', { name: 'Notes' }));
    synced.read();
    synced.write(MANIFEST, { op: 'set', id: 'document', key: 'name', value: 'Field notes' });
    await answer(calls[2], { record: record('r2', { name: 'Field notes' }) });
    await answer(calls[1], { files: [snapshot(record('r1', { name: 'Notes' }))] });
    assert.deepEqual(synced.view(MANIFEST).data.records, [record('r2', { name: 'Field notes' })]);
    assert.equal(calls[3].name, 'sync');
  });
});

describe('every', () => {
  it('every reads on the interval until it is stopped', async (context) => {
    context.mock.timers.enable({ apis: ['setInterval'] });
    const { synced, calls } = await reading(record('r1', {}));
    const stop = synced.every(5);
    context.mock.timers.tick(5000);
    assert.equal(calls.length, 2);
    stop();
    context.mock.timers.tick(5000);
    assert.equal(calls.length, 2);
  });
});
