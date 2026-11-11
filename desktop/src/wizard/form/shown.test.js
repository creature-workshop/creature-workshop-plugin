/**
 * @file Which steps a form wizard shows, and what it finishes with.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { FINISH } from '../branch.js';
import { confirm, dialog, prompt, withDefaultIndex } from '../steps.js';
import { closingSplit, finalAnswers, shownSteps, startingValues } from './shown.js';

/** A wizard that asks for a name, then whether to go on, then a note only on yes. */
const STEPS = [dialog('Hello.'), prompt('Name', 'name', 'notes'), withDefaultIndex(confirm('Add a note?', 'more'), 1), prompt('Note', 'note', '')];

describe('startingValues', () => {
  it('starts each prompt on its fallback and each select on its default', () => {
    assert.deepEqual(startingValues(STEPS), { name: 'notes', more: 'no', note: '' });
  });
});

describe('shownSteps', () => {
  it('follows the branches with the answers as they stand', () => {
    assert.deepEqual(shownSteps(STEPS, { name: 'notes', more: 'no' }), [0, 1, 2]);
    assert.deepEqual(shownSteps(STEPS, { name: 'notes', more: 'yes' }), [0, 1, 2, 3]);
  });

  it('shows nothing for no steps, and stops when a step comes round again', () => {
    assert.deepEqual(shownSteps([], {}), []);
    const loop = [{ kind: 'dialog', text: 'again', id: 'a', branch: () => ({ kind: 'jump', id: 'a' }) }];
    assert.deepEqual(shownSteps(loop, {}), [0]);
  });
});

describe('closingSplit', () => {
  it('puts the dialogs after the last question with the buttons, and leaves an opening dialog in the body', () => {
    const steps = [dialog('Hello.'), prompt('Name', 'name', ''), dialog('By the way.'), dialog('Last word.')];
    assert.deepEqual(closingSplit(steps, [0, 1, 2, 3]), { body: [0, 1], closing: [2, 3] });
  });

  it('has no closing notes when a question comes last, and only those when nothing is asked', () => {
    assert.deepEqual(closingSplit(STEPS, [0, 1, 2]), { body: [0, 1, 2], closing: [] });
    assert.deepEqual(closingSplit([dialog('Only this.')], [0]), { body: [], closing: [0] });
  });
});

describe('finalAnswers', () => {
  it('keeps the answers of the steps shown, and drops the rest', () => {
    assert.deepEqual(finalAnswers(STEPS, { name: 'Notes', more: 'no', note: 'left over' }), { name: 'Notes', more: 'no' });
  });

  it('ends at FINISH', () => {
    const steps = [confirm('Go on?', 'go', FINISH, FINISH), prompt('Never', 'never', '')];
    assert.deepEqual(finalAnswers(steps, { go: 'yes', never: 'x' }), { go: 'yes' });
  });
});
