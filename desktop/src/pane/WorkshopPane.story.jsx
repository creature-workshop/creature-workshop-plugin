/**
 * @file The stories of the Workshop pane: each named export is the pane in
 * one scenario, with the backend's answers it runs against built in, so a
 * test mounts a story and passes nothing but plain data. In OnMain and
 * OutsideGit the session's directory holds no repository; in Adopted and
 * NotAdopted it is one, with a workshop on its branch and without; in
 * Unapproved its workshop is one the user has not approved; and in
 * WorkshopDeleted its workshop goes away while the pane is open. The header's own
 * scenarios are in header/Header.story.jsx. The pane's tests are in
 * pane.ct.jsx beside this file.
 */

import { cn } from '@hermes/plugin-sdk';
import { useState } from 'react';
import { requestWith } from '../modules/approval/approval.js';
import { standIn } from '../standIn/index.js';
import { sessionSubject } from '../subject.js';
import { FormWizard } from '../wizard/form/FormWizard.jsx';
import { register } from '../wizard/implementation.js';
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
const ONE_REPO = { start: CWD, inside: true, checkout: CWD, repos: [{ root: CWD, name: 'notes' }], refresh_seconds: 20 };

/** GET /repos/status for that repository: clean, on main. */
const CLEAN = { root: CWD, ok: true, branch: 'main', detached: false, upstream: false, ahead: 0, behind: 0, staged: 0, modified: 0, untracked: 0, conflicted: 0 };

/** GET /project outside any shellops project. */
const NO_PROJECT = { found: false, start: CWD, refresh_seconds: 20 };

/** GET /store/introspect for the manifest: each key a string. */
const MANIFEST_SCHEMA = Object.freeze({
  data: { schema: { properties: { name: { type: 'string' }, description: { type: 'string' }, 'command-name': { type: 'string' }, org: { type: 'string' }, repo: { type: 'string' } } } },
});

/** GET /store/query for the manifest of the project, as the file store answers it. */
const MANIFEST_RECORD = Object.freeze({
  data: { record: { id: 'document', revision: 'r1', values: { name: 'Notes', description: 'Notes, kept in git.', 'command-name': 'notes', org: 'someone', repo: 'notes' } } },
});

/** What the backend's call rejects with, by the kind of failure: as Desktop rejects an answer of 400 or more, or as a call that never reached the backend. */
const REJECTIONS = Object.freeze({
  'no-route': '404: {"detail":"Not Found"}',
  internal: `500: ${JSON.stringify({ data: null, errors: [{ message: "KeyError: 'root'", extensions: { code: 'INTERNAL', status: 500 } }] })}`,
  unreachable: 'bridge unavailable',
  refused: `400: ${JSON.stringify({ data: null, errors: [{ message: 'notes already has a manifest.', extensions: { code: 'REFUSED', status: 400 } }] })}`,
});

/** What GET /project/adoption suggests in the stories: the folder's name, and the remote's repository. */
const SUGGESTED = Object.freeze({ root: CWD, name: 'notes', repo: 'notes', branch: 'main' });

/** What GET /project/adoption/guess answers in the stories: the agent's description and command. */
const GUESSED = Object.freeze({ root: CWD, found: true, description: 'Notes kept in git.', command: 'notes' });

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

/**
 * The pane over a repository whose workshop is deleted outside the pane
 * after the first time the pane reads its setup: every later read finds no
 * workshop.
 */
export function WorkshopDeleted() {
  const [rest] = useState(() => deletingBackend());
  return framed(rest, DOCKED_WIDTH);
}

/**
 * The pane over an adopted repository whose backend fails the first call
 * to `path` the way `kind` names, and answers every call after it, so Try
 * again succeeds.
 *
 * @param props The story's props.
 * @param {string} props.path The path whose first call fails, such as `/repos?` or `/store/query`.
 * @param {'no-route' | 'internal' | 'unreachable'} props.kind How it fails.
 */
export function FailingOnce({ path, kind }) {
  const [rest] = useState(() => failingOnce(repositoryBackend(projectAt(CWD, { latest: '0.1.0', stable: '0.1.0' })), path, REJECTIONS[kind]));
  return framed(rest, DOCKED_WIDTH);
}

/**
 * The pane over a repository whose branch has no workshop, with the form
 * wizard registered. GET /project/adoption suggests SUGGESTED; POST
 * /project/adopt hands what it is sent to `onAdopt` and adopts the branch,
 * after which the checkout is a shellops project, unless `fails` is set,
 * when the first adoption is refused. Hermes's settings list `approved`
 * as the approved projects and hand each write of them to `onApprove`,
 * unless `unsaved` is set, when Hermes saves nothing.
 *
 * @param props The story's props.
 * @param {(body: object) => void} [props.onAdopt] Takes the body of each POST /project/adopt.
 * @param {boolean} [props.fails] Whether the first adoption is refused.
 * @param {boolean} [props.unguessed] Whether the agent's guess fails.
 * @param {string[]} [props.approved] The roots the approved_projects setting lists.
 * @param {(roots: string[]) => void} [props.onApprove] Takes the roots of each write of the setting.
 * @param {boolean} [props.unsaved] Whether Hermes fails to save the setting.
 */
export function NotAdopted(props) {
  const { onAdopt = () => {}, fails = false, unguessed = false, approved = [], onApprove = () => {}, unsaved = false } = props;
  register(FormWizard);
  const [rest] = useState(() => adoptingBackend(onAdopt, fails, unguessed));
  useState(() => requestWith(settingsGateway(approved, onApprove, unsaved)));
  return framed(rest, DOCKED_WIDTH);
}

/**
 * The pane over a repository that is a shellops project's root and that
 * the user has not approved, until the approved_projects setting is
 * written, after which GET /project answers it as approved. Hermes's
 * settings list `approved` as the approved projects and hand each write of
 * them to `onApprove`, unless `unsaved` is set, when Hermes saves nothing.
 *
 * @param props The story's props.
 * @param {string[]} [props.approved] The roots the approved_projects setting lists.
 * @param {(roots: string[]) => void} [props.onApprove] Takes the roots of each write of the setting.
 * @param {boolean} [props.unsaved] Whether Hermes fails to save the setting.
 */
export function Unapproved(props) {
  const { approved = [], onApprove = () => {}, unsaved = false } = props;
  const [backend] = useState(() => approvingBackend(approved, onApprove, unsaved));
  useState(() => requestWith(backend.gateway));
  return framed(backend.rest, DOCKED_WIDTH);
}

/**
 * GET /project for the approved shellops project rooted at root, without the toolchain.
 *
 * @param root The project's root.
 * @param release The release record of its lock.
 */
function projectAt(root, release) {
  return { found: true, root, name: 'Notes', summary: '', declaration: {}, release, declared: [], refresh_seconds: 20, approved: true };
}

/**
 * A backend over a shellops project that is not approved until the
 * approved_projects setting is written, with the stand-in for Hermes's
 * gateway that takes that write: `{rest, gateway}`.
 *
 * @param {string[]} approved The roots the setting lists.
 * @param {(roots: string[]) => void} onApprove Takes the roots of each write.
 * @param {boolean} unsaved Whether every call to the gateway fails.
 */
function approvingBackend(approved, onApprove, unsaved) {
  let written = false;
  const record = (roots) => {
    written = true;
    onApprove(roots);
  };
  const rest = async (path) => repositoryBackend({ ...projectAt(CWD, { latest: '', stable: '' }), approved: written })(path);
  return { rest, gateway: settingsGateway(approved, record, unsaved) };
}

/**
 * A backend call over a directory that is one repository, answering GET
 * /project with project, GET /project/setup with setup, and GET
 * /store/query and GET /store/introspect with its manifest.
 *
 * @param project The answer to GET /project.
 * @param {'no-workshop' | 'ready'} [setup] Whether the checkout has a workshop.
 */
function repositoryBackend(project, setup = 'ready') {
  const answers = [
    ['/about', ABOUT],
    ['/repos/status', CLEAN],
    ['/repos', ONE_REPO],
    ['/project/setup', { root: CWD, state: setup }],
    ['/project', project],
    ['/store/query', MANIFEST_RECORD],
    ['/store/introspect', MANIFEST_SCHEMA],
  ];
  return standIn(async (path) => answers.find(([prefix]) => path.startsWith(prefix))[1]);
}

/**
 * A backend over a shellops project until its setup has been read once,
 * and a checkout with no workshop after, as when .ops/ is deleted.
 */
function deletingBackend() {
  let reads = 0;
  return async (path) => {
    const deleted = reads > 0;
    if (path.startsWith('/project/setup')) {
      reads += 1;
    }
    return repositoryBackend(deleted ? NO_PROJECT : projectAt(CWD, { latest: '', stable: '' }), deleted ? 'no-workshop' : 'ready')(path);
  };
}

/**
 * A stand-in for Hermes's gateway as approval.js calls it: the plugin list
 * holds `approved` as this plugin's approved_projects, and each write of
 * the setting goes to `onApprove`. When `unsaved` is set, every call fails.
 *
 * @param {string[]} approved The roots the setting lists.
 * @param {(roots: string[]) => void} onApprove Takes the roots of each write.
 * @param {boolean} unsaved Whether every call fails.
 */
function settingsGateway(approved, onApprove, unsaved) {
  return async (method, params) => {
    if (unsaved) {
      throw new Error('the gateway is restarting');
    }
    if (params.action === 'settings') {
      onApprove(params.values.approved_projects);
    }
    const listing = {
      plugins: [
        { key: 'creature-workshop', settings_schema: [{ key: 'approved_projects', value: approved }] },
      ],
    };
    return listing;
  };
}

/**
 * A backend over a checkout whose branch has no workshop until POST
 * /project/adopt succeeds, and a shellops project after. Each POST's body
 * goes to `onAdopt`; when `fails` is set, the first is refused.
 *
 * @param {(body: object) => void} onAdopt Takes the body of each POST /project/adopt.
 * @param {boolean} fails Whether the first adoption is refused.
 * @param {boolean} unguessed Whether GET /project/adoption/guess fails.
 */
function adoptingBackend(onAdopt, fails, unguessed) {
  let adopted = false;
  let posts = 0;
  return async (path, options = {}) => {
    if (path.startsWith('/project/adopt') && options.method === 'POST') {
      posts += 1;
      onAdopt(options.body);
      if (fails && posts === 1) {
        throw new Error(REJECTIONS.refused);
      }
      adopted = true;
      return { root: CWD, path: '.ops/config/manifest.yaml', committed: options.body.commit, state: 'ready' };
    }
    if (path.startsWith('/project/adoption/guess')) {
      return unguessed ? Promise.reject(new Error(REJECTIONS['no-route'])) : GUESSED;
    }
    if (path.startsWith('/project/adoption')) {
      return SUGGESTED;
    }
    return repositoryBackend(adopted ? projectAt(CWD, { latest: '', stable: '' }) : NO_PROJECT, adopted ? 'ready' : 'no-workshop')(path);
  };
}

/**
 * A backend that rejects the first call to `path` with `rejection`, and
 * passes every other call to `rest`.
 *
 * @param rest The backend that answers.
 * @param {string} path The path whose first call fails.
 * @param {string} rejection The message of the error the call rejects with.
 */
function failingOnce(rest, path, rejection) {
  let failed = false;
  return async (asked, ...args) => {
    if (asked.startsWith(path) && !failed) {
      failed = true;
      throw new Error(rejection);
    }
    return rest(asked, ...args);
  };
}

/**
 * A backend call that answers GET /about with about and GET /repos with no repositories.
 *
 * @param about The answer to GET /about.
 */
function backendWith(about) {
  return standIn(async (path) => (path.startsWith('/about') ? about : NO_REPOS));
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
