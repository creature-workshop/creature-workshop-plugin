/**
 * @file Which checkout the pane reads: the picked worktree while it is
 * listed, else the main one, else the first, else the repository's root.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { checkoutOf, hasWorktrees, repositoryAt, repositoryHolding } from './selection.js';

/** A repository with its main worktree and one linked worktree. */
const DEMO = {
  root: '/code/demo',
  name: 'demo',
  worktrees: [
    { root: '/code/demo', name: 'demo', branch: 'main', main: true },
    { root: '/code/fix', name: 'fix', branch: 'fix/x', main: false },
  ],
};

/** A repository whose answer lists no worktrees. */
const BARE = { root: '/code/notes', name: 'notes', worktrees: [] };

describe('checkoutOf', () => {
  it('reads the main worktree when none is picked', () => {
    assert.equal(checkoutOf(DEMO, {}), '/code/demo');
  });

  it('reads the picked worktree', () => {
    assert.equal(checkoutOf(DEMO, { '/code/demo': '/code/fix' }), '/code/fix');
  });

  it('falls back to the main worktree when the picked one is no longer listed', () => {
    assert.equal(checkoutOf(DEMO, { '/code/demo': '/code/gone' }), '/code/demo');
  });

  it('reads the repository itself when it lists no worktrees', () => {
    assert.equal(checkoutOf(BARE, {}), '/code/notes');
  });

  it('reads nothing without a repository', () => {
    assert.equal(checkoutOf(undefined, {}), '');
  });
});

describe('finding a repository', () => {
  it('finds one by its root', () => {
    assert.equal(repositoryAt([BARE, DEMO], '/code/demo'), DEMO);
  });

  it('finds the one holding a worktree', () => {
    assert.equal(repositoryHolding([BARE, DEMO], '/code/fix'), DEMO);
  });
});

describe('hasWorktrees', () => {
  it('is true for a repository with linked worktrees', () => {
    assert.equal(hasWorktrees([DEMO], '/code/demo'), true);
  });

  it('is false for one with only its main worktree, or none listed, or no repository', () => {
    assert.equal(hasWorktrees([BARE], '/code/notes'), false);
    assert.equal(hasWorktrees([DEMO], ''), false);
  });
});
