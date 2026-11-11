/**
 * @file The adoption wizard's steps and what its answers turn into.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { startingValues } from '../../../wizard/form/shown.js';
import { adoptionOf, adoptionSteps, APPROVAL_NOTICE } from './adoptionSteps.js';

/** What GET /project/adoption suggests for a checkout of notes on main. */
const SUGGESTED = { name: 'notes', repo: 'notes', branch: 'main' };

/** What the agent guesses for it. */
const GUESSED = { found: true, description: 'Notes kept in git.', command: 'notes' };

/** No guess. */
const NO_GUESS = { found: false, description: '', command: '' };

describe('adoptionSteps', () => {
  it('starts each field on what was found, the organization empty, and the commit off', () => {
    assert.deepEqual(startingValues(adoptionSteps(SUGGESTED, GUESSED)), {
      name: 'notes', description: 'Notes kept in git.', 'command-name': 'notes', org: '', repo: 'notes', commit: 'no',
    });
  });

  it('marks the fields the agent filled in, and only those', () => {
    const hinted = adoptionSteps(SUGGESTED, GUESSED).filter((step) => step.hint).map((step) => step.key);
    assert.deepEqual(hinted, ['description', 'command-name']);
  });

  it('starts the guessed fields empty and unmarked without a guess', () => {
    const steps = adoptionSteps(SUGGESTED, NO_GUESS);
    assert.equal(startingValues(steps).description, '');
    assert.equal(steps.some((step) => step.hint), false);
  });

  it('names the branch in the commit question, and leaves it out when detached', () => {
    assert.equal(adoptionSteps(SUGGESTED, NO_GUESS).at(-2).text, 'Commit the workshop files to main');
    assert.equal(adoptionSteps({ ...SUGGESTED, branch: '' }, NO_GUESS).at(-2).text, 'Commit the workshop files');
  });
});

describe('adoptionSteps help', () => {
  it('gives every step that takes an answer what it is for', () => {
    assert.equal(adoptionSteps(SUGGESTED, NO_GUESS).filter((step) => step.key).every((step) => step.info), true);
  });

  it('takes a description of several lines, and every other field on one', () => {
    const multiline = adoptionSteps(SUGGESTED, NO_GUESS).filter((step) => step.multiline).map((step) => step.key);
    assert.deepEqual(multiline, ['description']);
  });
});

describe('the approval notice', () => {
  it('comes last, takes no answer, and says what completing setup agrees to', () => {
    const last = adoptionSteps(SUGGESTED, NO_GUESS).at(-1);
    assert.equal(last.kind, 'dialog');
    assert.equal(last.text, APPROVAL_NOTICE);
    assert.equal(APPROVAL_NOTICE, 'By completing setup, you agree to let Creature Workshop run commands to manage this repository.');
  });
});

describe('adoptionOf', () => {
  it('splits the answers into the manifest and the commit choice', () => {
    assert.deepEqual(
      adoptionOf({ name: 'Notes', org: 'someone', commit: 'yes' }),
      { manifest: { name: 'Notes', org: 'someone' }, commit: true },
    );
  });
});
