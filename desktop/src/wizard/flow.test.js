/**
 * @file The wizard contract's steps and flow without a screen: the step
 * constructors build blizz's configuration as plain data, answers collect
 * under their keys, and the next step follows the branches, including a
 * review that jumps back to an earlier step and a confirm that finishes on no.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { FINISH, NEXT, jumpTo } from './branch.js';
import { nextIndex, record, validateTargets } from './flow.js';
import { confirm, dialog, onSubmit, prompt, select, withDefaultIndex, withId } from './steps.js';

/** A setup in the shape the adoption wizard takes: identity, a review that can send the user back, and a confirm. */
const SETUP = [
  dialog('Let us set up shop.'),
  withId(prompt('What is the project called?', 'name', 'notes'), 'identity'),
  onSubmit(select('Does this look right?', 'review', [['Looks good', 'ok'], ['Change the name', 'identity']]), (output) => (output.review === 'ok' ? NEXT : jumpTo(output.review))),
  confirm('Adopt it now?', 'adopt'),
  dialog('All set.'),
];

describe('steps', () => {
  it('a select takes its options as label and value pairs and starts on the first', () => {
    const step = select('Pick one', 'pick', [['First', 'a'], ['Second', 'b']]);
    assert.deepEqual(step.options, [{ label: 'First', value: 'a' }, { label: 'Second', value: 'b' }]);
    assert.equal(step.defaultIndex, 0);
  });

  it('a confirm is a yes-or-no select', () => {
    assert.deepEqual(confirm('Sure?', 'sure').options.map((option) => option.value), ['yes', 'no']);
  });

  it('the with helpers return a copy and leave the step as it was', () => {
    const step = select('Pick one', 'pick', [['First', 'a'], ['Second', 'b']]);
    assert.equal(withDefaultIndex(step, 1).defaultIndex, 1);
    assert.equal(withId(step, 'pick-step').id, 'pick-step');
    assert.equal(step.defaultIndex, 0);
    assert.equal(step.id, undefined);
  });

  it('a default index on anything but a select changes nothing', () => {
    const step = prompt('Name?', 'name', '');
    assert.equal(withDefaultIndex(step, 3), step);
  });
});

describe('flow', () => {
  it('answers collect under their keys, and a dialog adds none', () => {
    const answers = record(record({}, SETUP[0], ''), SETUP[1], 'workshop');
    assert.deepEqual(answers, { name: 'workshop' });
  });

  it('a step with no branch goes on to the next', () => {
    assert.equal(nextIndex(0, SETUP, ''), 1);
  });

  it('a review that picks a section jumps back to that step', () => {
    assert.equal(nextIndex(2, SETUP, 'identity'), 1);
    assert.equal(nextIndex(2, SETUP, 'ok'), 3);
  });

  it('a confirm goes on with yes and finishes with no', () => {
    assert.equal(nextIndex(3, SETUP, 'yes'), 4);
    assert.equal(nextIndex(3, SETUP, 'no'), -1);
  });

  it('the wizard finishes after the last step, or where a branch says FINISH', () => {
    assert.equal(nextIndex(4, SETUP, ''), -1);
    assert.equal(nextIndex(0, [onSubmit(dialog('Bye.'), () => FINISH), dialog('Never shown.')], ''), -1);
  });
});

describe('validateTargets', () => {
  it('passes a wizard whose jumps all land on a step', () => {
    assert.doesNotThrow(() => validateTargets([withId(dialog('Start.'), 'start'), onSubmit(dialog('Again?'), () => jumpTo('start'))]));
  });

  it('names the id when a jump lands on no step', () => {
    assert.throws(() => validateTargets([onSubmit(dialog('Go.'), () => jumpTo('nowhere'))]), /'nowhere'/);
  });

  it('names the id two steps share', () => {
    assert.throws(() => validateTargets([withId(dialog('One.'), 'twin'), withId(dialog('Two.'), 'twin')]), /'twin'/);
  });
});
