"""Picking what a chat session is on: a repository, or one worktree of one.

The user picks in the pane's selectors, which go through the two functions
here; the agent has no tool that picks. A pick is only made for something
the session's folder holds a checkout of, and every open pane is told when
one is made, so that its selectors follow.
"""

from ..settings import PLUGIN_ID
from . import picks
from .state import checkout_roots, checkouts, holds, repository_at, resolved, state

CHANGED_EVENT = "selection.changed"


class NotSelectable(ValueError):
  """A pick that cannot be made; its message says why, for the user or the agent to read."""


def select_repository(session_id, folder, root):
  """Picks the repository rooted at root for the session, tells every open pane,
  and returns the Selection after the pick. The checkout is then the worktree
  last picked for that repository, or the one the rule gives. Raises
  NotSelectable when there is no session to pick for, or when root is not
  the root of a repository the folder holds a checkout of."""

  wanted = wanted_root(session_id, root)
  repository = repository_at(wanted)
  if repository["root"] != wanted or not holds(checkouts(folder)[1], repository):
    raise NotSelectable(f"{root} is not the root of a repository that the session's folder, {folder}, holds.")

  picks.keep(session_id, picks.REPOSITORY, wanted)
  announce(session_id)
  return state(session_id, folder)


def select_worktree(session_id, folder, root):
  """Picks the worktree rooted at root, and the repository it belongs to, for the
  session, tells every open pane, and returns the Selection after the pick.
  Raises NotSelectable when there is no session to pick for, or when root is
  not a worktree of a repository the folder holds a checkout of."""

  wanted = wanted_root(session_id, root)
  repository = repository_at(wanted)
  if wanted not in checkout_roots(repository) or not holds(checkouts(folder)[1], repository):
    raise NotSelectable(f"{root} is not a worktree of a repository that the session's folder, {folder}, holds.")

  picks.keep(session_id, picks.worktree_kind(repository["root"]), wanted)
  picks.keep(session_id, picks.REPOSITORY, repository["root"])
  announce(session_id)
  return state(session_id, folder)


def wanted_root(session_id, root):
  """The root a pick names, as git names it, for a pick that can be made at all.
  Raises NotSelectable without a session or without a root."""

  if not session_id:
    raise NotSelectable("There is no chat session to select a repository for.")

  if not root:
    raise NotSelectable("No repository or worktree was named.")

  return resolved(root)


def announce(session_id):
  """Tells every open pane that the session's selection changed, so that its
  selectors follow. Outside Hermes, as in the tests, no pane is listening."""

  try:
    from hermes_cli.plugin_events import broadcast_plugin_event
  except ImportError:
    return

  broadcast_plugin_event(PLUGIN_ID, CHANGED_EVENT, {"session": session_id})
