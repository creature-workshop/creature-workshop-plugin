/**
 * @file When the pane asks for the user's approval of the selected project.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { unapproved } from './unapproved.js';

/**
 * GET /project's answer for a project at /p, as remote data.
 *
 * @param {boolean} approved Whether the user has approved it.
 */
function answered(approved) {
  return { state: 'success', data: { found: true, root: '/p', approved } };
}

describe('unapproved', () => {
  it('is true for the selected project when it is not approved', () => {
    assert.equal(unapproved(answered(false), '/p'), true);
  });

  it('is false when the project is approved, when none is selected, and while the project loads', () => {
    assert.equal(unapproved(answered(true), '/p'), false);
    assert.equal(unapproved(answered(false), ''), false);
    assert.equal(unapproved({ state: 'loading' }, '/p'), false);
  });

  it('is false outside a project, and for a project above the selected folder', () => {
    assert.equal(unapproved({ state: 'success', data: { found: false } }, '/p'), false);
    assert.equal(unapproved(answered(false), '/p/below'), false);
  });
});
