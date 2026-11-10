/**
 * @file The state the whole pane shares, held by WorkshopProvider at the top
 * of the pane and read anywhere below it with useWorkshop. It holds:
 *
 * - `about`: the plugin's version and branch;
 * - `subject`: what the pane is about;
 * - `repos`: the git repositories in the subject's folder, each with its
 *   worktrees;
 * - `repo`: the root of the selected repository;
 * - `selected`: the root of the checkout the pane reads, the worktree
 *   picked for the selected repository or else its main worktree;
 * - `project`: the shellops project of that checkout.
 *
 * `about`, `repos` and `project` are remote data, as remote.js
 * describes: loading, failure or success. `retry` asks for one of them
 * again.
 */

import { createContext, useContext, useMemo } from 'react';
import { connect } from '../client/index.js';
import { useAbout } from './useAbout.js';
import { useCheckout } from './useCheckout.js';
import { useProject } from './useProject.js';
import { useRetry } from './useRetry.js';

/** The shared state; null outside a WorkshopProvider. */
const WorkshopContext = createContext(null);

/**
 * Provides the pane's shared state to its children.
 *
 * It connects the client to `rest` before anything renders, then holds one
 * piece per concern, each in its own hook: `about`; the repositories and
 * the selected checkout; that checkout's `project`; and `retry`, which asks
 * for one of the three remote pieces again.
 *
 * @param props The component's props.
 * @param props.rest The backend call, taking a path under the plugin's API.
 * @param {import('../subject.js').Subject} props.subject What the pane is about.
 * @param props.children The pane.
 */
export function WorkshopProvider({ rest, subject, children }) {
  useMemo(() => connect(rest), [rest]);
  const [retried, retry] = useRetry();
  const about = useAbout(rest, retried.about);
  const checkout = useCheckout(rest, subject.folder, retried.repos);
  const project = useProject(rest, checkout.selected, retried.project);
  const value = useMemo(() => ({ about, subject, ...checkout, project, retry }), [about, subject, checkout, project, retry]);

  return <WorkshopContext.Provider value={value}>{children}</WorkshopContext.Provider>;
}

/**
 * Returns the pane's shared state: `{about, subject, repos, repo, selected, select, selectWorktree, project, retry}`.
 *
 * - `about` is GET /about's answer, as remote data.
 * - `repos` is GET /repos's answer, as remote data.
 * - `repo` is the selected repository's root, or an empty string.
 * - `selected` is the root of the checkout the pane reads, or an empty string.
 * - `select(root)` selects a repository.
 * - `selectWorktree(root)` picks one of the selected repository's worktrees.
 * - `project` is GET /project's answer for the selected checkout, as
 *   remote data; loading while no repository is selected.
 * - `retry(name)` asks for `about`, `repos` or `project` again.
 */
export function useWorkshop() {
  return useContext(WorkshopContext);
}
