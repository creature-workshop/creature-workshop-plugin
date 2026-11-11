"""GET /project?path=<dir>: the shellops project at or above a folder.

The answer is a workshop.models.project.Project: its declaration files, its
release record, the tools it declares and, when `check` is not "0", the
toolchain as `ops install --check` reports it right now. Running the check
costs a few seconds, which is why the pane asks for it on its own timer and
not on every render. Outside a project the answer is a NoProject. Every
answer carries `refresh_seconds`, the pane_refresh_seconds setting, so the
pane schedules that timer from the setting without reading configuration
itself.

GET /project/setup?root=<dir> answers with a workshop.models.setup.Setup:
how far the checkout at root itself is set up, read from its files without
searching above or below it, so the pane can say what is missing there.

GET /project/adoption?root=<dir> answers with what the adoption form
starts with for a checkout whose branch has no workshop, from its folder
and its remote; GET /project/adoption/guess?root=<dir> with the agent's
guesses for its description and command, which take a model call; and POST
/project/adopt writes that branch's .ops/config/manifest.yaml from the
form's values, committing it on its own when asked; it refuses a checkout
that already has .ops/config.

The pane reads and changes the project's files, such as its manifest,
through the /store routes.
"""

import asyncio
import os
from pathlib import Path

from fastapi import HTTPException, Query
from pydantic import BaseModel

from workshop import api, settings
from workshop.consent import approve as approve_project, is_approved
from workshop.models.adoption import AdoptBody, Adopted, AdoptionGuess, AdoptionSuggestions
from workshop.models.project import DeclaredTool, NoProject, Project, Release
from workshop.models.setup import Setup
from workshop.models.toolchain import Toolchain
from workshop.project import check_table
from workshop.project.adoption import MANIFEST_PATH, commit_manifest, suggestions, write_manifest
from workshop.project.declaration import declaration, declared_tools, find_project, manifest, release, summary_line
from workshop.project.guess import guess
from workshop.project.setup import NO_WORKSHOP, setup_state
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


@api.register("/project/setup", Setup)
async def setup(root: str = Query()):
  """How far the checkout at root is set up for shellops."""

  return Setup(root=root, state=setup_state(root))


@api.register("/project/adoption", AdoptionSuggestions)
async def adoption(root: str = Query()):
  """What the adoption form starts with for the checkout at root."""

  return AdoptionSuggestions(root=root, **await asyncio.to_thread(suggestions, root))


@api.register("/project/adoption/guess", AdoptionGuess)
async def adoption_guess(root: str = Query()):
  """The agent's guesses for the checkout's description and command, with found false when there are none."""

  guessed = await guess(root)
  if guessed is None:
    return AdoptionGuess(root=root, found=False)

  return AdoptionGuess(root=root, found=True, **guessed)


@api.register("/project/adopt", Adopted, method="POST")
async def adopt(body: AdoptBody):
  """Writes the checkout's .ops/config/manifest.yaml from body.manifest and commits it alone when body.commit is set, refusing a checkout whose branch already has a workshop."""

  if setup_state(body.root) != NO_WORKSHOP:
    raise HTTPException(status_code=400, detail=f"{Path(body.root).name} already has a workshop.")

  write_manifest(body.root, body.manifest.model_dump(by_alias=True))
  failure = await asyncio.to_thread(commit_manifest, body.root) if body.commit else ""
  if failure:
    raise HTTPException(status_code=400, detail=f"I wrote {MANIFEST_PATH}, but git didn't commit it: {failure}")

  return Adopted(root=body.root, path=MANIFEST_PATH, committed=body.commit, state=setup_state(body.root))


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
