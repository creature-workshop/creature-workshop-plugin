"""The routes about the git repositories a folder holds, for the pane's header.

GET /repos?path=<dir>&session=<id> answers with a workshop.models.repos.Repos,
the repositories a session's folder holds, sorted by root, each with its
worktrees, so several worktrees of one repository are one entry, and which
of them the session is on, as workshop.selection decides it. It carries
`refresh_seconds`, the pane_refresh_seconds setting, so the pane reads their
state again on that interval. GET /repos/status?root=<dir> answers with a RepoStatus, the state
of one repository the way a shell prompt shows it, with `ok` false when git
cannot read it.
"""

import asyncio
import os

from fastapi import Query

from workshop import api, settings
from workshop.models.repos import Repo, Repos, RepoStatus
from workshop.repos.grouping import repositories_of
from workshop.repos.status import status_of
from workshop.selection.state import state


@api.register("/repos", Repos)
async def repos(path: str = Query(default=""), session: str = Query(default="")):
  """The repositories the folder at path holds, the server's working folder when
  path is empty, and the repository and the checkout the session is on."""

  start = path or os.getcwd()
  inside, checkout, found = await asyncio.to_thread(repositories_of, start)
  now = await asyncio.to_thread(state, session, start)
  return Repos(
    start=start,
    inside=inside,
    checkout=checkout,
    repository=now.repository,
    selected=now.checkout,
    repos=[Repo(**each) for each in found],
    refresh_seconds=settings.value("pane_refresh_seconds"),
  )


@api.register("/repos/status", RepoStatus)
async def repo_status(root: str = Query()):
  """The prompt-style state of the repository at root, with ok false when git cannot read it."""

  state = await asyncio.to_thread(status_of, root)
  return RepoStatus(root=root, ok=state is not None, **(state or {}))
