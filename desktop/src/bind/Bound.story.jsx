/**
 * @file The stories of binding: an ordinary controlled component, NameBox,
 * which knows nothing about the pane's data, bound to the name in the
 * manifest by a `bind` prop where it is used; and the same component
 * bound to a file the backend cannot read. The backend keeps each write it
 * is sent. The tests are in bound.ct.jsx beside this file.
 */

import { cn } from '@hermes/plugin-sdk';
import { useState } from 'react';
import { standIn } from '../standIn/index.js';
import { sessionSubject } from '../subject.js';
import { WorkshopProvider } from '../workshop/WorkshopProvider.jsx';

/** The repository in every story, the root of a shellops project. */
const ROOT = '/home/someone/notes';

/** The name in the manifest, as a binding. */
const NAME = Object.freeze({ kind: 'file', source: 'config/manifest.yaml', record: 'document', key: 'name' });

/** The manifest as the backend first answers it. */
const MANIFEST = Object.freeze({ id: 'document', revision: 'r1', values: { name: 'Notes' } });

/** What the backend answers to each read that is not the manifest. */
const READS = Object.freeze([
  ['/about', { version: '0.1.0', branch: 'main' }],
  ['/repos/status', { root: ROOT, ok: true, branch: 'main', detached: false, upstream: false, ahead: 0, behind: 0, staged: 0, modified: 0, untracked: 0, conflicted: 0 }],
  ['/repos', { start: ROOT, inside: true, checkout: ROOT, repos: [{ root: ROOT, name: 'notes' }], refresh_seconds: 20 }],
  ['/project/setup', { root: ROOT, state: 'ready' }],
  ['/project', { found: true, root: ROOT, name: 'Notes', summary: '', declaration: {}, release: { latest: '', stable: '' }, declared: [], refresh_seconds: 20 }],
  ['/store/introspect', { data: { schema: { properties: { name: { type: 'string' } } } } }],
]);

/**
 * A text box for a name: an ordinary controlled component. It shows
 * `value`, calls `onChange` with what is typed, and says when a change is
 * being saved and why the last one failed.
 *
 * @param props The component's props.
 * @param {string} [props.value] The name.
 * @param {(name: string) => void} props.onChange Takes the name as typed.
 * @param {boolean} [props.saving] Whether a change is being saved.
 * @param {string} [props.error] Why the last change failed, or empty.
 */
function NameBox({ value, onChange, saving, error }) {
  return (
    <label className={cn('workshop-name-box')}>
      Name
      <input value={value ?? ''} onChange={(event) => onChange(event.target.value)} />
      {saving && <span role="status" className={cn('workshop-name-saving')}>Saving</span>}
      {error && <span role="alert" className={cn('workshop-name-error')}>{error}</span>}
    </label>
  );
}

/**
 * NameBox bound to the name in the manifest, over a backend that keeps
 * each write and hands its body to `onWrite`.
 *
 * @param props The story's props.
 * @param {(body: object) => void} [props.onWrite] Takes the body of each POST /store/mutate.
 */
export function BoundToAKey({ onWrite = () => {} }) {
  const [rest] = useState(() => standIn(keepingBackend(onWrite)));
  return framed(rest);
}

/** NameBox bound to the name in a manifest the backend cannot be reached for. */
export function Unreadable() {
  const [rest] = useState(() => standIn(unreadableBackend()));
  return framed(rest);
}

/**
 * NameBox, bound, under a provider over `rest`.
 *
 * @param rest The backend call.
 */
function framed(rest) {
  return (
    <WorkshopProvider rest={rest} subject={sessionSubject('stored-session-1', ROOT)}>
      <div className={cn('workshop-bound-story')}>
        <NameBox bind={NAME} />
      </div>
    </WorkshopProvider>
  );
}

/**
 * A backend call that answers the reads, and applies each write to its own
 * copy of the manifest under a new revision.
 *
 * @param {(body: object) => void} onWrite Takes the body of each POST /store/mutate.
 */
function keepingBackend(onWrite) {
  let manifest = MANIFEST;
  return async (path, options) => {
    if (options?.method === 'POST') {
      onWrite(options.body);
      manifest = { ...manifest, revision: `${manifest.revision}+`, values: { ...manifest.values, [options.body.key]: options.body.value } };
      return { data: { record: manifest } };
    }
    return path.startsWith('/store/query') ? { data: { record: manifest } } : answerTo(path);
  };
}

/** A backend call that answers every read but the manifest's, which never reaches the backend. */
function unreadableBackend() {
  return async (path) => {
    if (path.startsWith('/store/query')) {
      throw new Error('never reached the backend');
    }
    return answerTo(path);
  };
}

/**
 * The answer to a read that is not the manifest.
 *
 * @param {string} path The path asked for.
 */
function answerTo(path) {
  return READS.find(([prefix]) => path.startsWith(prefix))[1];
}
