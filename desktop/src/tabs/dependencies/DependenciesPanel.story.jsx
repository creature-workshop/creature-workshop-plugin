/**
 * @file The stories of the Dependencies tab: a project that declares tools
 * over three channels, one of them missing; the same with every tool
 * installed; one whose check fails once; one whose check says nothing; a
 * project that declares none; and one whose declaration gains its tools
 * while the pane is open. The tests are in dependencies.ct.jsx
 * beside this file.
 */

import { useState } from 'react';
import { WorkshopTabs } from '../../pane/tabs/WorkshopTabs.jsx';
import { standIn } from '../../standIn/index.js';
import { sessionSubject } from '../../subject.js';
import { WorkshopProvider } from '../../workshop/WorkshopProvider.jsx';
import { dependencies } from './tab.js';

/** The repository in every story, the root of a shellops project. */
const ROOT = '/home/someone/notes';

/** GET /repos for a directory that is the repository itself. */
const REPOS = { start: ROOT, inside: true, checkout: ROOT, repos: [{ root: ROOT, name: 'notes' }], refresh_seconds: 20 };

/** GET /repos/status for the repository. */
const STATUS = { root: ROOT, ok: true, branch: 'main', detached: false, upstream: false, ahead: 0, behind: 0, staged: 0, modified: 0, untracked: 0, conflicted: 0 };

/** The tools the project declares, as GET /project lists them. */
const DECLARED = Object.freeze([
  { channel: 'system', tool: 'ffmpeg', version: '6.1.1' },
  { channel: 'system', tool: 'uv', version: '0.11.19' },
  { channel: 'npm', tool: 'pnpm', version: '12.18.0' },
  { channel: 'script', tool: 'hermes', version: '2026.9.24' },
]);

/** What the failing check rejects with: an answer of 500 from the backend. */
const REJECTION = `500: ${JSON.stringify({ data: null, errors: [{ message: 'the check timed out', extensions: { code: 'INTERNAL', status: 500 } }] })}`;

/**
 * The Dependencies tab over a project that declares DECLARED, with the
 * tools named in `missing` not installed.
 *
 * @param props The story's props.
 * @param {string[]} [props.missing] The tools that are not installed.
 */
export function Declared({ missing = ['uv'] }) {
  const [rest] = useState(() => standIn(backend(DECLARED, () => toolchain(DECLARED, missing))));
  return framed(rest);
}

/** The tab over a project whose first check fails, and whose next finds every tool installed. */
export function CheckFailsOnce() {
  const [rest] = useState(() => standIn(backend(DECLARED, failingOnce(() => toolchain(DECLARED, [])))));
  return framed(rest);
}

/** The tab over a project whose check finishes and says nothing about any tool. */
export function CheckSaysNothing() {
  const [rest] = useState(() => standIn(backend(DECLARED, () => toolchain([], []))));
  return framed(rest);
}

/** The tab over a project whose check never answers. */
export function StillChecking() {
  const [rest] = useState(() => standIn(backend(DECLARED, () => new Promise(() => {}))));
  return framed(rest);
}

/**
 * The tab over a project that declares no tools the first time the pane
 * reads it, and DECLARED on every later read, as when tools.yaml is
 * written outside the pane.
 */
export function DeclaredLater() {
  const [rest] = useState(() => standIn(declaringLater()));
  return framed(rest);
}

/** The tab over a project that declares no tools. */
export function NoneDeclared() {
  const [rest] = useState(() => standIn(backend([], () => toolchain([], []))));
  return framed(rest);
}

/**
 * The Dependencies tab alone in the strip, under a provider over `rest`.
 *
 * @param rest The backend call.
 */
function framed(rest) {
  return (
    <WorkshopProvider rest={rest} subject={sessionSubject('stored-session-1', ROOT)}>
      <WorkshopTabs tabs={[dependencies]} />
    </WorkshopProvider>
  );
}

/**
 * GET /project's answer for the project, declaring `declared`, with
 * `toolchain` when the check was asked for.
 *
 * @param declared The tools it declares.
 * @param toolchain The toolchain, or null.
 */
function projectWith(declared, toolchain) {
  return { found: true, root: ROOT, name: 'Notes', summary: '', declaration: {}, release: { latest: '', stable: '' }, declared, refresh_seconds: 20, approved: true, toolchain };
}

/**
 * What `ops install --check` reports for `declared`, with the tools named
 * in `missing` not installed.
 *
 * @param declared The tools the check has a row for.
 * @param {string[]} missing The tools that are not installed.
 */
function toolchain(declared, missing) {
  const rows = declared.map((each) => ({ ...each, installed: !missing.includes(each.tool) }));
  return { ok: missing.length === 0, rows, stderr: '', duration_ms: 12 };
}

/**
 * A backend call over the project: GET /project with the check answers
 * what `check()` gives, and without it answers the declaration alone.
 *
 * @param declared The tools the project declares.
 * @param check Gives the toolchain of a check, or rejects.
 */
function backend(declared, check) {
  return async (path) => {
    if (path.startsWith('/project?') && path.includes('check=1')) {
      return projectWith(declared, await check());
    }
    if (path.startsWith('/project')) {
      return projectWith(declared, null);
    }
    return path.startsWith('/repos/status') ? STATUS : REPOS;
  };
}

/**
 * A backend call over a project that declares nothing on the first GET
 * /project without the check, and DECLARED, all installed, on every read
 * after.
 */
function declaringLater() {
  let reads = 0;
  return async (path) => {
    const declared = reads > 0 ? DECLARED : [];
    if (path.startsWith('/project?') && path.includes('check=0')) {
      reads += 1;
    }
    return backend(declared, () => toolchain(declared, []))(path);
  };
}

/**
 * A check that rejects the first time it is asked, and answers `then()`
 * every time after.
 *
 * @param then Gives the toolchain of every later check.
 */
function failingOnce(then) {
  let failed = false;
  return async () => {
    if (!failed) {
      failed = true;
      throw new Error(REJECTION);
    }
    return then();
  };
}
