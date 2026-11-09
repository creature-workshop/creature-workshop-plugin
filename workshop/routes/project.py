"""GET /project?path=<dir>: the shellops project at or above a folder, and
POST /project/manifest, which changes one field of its manifest.

The answer is a workshop.models.project.Project: its declaration files, what
its manifest says it is, its release record, the tools it declares and, when `check` is not "0", the
toolchain as `ops install --check` reports it right now. Running the check
costs a few seconds, which is why the pane asks for it on its own timer and
not on every render. Outside a project the answer is a NoProject. Every
answer carries `refresh_seconds`, the pane_refresh_seconds setting, so the
pane schedules that timer from the setting without reading configuration
itself.

POST /project/manifest takes a ManifestChange and answers the project as it
reads after the change, without the toolchain. A change the manifest cannot
take, or a root that is not a project's root, answers HTTP 400 with the
reason as its detail.
"""

import asyncio
import os

from pathlib import Path

from fastapi import HTTPException, Query

from workshop import api, settings
from workshop.models.project import DeclaredTool, ManifestChange, ManifestFields, NoProject, Project, Release
from workshop.models.toolchain import Toolchain
from workshop.project import check_table
from workshop.project.declaration import declaration, declared_tools, find_project, manifest, manifest_fields, release, summary_line
from workshop.project.manifest_edit import ManifestEditError, set_field
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

  if check != "0":
    answer.toolchain = await asyncio.to_thread(toolchain, root)

  return answer


@api.register("/project/manifest", Project, method="POST")
async def change_manifest(change: ManifestChange):
  """Sets one field in the manifest of the project rooted at change.root, and answers the project."""

  root = Path(change.root).resolve()
  if find_project(root) != root:
    raise HTTPException(status_code=400, detail=f"{change.root} is not the root of a shellops project.")

  try:
    set_field(root, change.key, change.value)
  except ManifestEditError as error:
    raise HTTPException(status_code=400, detail=str(error)) from error

  return described(root, settings.value("pane_refresh_seconds"))


def described(root, refresh_seconds):
  """The Project answer for root, without the toolchain."""

  return Project(
    root=str(root),
    name=manifest(root).get("name") or root.name,
    summary=summary_line(root),
    declaration=declaration(root),
    manifest=ManifestFields(**manifest_fields(root)),
    release=Release(**release(root)),
    declared=[DeclaredTool(channel=c, tool=t, version=v) for c, t, v in declared_tools(root)],
    refresh_seconds=refresh_seconds,
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
