/**
 * @file The state the whole pane shares: what the plugin is, the subject the
 * pane is about, the git repositories the subject's folder holds, and which
 * of them is selected. WorkshopProvider holds it at the top of the pane, and
 * any part of the pane reads it with useWorkshop. The provider also connects
 * the backend's client to the backend call it is given, before anything
 * below it renders.
 */

import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { client, connect } from '../client/index.js';

/** What the footer shows before the backend has answered. */
const UNKNOWN_ABOUT = { version: '', branch: '' };

/** The shared state; null outside a WorkshopProvider. */
const WorkshopContext = createContext(null);

/**
 * Holds the pane's shared state for its children, connecting the client to
 * the backend call first. It asks the backend what the plugin is once, and
 * which repositories the subject's folder holds whenever the folder
 * changes. When the folder holds exactly one repository, that one is
 * selected; otherwise none is, until a part of the pane selects one.
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
  const selected = repos?.repos.length === 1 ? repos.repos[0].root : picked;
  const value = useMemo(() => ({ about, subject, repos, selected, select: setPicked }), [about, subject, repos, selected]);

  return <WorkshopContext.Provider value={value}>{children}</WorkshopContext.Provider>;
}

/**
 * The pane's shared state: {about, subject, repos, selected, select}.
 * `repos` is the answer to GET /repos, or null until it arrives; `selected`
 * is the root of the selected repository, or empty; `select` takes a root.
 */
export function useWorkshop() {
  return useContext(WorkshopContext);
}

/**
 * The effect that asks the backend what the plugin is, and keeps the answer
 * unless the provider went away first.
 *
 * @effect
 * @param setAbout The setter of the answer.
 */
function askAbout(setAbout) {
  return () => {
    let open = true;
    client.about().then((answer) => open && setAbout(answer));
    return () => { open = false; };
  };
}

/**
 * The effect that asks the backend which repositories a folder holds,
 * clears the selection, which belonged to the folder before, and keeps the
 * answer unless the folder changed or the provider went away first.
 *
 * @effect
 * @param folder The subject's folder.
 * @param setRepos The setter of the answer.
 * @param setPicked The setter of the selection.
 */
function askRepos(folder, setRepos, setPicked) {
  return () => {
    let open = true;
    setPicked('');
    client.repos(folder).then((answer) => open && setRepos(answer));
    return () => { open = false; };
  };
}
