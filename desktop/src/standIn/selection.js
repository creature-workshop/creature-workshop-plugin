/**
 * @file The stand-in's selection: what every stand-in backend does for the
 * checkout a session is on. It keeps each session's picks in memory and
 * answers as workshop/selection/ does. The repository is the one picked
 * while GET /repos lists it, else the one the folder is inside, else none,
 * however many the folder holds below it. Its
 * checkout is the worktree picked for it while it is listed, else the
 * worktree the folder is inside, else the main worktree. It answers the
 * /selection routes, and adds the session's selection to the story's own
 * answer of GET /repos, as the backend does.
 */

import { repositoryAt, worktreesOf } from '../workshop/selection.js';
import * as api from './api.js';

/** The picks of a session nothing was picked for. */
const NO_PICKS = Object.freeze({ repository: '', worktrees: {} });

api.register(routes);

/**
 * The selection's routes for one stand-in, over picks of their own: the
 * /selection routes, and GET /repos with the session's selection added.
 */
export function routes() {
  const picksBySession = new Map();
  return [
    ['/selection', (request, backend) => selection(picksBySession, request, backend)],
    ['/repos?', (request, backend) => reposWithSelection(picksBySession, request, backend)],
  ];
}

/**
 * The repository one of whose worktrees is rooted at `checkout`, or undefined.
 *
 * @param {object[]} repos GET /repos's repositories.
 * @param {string} checkout A worktree's root.
 */
export function repositoryHolding(repos, checkout) {
  return repos.find((repo) => worktreesOf(repo).some((each) => each.root === checkout));
}

/**
 * The root of the selected repository: the picked one while `repos` lists
 * it, else the one the folder is inside, else an empty string.
 *
 *     repositoryOf([demo, site], '/code/site')  ->  "/code/site"
 *     repositoryOf([demo], '', '/code/fix')     ->  "/code/demo"
 *     repositoryOf([demo], '')                  ->  ""
 *
 * @param {object[]} repos GET /repos's repositories.
 * @param {string} pick The root of the repository picked for the session, or an empty string.
 * @param {string} [inside] The root of the worktree the folder is inside, or an empty string.
 */
export function repositoryOf(repos, pick, inside = '') {
  if (repositoryAt(repos, pick)) {
    return pick;
  }
  return (repositoryHolding(repos, inside) ?? repositoryAt(repos, inside))?.root ?? '';
}

/**
 * The root of the checkout a session is on for `repo`: the worktree
 * `picks` names for it while that worktree is still listed, else `inside`
 * when it is one of its worktrees, else its main worktree, else its first,
 * else the repository's own root; "" without a repository.
 *
 *     checkoutOf(demo, {})                           ->  "/code/demo"
 *     checkoutOf(demo, {"/code/demo": "/code/fix"})  ->  "/code/fix"
 *     checkoutOf(demo, {}, "/code/fix")              ->  "/code/fix"
 *
 * @param {object | undefined} repo The selected repository.
 * @param {Record<string, string>} picks The worktree picked for each repository, by its root.
 * @param {string} [inside] The root of the worktree the folder is inside, or an empty string.
 */
export function checkoutOf(repo, picks, inside = '') {
  if (!repo) {
    return '';
  }
  const worktrees = worktreesOf(repo);
  const rooted = (root) => worktrees.find((each) => each.root === root);
  return (rooted(picks[repo.root]) ?? rooted(inside) ?? worktrees.find((each) => each.main) ?? worktrees[0] ?? repo).root;
}

/**
 * The answer of the /selection routes: the session's selection, after the
 * pick when the request makes one.
 *
 * @param picksBySession Each session's picks, by session id.
 * @param request The request, `{path, options}`.
 * @param backend The stand-in, whose `answer` is the story's own backend call.
 */
async function selection(picksBySession, { path, options }, backend) {
  const asked = options?.body ?? askedIn(path);
  const listing = await backend.answer(`/repos?path=${encodeURIComponent(asked.path)}`);
  const before = picksBySession.get(asked.session) ?? NO_PICKS;
  const picks = options?.method === 'POST' ? picked(before, listing.repos, { root: asked.root, worktree: path.startsWith('/selection/worktree') }) : before;
  picksBySession.set(asked.session, picks);
  return { session: asked.session, start: asked.path, ...selectionIn(listing, picks), refresh_seconds: listing.refresh_seconds };
}

/**
 * The story's own answer of GET /repos, with the selection of the session
 * the path names added.
 *
 * @param picksBySession Each session's picks, by session id.
 * @param request The request, `{path, options}`.
 * @param backend The stand-in, whose `answer` is the story's own backend call.
 */
async function reposWithSelection(picksBySession, { path, options }, backend) {
  const listing = await backend.answer(path, options);
  return { ...listing, ...selectionIn(listing, picksBySession.get(askedIn(path).session) ?? NO_PICKS) };
}

/**
 * What a session with these picks is on, among the repositories of a listing.
 *
 * @param listing GET /repos's answer for the folder.
 * @param picks The session's picks: `repository`, and `worktrees` by repository root.
 */
function selectionIn(listing, picks) {
  const repository = repositoryOf(listing.repos, picks.repository, listing.checkout);
  return { repository, selected: checkoutOf(repositoryAt(listing.repos, repository), picks.worktrees, listing.checkout) };
}

/**
 * What a path's query asks about: its session and its folder.
 *
 * @param path The path, with its query.
 */
function askedIn(path) {
  const query = new URLSearchParams(path.split('?')[1]);
  return { session: query.get('session') ?? '', path: query.get('path') ?? '' };
}

/**
 * A session's picks after one more: a repository, or a worktree together
 * with the repository that holds it.
 *
 * @param picks The session's picks: `repository`, and `worktrees` by repository root.
 * @param {object[]} repos GET /repos's repositories.
 * @param pick The pick made.
 * @param {string} pick.root The root picked.
 * @param {boolean} pick.worktree Whether the root is a worktree's, not a repository's.
 */
function picked(picks, repos, { root, worktree }) {
  if (!worktree) {
    return { ...picks, repository: root };
  }
  const holding = repositoryHolding(repos, root)?.root ?? picks.repository;
  return { repository: holding, worktrees: { ...picks.worktrees, [holding]: root } };
}
