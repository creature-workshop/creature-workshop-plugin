/**
 * @file The stories of the Workshop pane: each named export is the pane in
 * one scenario, with the backend's answers it runs against built in, so a
 * test mounts a story and passes nothing but plain data. In OnMain and
 * OutsideGit the session's directory holds no repository; in Adopted and
 * NotAdopted it is one, with and without shellops. The header's own
 * scenarios are in header/Header.story.jsx. The pane's tests are in
 * pane.ct.jsx beside this file.
 */

import { cn } from '@hermes/plugin-sdk';
import { sessionSubject } from '../subject.js';
import { WorkshopProvider } from '../workshop/WorkshopProvider.jsx';
import { WorkshopPane } from './WorkshopPane.jsx';

/** The pane's height in every story, in pixels. */
const HEIGHT = 200;

/** The pane's width when a test gives none, in pixels: the width Desktop docks it at. */
const DOCKED_WIDTH = 320;

/** The session's directory in every story. */
const CWD = '/home/someone/notes';

/** The subject in every story: a chat session in CWD. */
const SUBJECT = sessionSubject('stored-session-1', CWD);

/** GET /repos for a directory that holds no repository. */
const NO_REPOS = { start: CWD, inside: false, repos: [], refresh_seconds: 20 };

/** GET /repos for a directory that is a repository itself. */
const ONE_REPO = { start: CWD, inside: true, repos: [{ root: CWD, name: 'notes' }], refresh_seconds: 20 };

/** GET /repos/status for that repository: clean, on main. */
const CLEAN = { root: CWD, ok: true, branch: 'main', detached: false, upstream: false, ahead: 0, behind: 0, staged: 0, modified: 0, untracked: 0, conflicted: 0 };

/** GET /project outside any shellops project. */
const NO_PROJECT = { found: false, start: CWD, refresh_seconds: 20 };

/** What GET /about answers in the stories of a repository. */
const ABOUT = { version: '0.1.0-dev.9', branch: 'main' };

/** The backend for a plugin loaded from a checkout on main. */
const onMainBackend = backendWith({ version: '0.1.0-dev.9', branch: 'main' });

/** The backend for a plugin loaded from outside any git checkout. */
const outsideGitBackend = backendWith({ version: '0.1.0-dev.9', branch: '' });

/**
 * The pane loaded from a checkout on main.
 *
 * @param props The story's props.
 * @param props.width The pane's width in pixels.
 */
export function OnMain({ width = DOCKED_WIDTH }) {
  return framed(onMainBackend, width);
}

/**
 * The pane loaded from outside any git checkout.
 *
 * @param props The story's props.
 * @param props.width The pane's width in pixels.
 */
export function OutsideGit({ width = DOCKED_WIDTH }) {
  return framed(outsideGitBackend, width);
}

/**
 * The pane over a repository that is a shellops project's root, with a release record.
 *
 * @param props The story's props.
 * @param props.latest The latest release the lock records, or empty.
 * @param props.stable The latest stable release the lock records, or empty.
 */
export function Adopted({ latest = '0.1.0-dev.12', stable = '0.0.0' }) {
  return framed(repositoryBackend(projectAt(CWD, { latest, stable })), DOCKED_WIDTH);
}

/** The pane over a repository with no shellops. */
export function NotAdopted() {
  return framed(repositoryBackend(NO_PROJECT), DOCKED_WIDTH);
}

/**
 * GET /project for the shellops project rooted at root, without the toolchain.
 *
 * @param root The project's root.
 * @param release The release record of its lock.
 */
function projectAt(root, release) {
  const manifest = { name: 'Notes', description: 'Notes, kept in git.', command_name: 'notes', org: 'someone', repo: 'notes' };
  return { found: true, root, name: 'Notes', summary: '', declaration: {}, manifest, release, declared: [], refresh_seconds: 20 };
}

/**
 * A backend call over a directory that is one repository, answering GET /project with project.
 *
 * @param project The answer to GET /project.
 */
function repositoryBackend(project) {
  const answers = [['/about', ABOUT], ['/repos/status', CLEAN], ['/repos', ONE_REPO], ['/project', project]];
  return async (path) => answers.find(([prefix]) => path.startsWith(prefix))[1];
}

/**
 * A backend call that answers GET /about with about and GET /repos with no repositories.
 *
 * @param about The answer to GET /about.
 */
function backendWith(about) {
  return async (path) => (path.startsWith('/about') ? about : NO_REPOS);
}

/**
 * The pane in a box of the given width, the way Desktop docks it, under a provider over a backend call.
 *
 * @param rest The backend call the pane makes.
 * @param width The box's width in pixels.
 */
function framed(rest, width) {
  return (
    <div className={cn('workshop-story')} style={{ width, height: HEIGHT, display: 'flex', flexDirection: 'column' }}>
      <WorkshopProvider rest={rest} subject={SUBJECT}>
        <WorkshopPane />
      </WorkshopProvider>
    </div>
  );
}
