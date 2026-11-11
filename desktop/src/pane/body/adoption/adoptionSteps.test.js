/**
 * @file The adoption wizard's steps and what its answers turn into.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { startingValues } from '../../../wizard/form/shown.js';
import { adoptionOf, adoptionSteps } from './adoptionSteps.js';

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
    assert.equal(adoptionSteps(SUGGESTED, NO_GUESS).at(-1).text, 'Commit the workshop files to main');
    assert.equal(adoptionSteps({ ...SUGGESTED, branch: '' }, NO_GUESS).at(-1).text, 'Commit the workshop files');
  });
});

describe('adoptionSteps help', () => {
  it('gives every step what it is for', () => {
    assert.equal(adoptionSteps(SUGGESTED, NO_GUESS).every((step) => step.info), true);
  });
});

describe('adoptionOf', () => {
  it('splits the answers into the manifest and the commit choice', () => {
    assert.deepEqual(adoptionOf({ name: 'Notes', org: 'someone', commit: 'yes' }), { manifest: { name: 'Notes', org: 'someone' }, commit: true });
  });
});
