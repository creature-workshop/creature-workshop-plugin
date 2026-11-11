/**
 * @file The client's calls for the checkout a chat session is on:
 * GET /selection, which reads it again after GET /repos first answered it;
 * POST /selection, which picks a repository; and POST /selection/worktree,
 * which picks one worktree. The backend keeps the selection, and the
 * agent's tools read the same one, so the pane never decides it alone.
 */

import * as api from './api.js';

/**
 * The repository and the checkout a subject's session is on, as GET /selection answers.
 */
export const selection = api.register(
  'selection',
  (rest, subject) => rest(`/selection?session=${encodeURIComponent(subject.id)}&path=${encodeURIComponent(subject.folder)}`),
);

/**
 * Picks the repository rooted at a root for a subject's session, as POST
 * /selection answers: the selection after the pick.
 */
export const select = api.register(
  'select',
  (rest, subject, root) => rest('/selection', { method: 'POST', body: { session: subject.id, path: subject.folder, root } }),
);

/**
 * Picks the worktree rooted at a root, and its repository, for a subject's
 * session, as POST /selection/worktree answers: the selection after the pick.
 */
export const selectWorktree = api.register(
  'selectWorktree',
  (rest, subject, root) => rest('/selection/worktree', { method: 'POST', body: { session: subject.id, path: subject.folder, root } }),
);
