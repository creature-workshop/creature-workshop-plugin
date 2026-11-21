/**
 * @file The plain parts of binding a component to the synced files: what
 * a binding names inside a file's view, the props a bound component gets
 * for a file, a record and a key, and which elements the JSX runtime
 * wraps.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { propsFor } from './props.js';
import { targetOf } from './target.js';
import { wrapped } from './wrap.js';

/** The manifest. */
const MANIFEST = Object.freeze({ kind: 'document', source: 'config/manifest.yaml' });

/** The record the file's view holds. */
const RECORD = Object.freeze({ id: 'document', revision: 'r1', values: { name: 'Notes', org: null } });

/** The file's view once it has been read. */
const VIEW = Object.freeze({ state: 'success', data: { records: [RECORD], schema: { type: 'object' }, git: 'modified' } });

/**
 * A writer whose `write` and `save` record the operations they are given.
 *
 * @param {object[]} sent Takes each operation.
 */
function writer(sent) {
  const keep = async (operation) => { sent.push(operation); return null; };
  return { write: keep, save: keep, saving: true, error: 'No.', reread: () => 'read again' };
}

/** Stands in for the wrapper component: a function the test only compares by identity. */
function wrapperStandIn() {
  return null;
}

/** Stands in for a component of the pane: a function the test only compares by identity. */
function fieldStandIn() {
  return null;
}

/**
 * Stands in for React's jsx: answers what it was asked to make.
 *
 * @param type The element's type.
 * @param props The element's props.
 * @param key The element's key.
 */
function make(type, props, key) {
  return { type, props, key };
}

describe('targetOf', () => {
  it('hands a file binding the view as it is', () => {
    assert.equal(targetOf(MANIFEST, VIEW), VIEW);
  });

  it('adds the record a record binding names', () => {
    assert.deepEqual(targetOf({ ...MANIFEST, record: 'document' }, VIEW), { state: 'success', data: { ...VIEW.data, record: RECORD } });
  });

  it('is a NOT_FOUND failure for a record the file does not hold', () => {
    const target = targetOf({ ...MANIFEST, record: 'other' }, VIEW);
    assert.deepEqual([target.state, target.error.code, target.error.message], ['failure', 'NOT_FOUND', 'config/manifest.yaml has no record other.']);
  });

  it('hands back a view that is loading or failed', () => {
    const loading = { state: 'loading' };
    assert.equal(targetOf({ ...MANIFEST, record: 'document' }, loading), loading);
  });
});

describe('propsFor', () => {
  it('gives a file binding every record, the schema, the git state and the write', async () => {
    const sent = [];
    const props = propsFor(MANIFEST, VIEW.data, writer(sent));
    assert.deepEqual([props.value, props.schema, props.git, props.reread()], [[RECORD], { type: 'object' }, 'modified', 'read again']);
    await props.write({ op: 'create', values: {} });
    assert.deepEqual(sent, [{ op: 'create', values: {} }]);
  });

  it('gives a record binding the record’s values and a write to that record', async () => {
    const sent = [];
    const props = propsFor({ ...MANIFEST, record: 'document' }, { ...VIEW.data, record: RECORD }, writer(sent));
    assert.deepEqual([props.value, props.git], [RECORD.values, 'modified']);
    await props.write({ op: 'clear', key: 'name' });
    assert.deepEqual(sent, [{ op: 'clear', key: 'name', id: 'document' }]);
  });

  it('gives a key binding the props of a controlled component', async () => {
    const sent = [];
    const props = propsFor({ ...MANIFEST, record: 'document', key: 'name' }, { ...VIEW.data, record: RECORD }, writer(sent));
    assert.deepEqual([props.value, props.saving, props.error, Object.keys(props)], ['Notes', true, 'No.', ['value', 'onChange', 'saving', 'error']]);
    await props.onChange('Field notes');
    assert.deepEqual(sent, [{ op: 'set', id: 'document', key: 'name', value: 'Field notes' }]);
  });

  it('gives a key binding undefined for an untouched key and null for a cleared one', () => {
    const data = { ...VIEW.data, record: RECORD };
    assert.equal(propsFor({ ...MANIFEST, record: 'document', key: 'repo' }, data, writer([])).value, undefined);
    assert.equal(propsFor({ ...MANIFEST, record: 'document', key: 'org' }, data, writer([])).value, null);
  });
});

describe('wrapped', () => {
  it('makes a component given bind inside the wrapper, with the component as bound', () => {
    assert.deepEqual(wrapped(wrapperStandIn, make, fieldStandIn, { label: 'Name', bind: MANIFEST }, 'k'), { type: wrapperStandIn, props: { label: 'Name', bind: MANIFEST, bound: fieldStandIn }, key: 'k' });
  });

  it('makes a component without bind, a host element and the wrapper itself unchanged', () => {
    const props = { bind: MANIFEST };
    assert.deepEqual(wrapped(wrapperStandIn, make, fieldStandIn, { label: 'Name' }), { type: fieldStandIn, props: { label: 'Name' }, key: undefined });
    assert.equal(wrapped(wrapperStandIn, make, 'div', props).props, props);
    assert.equal(wrapped(wrapperStandIn, make, wrapperStandIn, props).props, props);
  });
});
