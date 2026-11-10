/**
 * @file The state the whole pane shares, held by WorkshopProvider at the top
 * of the pane and read anywhere below it with useWorkshop. It holds:
 *
 * - `about`: the plugin's version and branch;
 * - `subject`: what the pane is about;
 * - `repos`: the git repositories in the subject's folder;
 * - `selected`: the root of the selected repository;
 * - `project`: the shellops project of the selected repository.
 *
 * `about`, `repos` and `project` are remote data, as remote.js
 * describes: loading, failure or success. `retry` asks for one of them
 * again.
 */

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { client, connect } from '../client/index.js';
import { dataOr, LOADING, remoteOf } from '../remote.js';

/** How many times each piece has been asked for again, before anyone has. */
const NOT_RETRIED = Object.freeze({ about: 0, repos: 0, project: 0 });

/** The shared state; null outside a WorkshopProvider. */
const WorkshopContext = createContext(null);

/**
 * Provides the pane's shared state to its children.
 *
 * It connects the client to `rest` before anything renders, then loads:
 *
 * - `about`, once;
 * - `repos`, each time the subject's folder changes;
 * - `project`, each time the selected repository changes.
 *
 * Each loads again when `retry` names it. When the folder has exactly one
 * repository, it is selected automatically.
 *
 * @param props The component's props.
 * @param props.rest The backend call, taking a path under the plugin's API.
 * @param {import('../subject.js').Subject} props.subject What the pane is about.
 * @param props.children The pane.
 */
export function WorkshopProvider({ rest, subject, children }) {
  useMemo(() => connect(rest), [rest]);
  const [retried, setRetried] = useState(NOT_RETRIED);
  const [about, setAbout] = useState(LOADING);
  const [repos, setRepos] = useState(LOADING);
  const [picked, setPicked] = useState('');
  const [project, setProject] = useState(LOADING);
  const found = dataOr(repos, { repos: [] }).repos;
  const selected = found.length === 1 ? found[0].root : picked;
  useEffect(askAbout(setAbout), [rest, retried.about]);
  useEffect(askRepos(subject.folder, setRepos, setPicked), [rest, subject.folder, retried.repos]);
  useEffect(askProject(selected, setProject), [rest, selected, retried.project]);
  const retry = useCallback((name) => setRetried((before) => ({ ...before, [name]: before[name] + 1 })), []);
  const value = useMemo(
    () => ({ about, subject, repos, selected, select: setPicked, project, retry }),
    [about, subject, repos, selected, project, retry],
  );

  return <WorkshopContext.Provider value={value}>{children}</WorkshopContext.Provider>;
}

/**
 * Returns the pane's shared state: `{about, subject, repos, selected, select, project, retry}`.
 *
 * - `about` is GET /about's answer, as remote data.
 * - `repos` is GET /repos's answer, as remote data.
 * - `selected` is the selected repository's root, or an empty string.
 * - `select(root)` selects a repository.
 * - `project` is GET /project's answer for the selected repository, as
 *   remote data; loading while no repository is selected.
 * - `retry(name)` asks for `about`, `repos` or `project` again.
 */
export function useWorkshop() {
  return useContext(WorkshopContext);
}

/**
 * Loads `about` from GET /about.
 *
 * @effect
 * @param setAbout Stores the answer.
 */
function askAbout(setAbout) {
  return () => {
    let open = true;
    setAbout(LOADING);
    client.about().then((result) => open && setAbout(remoteOf(result)));
    return () => { open = false; };
  };
}

/**
 * Loads `repos` from GET /repos for the folder, and clears the selection.
 * An answer that arrives after the folder changes is dropped.
 *
 * @effect
 * @param folder The subject's folder.
 * @param setRepos Stores the answer.
 * @param setPicked Sets the selection.
 */
function askRepos(folder, setRepos, setPicked) {
  return () => {
    let open = true;
    setPicked('');
    setRepos(LOADING);
    client.repos(folder).then((result) => open && setRepos(remoteOf(result)));
    return () => { open = false; };
  };
}

/**
 * Loads `project` from GET /project for the selected repository, without
 * the toolchain check. It stays loading while no repository is selected.
 * An answer that arrives after the selection changes is dropped.
 *
 * @effect
 * @param selected The selected repository's root, or an empty string.
 * @param setProject Stores the answer.
 */
function askProject(selected, setProject) {
  return () => {
    let open = true;
    setProject(LOADING);
    if (selected) {
      client.project(selected, false).then((result) => open && setProject(remoteOf(result)));
    }
    return () => { open = false; };
  };
}
