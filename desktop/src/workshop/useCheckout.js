/**
 * @file The git repositories in the session's folder and which checkout of
 * them the session is on, as the pane's shared state holds them. The
 * backend decides the checkout, for the pane and for the agent alike, so
 * the pane keeps no pick of its own: it sends a pick to the backend, and
 * shows what the backend answered.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { client } from '../client/index.js';
import { onSelectionChanged } from '../events.js';
import { dataOr, LOADING, remoteOf } from '../remote.js';

/** GET /repos's answer while it has not arrived: no repositories, nothing selected, and the interval the pane reads on until the backend names one. */
const NO_REPOS = Object.freeze({ repos: [], repository: '', selected: '', refresh_seconds: 20 });

/** What to do with a failed read of the selection that only refreshes it: nothing, so the pane keeps what it shows. */
const KEEP_SHOWING = () => {};

/**
 * Returns `{repos, repo, selected, select, selectWorktree}` for `subject`:
 *
 * - `repos`, GET /repos's answer as remote data, loaded each time the
 *   subject, `rest` or `retried` changes; it says what the session is on;
 * - `repo`, the root of the repository the session is on, or an empty string;
 * - `selected`, the root of the checkout the session is on, one of
 *   `repo`'s worktrees, or an empty string;
 * - `select(root)`, which picks a repository, through POST /selection;
 * - `selectWorktree(root)`, which picks one worktree, through POST
 *   /selection/worktree.
 *
 * `repo` and `selected` follow the backend: they are read again from GET
 * /selection every `refresh_seconds` and whenever the backend says a
 * selection changed, which is how the pane follows a pick made in another window.
 * A pick the backend refuses is shown as the failure of `repos`. The
 * answer is the same object until one of those changes.
 *
 * @param rest The backend call the client is connected to.
 * @param {import('../subject.js').Subject} subject What the pane is about.
 * @param {number} retried How many times `repos` has been asked for again.
 */
export function useCheckout(rest, subject, retried) {
  const [repos, setRepos] = useState(LOADING);
  const [moved, setMoved] = useState(null);
  const asked = useRef(0);
  useEffect(askRepos(subject, { asked, setRepos, setMoved }), [rest, subject.id, subject.folder, retried]);
  const listed = dataOr(repos, NO_REPOS);
  useEffect(follow(subject, listed.refresh_seconds, keeping(asked, setMoved, KEEP_SHOWING)), [rest, subject.id, subject.folder, listed.refresh_seconds]);
  const { repository: repo, selected } = moved ?? listed;
  const pick = useCallback(keeping(asked, setMoved, (result) => setRepos(remoteOf(result))), []);
  const select = useCallback((root) => pick(client.select(subject, root)), [subject, pick]);
  const selectWorktree = useCallback((root) => pick(client.selectWorktree(subject, root)), [subject, pick]);
  return useMemo(() => ({ repos, repo, selected, select, selectWorktree }), [repos, repo, selected, select, selectWorktree]);
}

/**
 * A function that takes a request for the selection and keeps its answer,
 * unless a later request was made before it answered. A selection is kept
 * with `setMoved`, and a failure is handed to `onFailure`.
 *
 * @param asked A ref that counts the requests made.
 * @param setMoved Stores the selection the backend answered.
 * @param onFailure Takes the failed result.
 */
function keeping(asked, setMoved, onFailure) {
  return (request) => {
    asked.current += 1;
    const mine = asked.current;
    return request.then((result) => mine === asked.current && (result.ok ? setMoved(result.data) : onFailure(result)));
  };
}

/**
 * Loads `repos` from GET /repos for the subject, and forgets the selection
 * read since the last load, so the pane shows what this answer says. An
 * answer that arrives after the subject changes is dropped, and so is a
 * read of the selection that was on its way.
 *
 * @effect
 * @param {import('../subject.js').Subject} subject What the pane is about.
 * @param state What the effect writes.
 * @param state.asked A ref that counts the requests made for the selection.
 * @param state.setRepos Stores the answer.
 * @param state.setMoved Stores the selection read since the load.
 */
function askRepos(subject, { asked, setRepos, setMoved }) {
  return () => {
    let open = true;
    asked.current += 1;
    setMoved(null);
    setRepos(LOADING);
    client.repos(subject).then((result) => open && setRepos(remoteOf(result)));
    return () => { open = false; };
  };
}

/**
 * Reads the subject's selection again every `seconds` and whenever the
 * backend says a selection changed, until the subject or the interval
 * changes or the component goes away.
 *
 * @effect
 * @param {import('../subject.js').Subject} subject What the pane is about.
 * @param seconds How long to wait between reads.
 * @param keep Takes a request for the selection and keeps its answer.
 */
function follow(subject, seconds, keep) {
  return () => {
    const read = () => keep(client.selection(subject));
    const timer = setInterval(read, seconds * 1000);
    const stop = onSelectionChanged(read);
    return () => {
      clearInterval(timer);
      stop();
    };
  };
}
