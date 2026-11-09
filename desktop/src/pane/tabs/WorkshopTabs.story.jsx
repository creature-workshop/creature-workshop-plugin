/**
 * @file The stories of the Workshop tabs on their own: a shellops project
 * with the real Project Info tab and a second tab beside it, so a test can
 * switch between them. The tests are in tabs.ct.jsx beside this file.
 */

import { projectInfo } from '../../tabs/project-info/tab.js';
import { sessionSubject } from '../../subject.js';
import { WorkshopProvider } from '../../workshop/WorkshopProvider.jsx';
import { WorkshopTabs } from './WorkshopTabs.jsx';

/** The repository in every story, the root of a shellops project. */
const ROOT = '/home/someone/notes';

/** A second tab, with a panel that says which it is. */
const SECOND = Object.freeze({ id: 'second', label: 'Second', Panel: () => <p>The second panel</p> });

/** Answers of the backend by path prefix, for a directory that is one adopted repository. */
const ANSWERS = [
  ['/about', { version: '0.1.0-dev.9', branch: 'main' }],
  ['/repos/status', { root: ROOT, ok: true, branch: 'main', detached: false, upstream: false, ahead: 0, behind: 0, staged: 0, modified: 0, untracked: 0, conflicted: 0 }],
  ['/repos', { start: ROOT, inside: true, repos: [{ root: ROOT, name: 'notes' }], refresh_seconds: 20 }],
  ['/project', { found: true, root: ROOT, name: 'notes', summary: '', declaration: {}, release: { latest: '0.1.0', stable: '0.1.0' }, declared: [], refresh_seconds: 20 }],
];

/**
 * The backend call over ANSWERS.
 *
 * @param path The path asked for.
 */
async function rest(path) {
  return ANSWERS.find(([prefix]) => path.startsWith(prefix))[1];
}

/** The tabs with Project Info and a second tab. */
export function TwoTabs() {
  return (
    <WorkshopProvider rest={rest} subject={sessionSubject('stored-session-1', ROOT)}>
      <WorkshopTabs tabs={[projectInfo, SECOND]} />
    </WorkshopProvider>
  );
}
