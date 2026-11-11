/**
 * @file The stories of the Project Info tab: an adopted repository over a
 * backend whose file store keeps each change it is sent, as the real one
 * writes it to the manifest; one whose store refuses every change with a
 * reason; one where the manifest changed outside the pane before the
 * first save; and one whose project has no manifest until the form writes
 * it. The tests are in
 * project-info.ct.jsx beside this file.
 */

import { useState } from 'react';
import { requestWith } from '../../modules/approval/approval.js';
import { FormWizard } from '../../wizard/form/FormWizard.jsx';
import { register } from '../../wizard/implementation.js';
import { WorkshopTabs } from '../../pane/tabs/WorkshopTabs.jsx';
import { standIn } from '../../standIn/index.js';
import { sessionSubject } from '../../subject.js';
import { WorkshopProvider } from '../../workshop/WorkshopProvider.jsx';

/** The repository in every story, the root of a shellops project. */
const ROOT = '/home/someone/notes';

/** GET /repos for a directory that is the repository itself. */
const REPOS = { start: ROOT, inside: true, checkout: ROOT, repos: [{ root: ROOT, name: 'notes' }], refresh_seconds: 20 };

/** GET /repos/status for the repository. */
const STATUS = { root: ROOT, ok: true, branch: 'main', detached: false, upstream: false, ahead: 0, behind: 0, staged: 0, modified: 0, untracked: 0, conflicted: 0 };

/** The project as GET /project first answers it; it sets no command name. */
const PROJECT = Object.freeze({
  found: true,
  root: ROOT,
  name: 'Notes',
  summary: '',
  declaration: {},
  release: { latest: '0.1.0', stable: '0.1.0' },
  declared: [],
  refresh_seconds: 20,
});

/** The part of shellops' manifest schema the stories need: the fields Manifest shows, and which are required. */
const SCHEMA = Object.freeze({
  required: ['name', 'description', 'org', 'repo'],
  properties: {
    name: { type: 'string', description: 'Human-readable project name.' },
    description: { type: 'string', description: "One-line summary of the project's purpose." },
    'command-name': { type: 'string', description: 'CLI binary name for projects that ship an executable.' },
    org: { type: 'string' },
    repo: { type: 'string' },
  },
});

/** The manifest as the file store first answers it; it sets no command name. */
const MANIFEST = Object.freeze({ id: 'document', revision: 'r1', values: { name: 'Notes', description: 'Notes, kept in git.', org: 'someone', repo: 'notes' } });

/** The manifest after someone changed its description outside the pane. */
const EDITED_OUTSIDE = Object.freeze({ ...MANIFEST, revision: 'r2', values: { ...MANIFEST.values, description: 'Edited by an agent.' } });

/** What the refusing store says to every change. */
const REFUSAL = 'description cannot be cleared: its schema has no empty value for it.';

/** The tabs over a backend that keeps every change it is sent. */
export function Editable() {
  const [rest] = useState(() => standIn(keepingBackend()));
  return framed(rest);
}

/** The tabs over a backend that refuses every change. */
export function Refusing() {
  const [rest] = useState(() => standIn(refusingBackend()));
  return framed(rest);
}

/** The tabs over a backend whose manifest changed outside the pane after the pane read it. */
export function ChangedOutside() {
  const [rest] = useState(() => standIn(keepingBackend(EDITED_OUTSIDE)));
  return framed(rest);
}

/**
 * The tabs over a project that has no manifest until POST /project/adopt
 * writes one, with the form wizard registered. Each POST's body goes to
 * `onAdopt`.
 *
 * @param props The story's props.
 * @param {(body: object) => void} [props.onAdopt] Takes the body of each POST /project/adopt.
 */
export function NoManifestYet({ onAdopt = () => {} }) {
  register(FormWizard);
  const [rest] = useState(() => standIn(manifestlessBackend(onAdopt)));
  useState(() => requestWith(async () => ({ plugins: [] })));
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

/**
 * A backend call that answers the reads and applies each write at the
 * current revision to its own copy of the manifest, answering a write at
 * any other revision as stale. `stored` is the manifest as it is on disk,
 * which differs from what the pane first reads when it changed outside the
 * pane.
 *
 * @param stored The manifest on disk.
 */
function keepingBackend(stored = MANIFEST) {
  let manifest = stored;
  let reads = 0;
  return async (path, options) => {
    if (options?.method === 'POST') {
      manifest = written(manifest, options.body);
      return { data: { record: manifest } };
    }
    reads += path.startsWith('/store/query') ? 1 : 0;
    return read(path, reads === 1 ? MANIFEST : manifest);
  };
}

/**
 * A backend call over a project whose manifest does not exist, so reading
 * it is answered NOT_FOUND as Desktop rejects a 404, until POST
 * /project/adopt writes it from the body's manifest.
 *
 * @param {(body: object) => void} onAdopt Takes the body of each POST /project/adopt.
 */
function manifestlessBackend(onAdopt) {
  let manifest = null;
  return async (path, options) => {
    if (path.startsWith('/project/adopt') && options?.method === 'POST') {
      onAdopt(options.body);
      manifest = { id: 'document', revision: 'r1', values: options.body.manifest };
      return { root: ROOT, path: '.ops/config/manifest.yaml', committed: options.body.commit, state: 'ready' };
    }
    if (path.startsWith('/project/adoption/guess')) {
      return { root: ROOT, found: true, description: 'Notes kept in git.', command: 'notes' };
    }
    if (path.startsWith('/project/adoption')) {
      return { root: ROOT, name: 'notes', repo: 'notes', branch: 'main' };
    }
    if (path.startsWith('/store/query') && !manifest) {
      throw new Error(`404: ${JSON.stringify(failure('The project has no .ops/config/manifest.yaml.', { code: 'NOT_FOUND', status: 404 }))}`);
    }
    return read(path, manifest);
  };
}

/** A backend call that answers the reads and refuses every mutation with REFUSAL, as Desktop rejects a 400. */
function refusingBackend() {
  return async (path, options) => {
    if (options?.method === 'POST') {
      throw new Error(`400: ${JSON.stringify(failure(REFUSAL, { code: 'REFUSED', status: 400 }))}`);
    }
    return read(path, MANIFEST);
  };
}

/**
 * The answer to a read.
 *
 * @param path The path asked for.
 * @param manifest The manifest record the file store answers.
 */
function read(path, manifest) {
  const record = { data: { record: manifest } };
  const answers = [
    ['/about', { version: '0.1.0', branch: 'main' }],
    ['/repos/status', STATUS],
    ['/repos', REPOS],
    ['/project', PROJECT],
    ['/store/query', record],
    ['/store/introspect', { data: { schema: SCHEMA } }],
  ];
  return answers.find(([prefix]) => path.startsWith(prefix))[1];
}

/**
 * The manifest with one write applied, the way the file store reads it
 * back; a write at another revision throws the STALE error as Desktop
 * rejects a 409.
 *
 * @param manifest The manifest before.
 * @param body The body of POST /store/mutate.
 */
function written(manifest, body) {
  if (body.revision !== manifest.revision) {
    const stale = failure('The document changed since it was read.', { code: 'STALE', status: 409, record: manifest });
    throw new Error(`409: ${JSON.stringify(stale)}`);
  }
  return { ...manifest, revision: `${manifest.revision}+`, values: { ...manifest.values, [body.key]: body.value } };
}

/**
 * A failed answer as the store routes shape it.
 *
 * @param {string} message The reason.
 * @param extensions The code, the status and anything else the error carries.
 */
function failure(message, extensions) {
  return { data: null, errors: [{ message, extensions }] };
}

