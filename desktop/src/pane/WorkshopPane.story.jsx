/**
 * @file The stories of the Workshop pane: each named export is the pane in
 * one scenario, with the backend's answers it runs against built in, so a
 * test mounts a story and passes nothing but plain data. The session's
 * directory holds no repository in these; the header's own scenarios are in
 * header/Header.story.jsx. The pane's tests are in pane.ct.jsx beside this file.
 */

import { cn } from '@hermes/plugin-sdk';
import { WorkshopProvider } from '../workshop/WorkshopProvider.jsx';
import { WorkshopPane } from './WorkshopPane.jsx';

/** The pane's height in every story, in pixels. */
const HEIGHT = 200;

/** The pane's width when a test gives none, in pixels: the width Desktop docks it at. */
const DOCKED_WIDTH = 320;

/** The session's directory in every story. */
const CWD = '/home/someone/notes';

/** GET /repos for a directory that holds no repository. */
const NO_REPOS = { start: CWD, inside: false, repos: [], refresh_seconds: 20 };

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
      <WorkshopProvider rest={rest} cwd={CWD}>
        <WorkshopPane />
      </WorkshopProvider>
    </div>
  );
}
