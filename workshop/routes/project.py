"""GET /project?path=<dir>: the shellops project at or above a folder.

The answer is a workshop.models.project.Project: its declaration files, its
release record, the tools it declares and, when `check` is not "0", the
toolchain as `ops install --check` reports it right now. Running the check
costs a few seconds, which is why the pane asks for it on its own timer and
not on every render. Outside a project the answer is a NoProject. Every
answer carries `refresh_seconds`, the pane_refresh_seconds setting, so the
pane schedules that timer from the setting without reading configuration
itself.

The pane reads and changes the project's files, such as its manifest,
through the /store routes.
"""

import asyncio
import os

from fastapi import Query
from pydantic import BaseModel

from workshop import api, settings
from workshop.consent import approve as approve_project, is_approved
from workshop.models.project import DeclaredTool, NoProject, Project, Release
from workshop.models.toolchain import Toolchain
from workshop.project import check_table
from workshop.project.declaration import declaration, declared_tools, find_project, manifest, release, summary_line
from workshop.run import ops


@api.register("/project", Project | NoProject)
async def project(path: str = Query(default=""), check: str = Query(default="1")):
  """The project at or above path, with its toolchain unless check is "0", or a NoProject outside one."""

  start = path or os.getcwd()
  root = find_project(start)
  refresh_seconds = settings.value("pane_refresh_seconds")
  if root is None:
    return NoProject(start=start, refresh_seconds=refresh_seconds)

  answer = described(root, refresh_seconds)

  if check != "0" and answer.approved:
    answer.toolchain = await asyncio.to_thread(toolchain, root)

  return answer


def described(root, refresh_seconds):
  """The Project answer for root, without the toolchain."""

  return Project(
    root=str(root),
    name=manifest(root).get("name") or root.name,
    summary=summary_line(root),
    declaration=declaration(root),
    release=Release(**release(root)),
    declared=[DeclaredTool(channel=c, tool=t, version=v) for c, t, v in declared_tools(root)],
    refresh_seconds=refresh_seconds,
    approved=is_approved(root),
  )


def toolchain(root):
  """The toolchain as the pane shows it: `shell/ops install --check`, run in the
  project with the ops_timeout_seconds setting as its limit, parsed into one
  row per declared tool, with whether the command succeeded, what it wrote on
  stderr (where shellops logs the table and any error) and how long it took."""

  outcome = ops.run(root, ["install", "--check"], settings.value("ops_timeout_seconds"))
  return Toolchain(
    ok=outcome["ok"],
    rows=check_table.rows(outcome),
    stderr=outcome["stderr"],
    duration_ms=outcome["duration_ms"],
  )


class ApproveBody(BaseModel):
  """The body of POST /project/approve: the project root to approve."""

  root: str


class ApproveAnswer(BaseModel):
  """The answer of POST /project/approve."""

  approved: bool
  root: str


@api.register("/project/approve", ApproveAnswer, method="POST")
async def approve(body: ApproveBody):
  """Approves a project for execution, so the plugin can run shell commands in it."""

  approve_project(body.root)
  return ApproveAnswer(approved=True, root=body.root)
