/**
 * @file The git repositories in the session's folder and which checkout of
 * them the pane reads, as the pane's shared state holds them.
 */

import { useCallback, useEffect, useMemo, useState } from 'react';
import { client } from '../client/index.js';
import { dataOr, LOADING, remoteOf } from '../remote.js';
import { checkoutOf, repositoryAt, repositoryHolding } from './selection.js';

/**
 * Returns `{repos, repo, selected, select, selectWorktree}` for `folder`:
 *
 * - `repos`, GET /repos's answer as remote data, loaded each time `folder`,
 *   `rest` or `retried` changes;
 * - `repo`, the selected repository's root: the only one when there is one,
 *   else the one picked, else an empty string;
 * - `selected`, the root of the checkout the pane reads: the worktree picked
 *   for `repo`, else its main worktree;
 * - `select(root)`, which selects a repository;
 * - `selectWorktree(root)`, which picks one of `repo`'s worktrees.
 *
 * The answer is the same object until one of those changes. Loading clears
 * the selection; when `folder` is inside a linked worktree,
 * its repository and that worktree are selected.
 *
 * @param rest The backend call the client is connected to.
 * @param {string} folder The session's folder.
 * @param {number} retried How many times `repos` has been asked for again.
 */
export function useCheckout(rest, folder, retried) {
  const [repos, setRepos] = useState(LOADING);
  const [picked, setPicked] = useState('');
  const [picks, setPicks] = useState({});
  useEffect(askRepos(folder, setRepos, setPicked, setPicks), [rest, folder, retried]);
  const found = dataOr(repos, { repos: [] }).repos;
  const repo = found.length === 1 ? found[0].root : picked;
  const selected = checkoutOf(repositoryAt(found, repo), picks);
  const selectWorktree = useCallback((root) => setPicks((before) => ({ ...before, [repo]: root })), [repo]);
  return useMemo(() => ({ repos, repo, selected, select: setPicked, selectWorktree }), [repos, repo, selected, selectWorktree]);
}

/**
 * Loads `repos` from GET /repos for the folder, and clears the selection;
 * when the folder is inside a linked worktree, selects its repository and
 * that worktree. An answer that arrives after the folder changes is dropped.
 *
 * @effect
 * @param folder The session's folder.
 * @param setRepos Stores the answer.
 * @param setPicked Sets the selected repository.
 * @param setPicks Sets the worktree picked for each repository.
 */
function askRepos(folder, setRepos, setPicked, setPicks) {
  return () => {
    let open = true;
    setPicked('');
    setPicks({});
    setRepos(LOADING);
    client.repos(folder).then((result) => open && arrived(result, setRepos, setPicked, setPicks));
    return () => { open = false; };
  };
}

/**
 * Stores GET /repos's result, and selects the worktree the folder is in when it names one.
 *
 * @param result GET /repos's result.
 * @param setRepos Stores the answer.
 * @param setPicked Sets the selected repository.
 * @param setPicks Sets the worktree picked for each repository.
 */
function arrived(result, setRepos, setPicked, setPicks) {
  setRepos(remoteOf(result));
  const holding = result.ok && result.data.checkout ? repositoryHolding(result.data.repos, result.data.checkout) : undefined;
  if (holding) {
    setPicked(holding.root);
    setPicks({ [holding.root]: result.data.checkout });
  }
}
