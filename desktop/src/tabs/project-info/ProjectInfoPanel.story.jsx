/**
 * @file The stories of the Project Info tab: an adopted repository over a
 * backend that keeps the manifest fields it is sent, as the real one writes
 * them to the manifest, and one whose saves always fail. The tests are in
 * project-info.ct.jsx beside this file.
 */

import { useState } from 'react';
import { WorkshopTabs } from '../../pane/tabs/WorkshopTabs.jsx';
import { sessionSubject } from '../../subject.js';
import { WorkshopProvider } from '../../workshop/WorkshopProvider.jsx';

/** The repository in every story, the root of a shellops project. */
const ROOT = '/home/someone/notes';

/** GET /repos for a directory that is the repository itself. */
const REPOS = { start: ROOT, inside: true, repos: [{ root: ROOT, name: 'notes' }], refresh_seconds: 20 };

/** GET /repos/status for the repository. */
const STATUS = { root: ROOT, ok: true, branch: 'main', detached: false, upstream: false, ahead: 0, behind: 0, staged: 0, modified: 0, untracked: 0, conflicted: 0 };

/** The project as GET /project first answers it; it sets no command name. */
const PROJECT = Object.freeze({
  found: true,
  root: ROOT,
  name: 'Notes',
  summary: '',
  declaration: {},
  manifest: { name: 'Notes', description: 'Notes, kept in git.', command_name: '', org: 'someone', repo: 'notes' },
  release: { latest: '0.1.0', stable: '0.1.0' },
  declared: [],
  refresh_seconds: 20,
});

/** The fields of GET /project's manifest by manifest key. */
const MANIFEST_KEYS = { name: 'name', description: 'description', 'command-name': 'command_name', org: 'org', repo: 'repo' };

/** The tabs over a backend that keeps every change it is sent. */
export function Editable() {
  const [rest] = useState(() => keepingBackend());
  return framed(rest);
}

/** The tabs over a backend that refuses every change. */
export function Refusing() {
  const [rest] = useState(() => refusingBackend());
  return framed(rest);
}

/**
 * The tabs under a provider over `rest`.
 *
 * @param rest The backend call.
 */
function framed(rest) {
  return (
    <WorkshopProvider rest={rest} subject={sessionSubject('stored-session-1', ROOT)}>
      <WorkshopTabs />
    </WorkshopProvider>
  );
}

/** A backend call that answers the reads and applies each POST /project/manifest to its own copy of the project. */
function keepingBackend() {
  let project = PROJECT;
  return async (path, options) => {
    if (options?.method === 'POST') {
      project = changed(project, options.body);
      return project;
    }
    return read(path, project);
  };
}

/** A backend call that answers the reads and rejects every POST. */
function refusingBackend() {
  return async (path, options) => {
    if (options?.method === 'POST') {
      throw new Error('HTTP 400');
    }
    return read(path, PROJECT);
  };
}

/**
 * The answer to a read.
 *
 * @param path The path asked for.
 * @param project The answer to GET /project.
 */
function read(path, project) {
  const answers = [['/about', { version: '0.1.0', branch: 'main' }], ['/repos/status', STATUS], ['/repos', REPOS], ['/project', project]];
  return answers.find(([prefix]) => path.startsWith(prefix))[1];
}

/**
 * The project with one change applied, the way the backend reads it back.
 *
 * @param project The project before.
 * @param change The body of POST /project/manifest: `{root, key, value}`.
 */
function changed(project, change) {
  return { ...project, manifest: { ...project.manifest, [MANIFEST_KEYS[change.key]]: change.value } };
}
