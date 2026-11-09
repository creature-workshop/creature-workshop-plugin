"""The backend the Desktop pane reads, mounted at /api/plugins/creature-workshop/.

GET /project?path=<dir> answers for the shellops project at or above the
directory with a workshop.models.project.Project: its declaration files, its release
record, the tools it declares and, when `check` is not "0", the toolchain as
`ops install --check` reports it right now. Running the check costs a few
seconds, which is why the pane asks for it on its own timer and not on every
render. Outside a project the answer is a NoProject. Every answer carries
`refresh_seconds`, the pane_refresh_seconds setting, so the pane schedules
that timer from the setting without reading configuration itself.

GET /about answers with a workshop.models.about.About: the plugin's own version
and the branch of the checkout Hermes loads it from, for the pane's footer.

Hermes imports this file by its path, not as part of a package, so the
plugin's root is not on sys.path when the file runs. The imports come in
three groups: the standard library, FastAPI, and then, once the root is on
the path, the plugin's own package.
"""

import asyncio
import os
import sys
from pathlib import Path

from fastapi import APIRouter, Query

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
if str(PLUGIN_ROOT) not in sys.path:
  sys.path.insert(0, str(PLUGIN_ROOT))

from workshop import check_table, ops, settings
from workshop.about import about
from workshop.models.about import About
from workshop.models.project import DeclaredTool, NoProject, Project, Release
from workshop.models.toolchain import Toolchain
from workshop.project import declaration, declared_tools, find_project, manifest, release, summary_line

router = APIRouter()


@router.get("/about", response_model=About)
async def plugin_about():
  return About(**about(PLUGIN_ROOT))


@router.get("/project", response_model=Project | NoProject)
async def project(path: str = Query(default=""), check: str = Query(default="1")):
  start = path or os.getcwd()
  root = find_project(start)
  refresh_seconds = settings.value("pane_refresh_seconds")
  if root is None:
    return NoProject(start=start, refresh_seconds=refresh_seconds)

  answer = Project(
    root=str(root),
    name=manifest(root).get("name") or root.name,
    summary=summary_line(root),
    declaration=declaration(root),
    release=Release(**release(root)),
    declared=[DeclaredTool(channel=c, tool=t, version=v) for c, t, v in declared_tools(root)],
    refresh_seconds=refresh_seconds,
  )

  if check != "0":
    answer.toolchain = await asyncio.to_thread(toolchain, root)

  return answer


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
