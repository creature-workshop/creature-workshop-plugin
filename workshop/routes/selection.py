"""The routes about the checkout a chat session is on, for the pane's selectors.

GET /repos answers with a session's selection beside its repositories, and
that is where the pane first reads it. GET /selection?session=<id>&path=<dir>
answers with the selection alone, a workshop.models.selection.Selection: the
repository the session is on and the checkout of it the pane reads, as
workshop.selection decides them for the session and its folder, which is
the same answer the agent's tools get. The pane asks for it when the
plugin's `selection.changed` event arrives, which is how its selectors
follow a pick made in another window, and on the interval `refresh_seconds` names,
the pane_refresh_seconds setting.

POST /selection picks the repository rooted at `root` for the session, and
POST /selection/worktree picks the worktree rooted at `root` and the
repository it belongs to. Each answers with the Selection after the pick,
or 400 REFUSED when the session's folder holds no checkout of that
repository, or when there is no session.
"""

import asyncio

from fastapi import HTTPException, Query
from pydantic import BaseModel

from workshop import api, settings
from workshop.models.selection import Selection
from workshop.selection import picking
from workshop.selection.state import state


class SelectBody(BaseModel):
  """The body of the two POST routes: the session, its folder, and the root to pick."""

  session: str
  path: str
  root: str


@api.register("/selection", Selection)
async def selection(session: str = Query(default=""), path: str = Query(default="")):
  """What the session is on, for a session whose folder is path."""

  return answer(session, path, await asyncio.to_thread(state, session, path))


@api.register("/selection", Selection, method="POST")
async def select(body: SelectBody):
  """Picks the repository rooted at the body's root for its session."""

  return await picked(picking.select_repository, body)


@api.register("/selection/worktree", Selection, method="POST")
async def select_worktree(body: SelectBody):
  """Picks the worktree rooted at the body's root, and its repository, for its session."""

  return await picked(picking.select_worktree, body)


async def picked(pick, body):
  """The Selection after pick, one of workshop.selection.picking's two picks, was
  made for the body; a pick that cannot be made answers 400 with its reason."""

  try:
    now = await asyncio.to_thread(pick, body.session, body.path, body.root)
  except picking.NotSelectable as refusal:
    raise HTTPException(status_code=400, detail=str(refusal)) from refusal

  return answer(body.session, body.path, now)


def answer(session, path, now):
  """The Selection model for a session whose folder is path and whose selection is now."""

  return Selection(
    session=session,
    start=path,
    repository=now.repository,
    selected=now.checkout,
    refresh_seconds=settings.value("pane_refresh_seconds"),
  )
