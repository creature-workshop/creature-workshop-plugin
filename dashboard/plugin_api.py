"""The backend the Desktop pane reads, mounted at /api/plugins/creature-workshop/.

GET /project?path=<dir> answers for the shellops project at or above the
directory: its declaration files, its release record, the tools it declares
and, when `check` is not "0", the toolchain as `ops install --check` reports
it right now. Running the check costs a few seconds, which is why the pane
asks for it on its own timer and not on every render. Every answer, found or
not, carries `refresh_seconds`, the pane_refresh_seconds setting, so the pane
schedules that timer from the setting without reading configuration itself.
"""
import asyncio
import os
import sys
from pathlib import Path

from fastapi import APIRouter, Query

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
if str(PLUGIN_ROOT) not in sys.path:
  sys.path.insert(0, str(PLUGIN_ROOT))

from workshop import ops, settings  # noqa: E402
from workshop.project import declaration, declared_tools, find_project, manifest, release, summary_line  # noqa: E402

router = APIRouter()


@router.get("/project")
async def project(path: str = Query(default=""), check: str = Query(default="1")):
  root = find_project(path or os.getcwd())
  refresh_seconds = settings.value("pane_refresh_seconds")
  if root is None:
    return {"found": False, "start": path or os.getcwd(), "refresh_seconds": refresh_seconds}

  answer = {
    "found": True,
    "root": str(root),
    "name": manifest(root).get("name") or root.name,
    "summary": summary_line(root),
    "declaration": declaration(root),
    "release": release(root),
    "declared": [{"channel": c, "tool": t, "version": v} for c, t, v in declared_tools(root)],
    "refresh_seconds": refresh_seconds,
  }

  if check != "0":
    answer["toolchain"] = await asyncio.to_thread(toolchain_rows, root)

  return answer


def toolchain_rows(root):
  """The install --check table as rows, plus what the command said when it failed."""
  outcome = ops.run(root, ["install", "--check"], settings.value("ops_timeout_seconds"))
  return {"ok": outcome["ok"], "rows": ops.check_table(outcome),
      "stderr": outcome["stderr"], "duration_ms": outcome["duration_ms"]}
