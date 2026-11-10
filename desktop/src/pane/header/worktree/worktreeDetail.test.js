/**
 * @file What the worktree selector says after a worktree's folder name: its
 * branch, nothing when the folder is named for it, or its short commit on a
 * detached HEAD; and what its tooltip says.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { worktreeDetail, worktreeTip } from './worktreeDetail.js';

describe('worktreeDetail', () => {
  it('is the branch', () => {
    assert.equal(worktreeDetail({ name: 'rig-timers', branch: 'docs/timer-enable-line' }), 'docs/timer-enable-line');
  });

  it('is empty when the folder is named for the branch', () => {
    assert.equal(worktreeDetail({ name: 'main', branch: 'main' }), '');
    assert.equal(worktreeDetail({ name: 'hotfix', branch: 'fix/hotfix' }), '');
  });

  it('is the short commit on a detached HEAD', () => {
    assert.equal(worktreeDetail({ name: 'old', branch: '', head: '1a2b3c4d5e6f' }), 'detached at 1a2b3c4');
  });
});

describe('worktreeTip', () => {
  it('names the path and the branch', () => {
    assert.equal(worktreeTip({ root: '/code/rig-timers', branch: 'docs/x' }), '/code/rig-timers, on docs/x');
  });

  it('names the path and the commit on a detached HEAD', () => {
    assert.equal(worktreeTip({ root: '/code/old', branch: '', head: '1a2b3c4d5e6f' }), '/code/old, detached at 1a2b3c4');
  });
});
