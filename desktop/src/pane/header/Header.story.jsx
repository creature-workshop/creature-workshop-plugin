/**
 * @file The stories of the header: the session's directory holding no git
 * repository, one, and several, one with several worktrees, and a session
 * inside a linked worktree, each over a stand-in backend whose answers are built in, under the provider that holds the pane's shared state. The
 * stand-in keeps each session's selected repository and worktree, as the
 * real backend does. The header's tests are in header.ct.jsx beside this file.
 */

import { cn } from '@hermes/plugin-sdk';
import { useState } from 'react';
import { listenWith } from '../../events.js';
import { standIn } from '../../standIn/index.js';
import { sessionSubject } from '../../subject.js';
import { WorkshopProvider } from '../../workshop/WorkshopProvider.jsx';
import { Header } from './Header.jsx';

/** The header's width in every story, in pixels: the width Desktop docks the pane at. */
const DOCKED_WIDTH = 320;

/** The session's directory in every story. */
const CWD = '/home/someone/code';

/** A folder beside CWD that holds no repository. */
const NOTES = '/home/someone/notes';

/** The subject in every story but Following: a chat session in CWD. */
const SUBJECT = sessionSubject('stored-session-1', CWD);

/** A repository on main, two commits ahead, with one staged and three untracked paths, and no other worktree. */
const DEMO = {
  root: '/home/someone/code/demo',
  name: 'demo',
  worktrees: [{ root: '/home/someone/code/demo', name: 'demo', branch: 'main', head: '1111111aaaa', main: true, locked: false }],
};

/** The linked worktree of SITE on a fix branch, with one modified path. */
const SITE_HOTFIX = { root: '/home/someone/code/.worktrees/site-hotfix', name: 'site-hotfix', branch: 'fix/hotfix', head: '2222222bbbb', main: false, locked: false };

/** A clean repository on a feature branch, with a linked worktree on a fix branch and one on a detached HEAD. */
const SITE = {
  root: '/home/someone/code/site',
  name: 'site',
  worktrees: [
    { root: '/home/someone/code/site', name: 'site', branch: 'feat/x', head: '3333333cccc', main: true, locked: false },
    SITE_HOTFIX,
    { root: '/home/someone/code/.worktrees/site-old', name: 'site-old', branch: '', head: '4444444dddd', main: false, locked: true },
  ],
};

/** GET /repos/status for each checkout, by its root. */
const STATUSES = {
  [DEMO.root]: { root: DEMO.root, ok: true, branch: 'main', detached: false, upstream: true, ahead: 2, behind: 0, staged: 1, modified: 0, untracked: 3, conflicted: 0 },
  [SITE.root]: { root: SITE.root, ok: true, branch: 'feat/x', detached: false, upstream: false, ahead: 0, behind: 0, staged: 0, modified: 0, untracked: 0, conflicted: 0 },
  [SITE_HOTFIX.root]: { root: SITE_HOTFIX.root, ok: true, branch: 'fix/hotfix', detached: false, upstream: false, ahead: 0, behind: 0, staged: 0, modified: 1, untracked: 0, conflicted: 0 },
};

/** The backend when the directory holds no repository. */
const noneBackend = backendOver([]);

/** The backend when the directory is inside DEMO. */
const oneBackend = backendOver([DEMO], DEMO.root);

/** The backend when the directory is inside no repository and holds DEMO alone below it. */
const oneBelowBackend = backendOver([DEMO]);

/** The backend when the directory holds DEMO and SITE. */
const severalBackend = backendOver([DEMO, SITE]);

/** The backend when the directory is inside SITE's main worktree; SITE has three worktrees. */
const worktreesBackend = backendOver([SITE], SITE.root);

/** The backend when the directory is inside SITE_HOTFIX. */
const insideBackend = backendOver([SITE], SITE_HOTFIX.root);

/** The header for a directory that holds no git repository. */
export function Empty() {
  return docked(noneBackend);
}

/** The header for a directory inside a git repository. */
export function Single() {
  return docked(oneBackend);
}

/** The header for a directory that is inside no git repository and holds one below it. */
export function OneBelow() {
  return docked(oneBelowBackend);
}

/** The header for a directory that holds two git repositories. */
export function Several() {
  return docked(severalBackend);
}

/** The header for a directory inside the main worktree of a repository with three worktrees. */
export function Worktrees() {
  return docked(worktreesBackend);
}

/** The header for a session inside a linked worktree. */
export function InsideWorktree() {
  return docked(insideBackend);
}

/**
 * The header for whichever of two sessions is focused: the first works in
 * CWD, which holds two repositories; the second works in NOTES, which holds none.
 *
 * @param props The story's props.
 * @param props.second Whether the second session is the one focused.
 */
export function Following({ second = false }) {
  return docked(severalBackend, second ? sessionSubject('stored-session-2', NOTES) : SUBJECT);
}

/**
 * The header for a directory inside SITE's main worktree, with a button
 * that picks SITE's hotfix worktree the way another window's pane does: through the
 * backend, which then says that a selection changed.
 */
export function PickedElsewhere() {
  const [other] = useState(withAnotherWindow);
  return (
    <div className={cn('workshop-story')} style={{ width: DOCKED_WIDTH }}>
      <WorkshopProvider rest={other.rest} subject={SUBJECT}>
        <Header />
      </WorkshopProvider>
      <button type="button" onClick={other.pickHotfix}>Pick site-hotfix in another window</button>
    </div>
  );
}

/**
 * The header in a box as wide as the docked pane, under a provider over a backend call.
 *
 * @param rest The backend call the header makes.
 * @param subject What the pane is about.
 */
function docked(rest, subject = SUBJECT) {
  return (
    <div className={cn('workshop-story')} style={{ width: DOCKED_WIDTH }}>
      <WorkshopProvider rest={rest} subject={subject}>
        <Header />
      </WorkshopProvider>
    </div>
  );
}

/**
 * A backend for a directory inside SITE's main worktree, with another
 * window beside it: `rest` is the backend call, and `pickHotfix` picks SITE_HOTFIX
 * for SUBJECT's session through the backend and then calls every listener
 * the pane registered for an event, as the backend's event does.
 */
function withAnotherWindow() {
  const rest = backendOver([SITE], SITE.root);
  const listeners = new Set();
  listenWith((type, listener) => {
    listeners.add(listener);
    return () => listeners.delete(listener);
  });
  const body = { session: SUBJECT.id, path: CWD, root: SITE_HOTFIX.root };
  const pickHotfix = () => rest('/selection/worktree', { method: 'POST', body }).then(() => listeners.forEach((listener) => listener()));
  return { rest, pickHotfix };
}

/**
 * A backend call that answers GET /repos with repos for CWD and none for
 * any other folder, and GET /repos/status from STATUSES, with what every
 * stand-in backend does besides.
 *
 * @param repos The repositories GET /repos lists for CWD.
 * @param [checkout] The worktree CWD is inside, when it is inside one.
 */
function backendOver(repos, checkout = '') {
  return standIn(async (path) => (path.startsWith('/repos/status') ? STATUSES[rootOf(path)] : answerFor(path, repos, checkout)));
}

/**
 * The answer to GET /about or GET /repos.
 *
 * @param path The path asked for.
 * @param repos The repositories GET /repos lists for CWD.
 * @param checkout The worktree CWD is inside, or "".
 */
function answerFor(path, repos, checkout) {
  return path.startsWith('/about') ? { version: '0.1.0-dev.9', branch: 'main' } : reposIn(queryOf(path).get('path'), repos, checkout);
}

/**
 * The answer to GET /repos for a folder: repos for CWD, none for any other.
 *
 * @param folder The folder asked about.
 * @param repos The repositories CWD holds.
 * @param checkout The worktree CWD is inside, or "".
 */
function reposIn(folder, repos, checkout) {
  const here = folder === CWD;
  return { start: folder, inside: here && Boolean(checkout), checkout: here ? checkout : '', repos: here ? repos : [], refresh_seconds: 20 };
}

/**
 * The root a GET /repos/status path asks about.
 *
 * @param path The path, with its query.
 */
function rootOf(path) {
  return queryOf(path).get('root');
}

/**
 * The query of a path, as search parameters.
 *
 * @param path The path, with its query.
 */
function queryOf(path) {
  return new URLSearchParams(path.split('?')[1]);
}
