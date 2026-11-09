/**
 * @file The state the whole pane shares, held by WorkshopProvider at the top
 * of the pane and read anywhere below it with useWorkshop. It holds:
 *
 * - `about`: the plugin's version and branch;
 * - `subject`: what the pane is about;
 * - `repos`: the git repositories in the subject's folder;
 * - `selected`: the root of the selected repository;
 * - `project`: the shellops project of the selected repository.
 */

import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { client, connect } from '../client/index.js';

/** What the footer shows before the backend has answered. */
const UNKNOWN_ABOUT = { version: '', branch: '' };

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
 * When the folder has exactly one repository, it is selected automatically.
 *
 * @param props The component's props.
 * @param props.rest The backend call, taking a path under the plugin's API.
 * @param {import('../subject.js').Subject} props.subject What the pane is about.
 * @param props.children The pane.
 */
export function WorkshopProvider({ rest, subject, children }) {
  useMemo(() => connect(rest), [rest]);
  const [about, setAbout] = useState(UNKNOWN_ABOUT);
  const [repos, setRepos] = useState(null);
  const [picked, setPicked] = useState('');
  useEffect(askAbout(setAbout), [rest]);
  useEffect(askRepos(subject.folder, setRepos, setPicked), [rest, subject.folder]);
  const [project, setProject] = useState(null);
  const selected = repos?.repos.length === 1 ? repos.repos[0].root : picked;
  useEffect(askProject(selected, setProject), [rest, selected]);
  const value = useMemo(
    () => ({ about, subject, repos, selected, select: setPicked, project, updateProject: setProject }),
    [about, subject, repos, selected, project],
  );

  return <WorkshopContext.Provider value={value}>{children}</WorkshopContext.Provider>;
}

/**
 * Returns the pane's shared state: `{about, subject, repos, selected, select, project, updateProject}`.
 *
 * - `repos` is the answer to GET /repos, or null while loading.
 * - `selected` is the selected repository's root, or an empty string.
 * - `select(root)` selects a repository.
 * - `project` is the answer to GET /project for the selected repository, or
 *   null while loading or when no repository is selected.
 * - `updateProject(answer)` replaces `project`, for a part of the pane that
 *   changed the project and got the new answer back.
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
    client.about().then((answer) => open && setAbout(answer));
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
    client.repos(folder).then((answer) => open && setRepos(answer));
    return () => { open = false; };
  };
}

/**
 * Loads `project` from GET /project for the selected repository, without
 * the toolchain check. Sets it to null when no repository is selected. An
 * answer that arrives after the selection changes is dropped.
 *
 * @effect
 * @param selected The selected repository's root, or an empty string.
 * @param setProject Stores the answer.
 */
function askProject(selected, setProject) {
  return () => {
    let open = true;
    setProject(null);
    if (selected) {
      client.project(selected, false).then((answer) => open && setProject(answer));
    }
    return () => { open = false; };
  };
}
