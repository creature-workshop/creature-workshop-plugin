/**
 * @file The stand-in's selection: which repository and which checkout it
 * answers for a session, the same rule as workshop/selection/; that a pick
 * on one session leaves another alone; and that GET /repos carries the
 * session's selection beside the story's own answer.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { standIn } from './index.js';
import { checkoutOf, repositoryHolding, repositoryOf } from './selection.js';

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

/** A story's own backend call, whose GET /repos lists DEMO and BARE for every folder. */
const listing = async (path) => (path.startsWith('/repos') ? { start: '/code', inside: false, checkout: '', repos: [DEMO, BARE], refresh_seconds: 20 } : { asked: path });

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

  it('reads the worktree the folder is inside when none is picked', () => {
    assert.equal(checkoutOf(DEMO, {}, '/code/fix'), '/code/fix');
    assert.equal(checkoutOf(DEMO, { '/code/demo': '/code/demo' }, '/code/fix'), '/code/demo');
  });
});

describe('repositoryOf', () => {
  it('is the picked repository while it is listed', () => {
    assert.equal(repositoryOf([BARE, DEMO], '/code/demo'), '/code/demo');
  });

  it('is the repository the folder is inside without a pick', () => {
    assert.equal(repositoryOf([DEMO], '', '/code/demo'), '/code/demo');
    assert.equal(repositoryOf([DEMO], '', '/code/fix'), '/code/demo');
    assert.equal(repositoryOf([BARE], '', '/code/notes'), '/code/notes');
  });

  it('is none without a pick in a folder that is inside no repository, even when it holds only one', () => {
    assert.equal(repositoryOf([DEMO], ''), '');
    assert.equal(repositoryOf([BARE, DEMO], ''), '');
    assert.equal(repositoryOf([BARE, DEMO], '/code/gone'), '');
  });
});

describe('repositoryHolding', () => {
  it('finds the repository holding a worktree', () => {
    assert.equal(repositoryHolding([BARE, DEMO], '/code/fix'), DEMO);
  });
});

describe('a stand-in backend', () => {
  it('answers nothing selected among several repositories until one is picked', async () => {
    const rest = standIn(listing);
    const before = await rest('/selection?session=s1&path=%2Fcode');
    assert.deepEqual([before.repository, before.selected], ['', '']);
    const after = await rest('/selection', { method: 'POST', body: { session: 's1', path: '/code', root: '/code/demo' } });
    assert.deepEqual([after.repository, after.selected], ['/code/demo', '/code/demo']);
  });

  it('picks a worktree together with its repository, and keeps it for that session alone', async () => {
    const rest = standIn(listing);
    await rest('/selection/worktree', { method: 'POST', body: { session: 's1', path: '/code', root: '/code/fix' } });
    const first = await rest('/selection?session=s1&path=%2Fcode');
    const second = await rest('/selection?session=s2&path=%2Fcode');
    assert.deepEqual([first.repository, first.selected], ['/code/demo', '/code/fix']);
    assert.deepEqual([second.repository, second.selected], ['', '']);
  });

  it('adds the session\'s selection to the story\'s own answer of GET /repos', async () => {
    const rest = standIn(listing);
    await rest('/selection/worktree', { method: 'POST', body: { session: 's1', path: '/code', root: '/code/fix' } });
    const repos = await rest('/repos?path=%2Fcode&session=s1');
    assert.deepEqual([repos.repos.length, repos.repository, repos.selected], [2, '/code/demo', '/code/fix']);
  });

  it('keeps its picks apart from another stand-in\'s', async () => {
    await standIn(listing)('/selection', { method: 'POST', body: { session: 's1', path: '/code', root: '/code/demo' } });
    const other = await standIn(listing)('/selection?session=s1&path=%2Fcode');
    assert.equal(other.repository, '');
  });

  it('passes every other path to the story\'s own backend call', async () => {
    assert.deepEqual(await standIn(listing)('/about'), { asked: '/about' });
  });
});
