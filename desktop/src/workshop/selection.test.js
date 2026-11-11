/**
 * @file Reading GET /repos's repositories: finding one by its root, and
 * whether it has worktrees to choose between.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { hasWorktrees, repositoryAt } from './selection.js';

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

describe('finding a repository', () => {
  it('finds one by its root', () => {
    assert.equal(repositoryAt([BARE, DEMO], '/code/demo'), DEMO);
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
