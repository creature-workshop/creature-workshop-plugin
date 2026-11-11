/**
 * @file The state the whole pane shares, held by WorkshopProvider at the top
 * of the pane and read anywhere below it with useWorkshop. It holds:
 *
 * - `about`: the plugin's version and branch;
 * - `subject`: what the pane is about;
 * - `repos`: the git repositories in the subject's folder, each with its
 *   worktrees;
 * - `repo`: the root of the repository the session is on;
 * - `selected`: the root of the checkout the session is on, one of that
 *   repository's worktrees; the backend decides both, and the agent's
 *   tools work on the same checkout;
 * - `project`: the shellops project of that checkout;
 * - `setup`: whether that checkout has a workshop, read again every 5
 *   seconds so a workshop added or deleted outside the pane shows.
 *
 * `about`, `repos`, `project` and `setup` are remote data, as remote.js
 * describes: loading, failure or success. `retry` asks for one of them
 * again.
 */

import { createContext, useContext, useMemo } from 'react';
import { connect } from '../client/index.js';
import { useAbout } from './useAbout.js';
import { useCheckout } from './useCheckout.js';
import { useProject } from './useProject.js';
import { useRetry } from './useRetry.js';
import { useSetup } from './useSetup.js';
import { useSetupFollower } from './useSetupFollower.js';

/** The shared state; null outside a WorkshopProvider. */
const WorkshopContext = createContext(null);

/**
 * How often the pane re-reads the checkout's setup, in seconds. It is its
 * own, shorter than pane_refresh_seconds, because the read only looks for
 * .ops/config, while that setting paces the git status.
 */
const SETUP_REFRESH_SECONDS = 5;

/**
 * Provides the pane's shared state to its children.
 *
 * It connects the client to `rest` before anything renders, then holds one
 * piece per concern, each in its own hook: `about`; the repositories and
 * the selected checkout; that checkout's `project` and `setup`; and
 * `retry`, which asks for one of the four remote pieces again.
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
  const checkout = useCheckout(rest, subject, retried.repos);
  const project = useProject(rest, checkout.selected, retried.project);
  const setup = useSetup(rest, checkout.selected, retried.setup, SETUP_REFRESH_SECONDS);
  useSetupFollower(checkout.selected, setup, retry);
  const value = useMemo(() => ({ about, subject, ...checkout, project, setup, retry }), [about, subject, checkout, project, setup, retry]);

  return <WorkshopContext.Provider value={value}>{children}</WorkshopContext.Provider>;
}

/**
 * Returns the pane's shared state: `{about, subject, repos, repo, selected, select, selectWorktree, project, setup, retry}`.
 *
 * - `about` is GET /about's answer, as remote data.
 * - `repos` is GET /repos's answer, as remote data.
 * - `repo` is the selected repository's root, or an empty string.
 * - `selected` is the root of the checkout the pane reads, or an empty string.
 * - `select(root)` picks a repository for the session, through the backend.
 * - `selectWorktree(root)` picks one worktree for the session, through the backend.
 * - `project` is GET /project's answer for the selected checkout, as
 *   remote data; loading while no repository is selected.
 * - `setup` is GET /project/setup's answer for the selected checkout, as
 *   remote data; loading while no repository is selected.
 * - `retry(name)` asks for `about`, `repos`, `project` or `setup` again.
 */
export function useWorkshop() {
  return useContext(WorkshopContext);
}
