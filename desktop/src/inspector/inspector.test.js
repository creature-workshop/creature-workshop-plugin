/**
 * @file The inspector without a screen: the component and binding
 * registries look up by id and freeze what they hold, a component fits a
 * key only when the document allows what it stores, and a key's state is
 * told apart by absent, null, or any other value.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import * as bindings from './bindings.js';
import { componentFor, register } from './components.js';
import { misfit } from './fits.js';
import { canClear, optionsOf, stateOf, typesOf } from './schema.js';

/** A component that stores a string, registered for the tests. */
const STRING = register({ id: 'test-string', stores: { type: 'string' }, Component: () => null });

describe('components', () => {
  it('registers a component frozen, and finds it by id', () => {
    assert.equal(componentFor('test-string'), STRING);
    assert.ok(Object.isFrozen(STRING) && Object.isFrozen(STRING.stores));
  });

  it('finds nothing under an id nobody registered', () => {
    assert.equal(componentFor('test-nothing'), null);
  });

  it('refuses a component with no name, no stored type, or no React component', () => {
    assert.throws(() => register({ id: '', stores: { type: 'string' }, Component: () => null }), TypeError);
    assert.throws(() => register({ id: 'test-bad', stores: {}, Component: () => null }), TypeError);
    assert.throws(() => register({ id: 'test-bad', stores: { type: 'string' } }), TypeError);
  });
});

describe('bindings', () => {
  it('registers a binding frozen, and finds it by id', () => {
    const binding = bindings.register({
      id: 'test/one',
      title: 'One',
      store: { kind: 'file', source: 'config/x.yaml' },
      record: 'document',
      fields: [{ key: 'a', component: 'text' }],
    });
    assert.equal(bindings.registered('test/one'), binding);
    assert.ok(Object.isFrozen(binding.fields[0]) && Object.isFrozen(binding.store));
    assert.equal(binding.fields[0].readOnly, false);
  });

  it('refuses a field with no key or no component', () => {
    assert.throws(() => bindings.boundField({ key: 'a' }), TypeError);
    assert.throws(() => bindings.boundField({ component: 'text' }), TypeError);
  });
});

describe('fits', () => {
  it('fits a key whose types include what the component stores, or that names no type', () => {
    assert.equal(misfit(STRING, 'name', { type: 'string' }), null);
    assert.equal(misfit(STRING, 'note', { type: ['string', 'null'] }), null);
    assert.equal(misfit(STRING, 'any', {}), null);
  });

  it('fits a number component to an integer key, and a component that saves several types only where each is accepted', () => {
    const number = register({ id: 'test-number', stores: { type: 'number' }, Component: () => null });
    const either = register({ id: 'test-either', stores: { type: ['string', 'boolean'] }, Component: () => null });
    const until = { anyOf: [{ type: 'string', enum: ['dev'] }, { type: 'boolean', const: false }] };
    assert.equal(misfit(number, 'count', { type: 'integer' }), null);
    assert.equal(misfit(either, 'until', until), null);
    assert.equal(misfit(either, 'name', { type: 'string' }), 'test-either stores a string or a boolean, but name is a string.');
  });

  it('says why a key does not fit', () => {
    assert.equal(misfit(STRING, 'count', { type: 'integer' }), 'test-string stores a string, but count is an integer.');
  });
});

describe('schema', () => {
  it('tells untouched, cleared and set apart, with false, 0 and an empty string set', () => {
    const values = { cleared: null, off: false, zero: 0, empty: '' };
    assert.equal(stateOf(values, 'absent'), 'untouched');
    assert.equal(stateOf(values, 'cleared'), 'cleared');
    for (const key of ['off', 'zero', 'empty']) {
      assert.equal(stateOf(values, key), 'set');
    }
  });

  it('reads the types of each alternative, and allows any when one names none', () => {
    assert.deepEqual(typesOf({ anyOf: [{ type: 'string' }, { type: 'boolean' }] }), ['string', 'boolean']);
    assert.deepEqual(typesOf({ oneOf: [{ type: 'string' }, { type: 'array' }] }), ['string', 'array']);
    assert.deepEqual(typesOf({ anyOf: [{ type: 'string' }, {}] }), []);
  });

  it('lists the string options of an enum, or of the first alternative with one', () => {
    assert.deepEqual(optionsOf({ type: 'string', enum: ['dev', 'stable'] }), ['dev', 'stable']);
    assert.deepEqual(optionsOf({ anyOf: [{ type: 'string', enum: ['false', 'dev'] }, { type: 'boolean', const: false }] }), ['false', 'dev']);
    assert.deepEqual(optionsOf({ type: 'string' }), []);
  });

  it('lets a key be cleared only when it is not required and allows null', () => {
    assert.equal(canClear({ type: ['string', 'null'] }, false), true);
    assert.equal(canClear({ type: ['string', 'null'] }, true), false);
    assert.equal(canClear({ type: 'string' }, false), false);
  });
});
