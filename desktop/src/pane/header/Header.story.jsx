/**
 * @file The stories of the header: the session's directory holding no git
 * repository, one, and several, each over a backend whose answers are built
 * in, under the provider that holds the pane's shared state. The header's
 * tests are in header.ct.jsx beside this file.
 */

import { cn } from '@hermes/plugin-sdk';
import { WorkshopProvider } from '../../workshop/WorkshopProvider.jsx';
import { Header } from './Header.jsx';

/** The header's width in every story, in pixels: the width Desktop docks the pane at. */
const DOCKED_WIDTH = 320;

/** The session's directory in every story. */
const CWD = '/home/someone/code';

/** A repository on main, two commits ahead, with one staged and three untracked paths. */
const DEMO = { root: '/home/someone/code/demo', name: 'demo' };

/** A clean repository on a feature branch. */
const SITE = { root: '/home/someone/code/site', name: 'site' };

/** GET /repos/status for each repository, by its root. */
const STATUSES = {
  [DEMO.root]: { root: DEMO.root, ok: true, branch: 'main', detached: false, upstream: true, ahead: 2, behind: 0, staged: 1, modified: 0, untracked: 3, conflicted: 0 },
  [SITE.root]: { root: SITE.root, ok: true, branch: 'feat/x', detached: false, upstream: false, ahead: 0, behind: 0, staged: 0, modified: 0, untracked: 0, conflicted: 0 },
};

/** The backend when the directory holds no repository. */
const noneBackend = backendOver([]);

/** The backend when the directory holds DEMO alone. */
const oneBackend = backendOver([DEMO]);

/** The backend when the directory holds DEMO and SITE. */
const severalBackend = backendOver([DEMO, SITE]);

/** The header for a directory that holds no git repository. */
export function Empty() {
  return docked(noneBackend);
}

/** The header for a directory that holds one git repository. */
export function Single() {
  return docked(oneBackend);
}

/** The header for a directory that holds two git repositories. */
export function Several() {
  return docked(severalBackend);
}

/**
 * The header in a box as wide as the docked pane, under a provider over a backend call.
 *
 * @param rest The backend call the header makes.
 */
function docked(rest) {
  return (
    <div className={cn('workshop-story')} style={{ width: DOCKED_WIDTH }}>
      <WorkshopProvider rest={rest} cwd={CWD}>
        <Header />
      </WorkshopProvider>
    </div>
  );
}

/**
 * A backend call that answers GET /repos with repos, and GET /repos/status from STATUSES.
 *
 * @param repos The repositories GET /repos lists.
 */
function backendOver(repos) {
  return async (path) => (path.startsWith('/repos/status') ? STATUSES[rootOf(path)] : answerFor(path, repos));
}

/**
 * The answer to GET /about or GET /repos.
 *
 * @param path The path asked for.
 * @param repos The repositories GET /repos lists.
 */
function answerFor(path, repos) {
  return path.startsWith('/about') ? { version: '0.1.0-dev.9', branch: 'main' } : { start: CWD, inside: false, repos, refresh_seconds: 20 };
}

/**
 * The root a GET /repos/status path asks about.
 *
 * @param path The path, with its query.
 */
function rootOf(path) {
  return new URLSearchParams(path.split('?')[1]).get('root');
}
