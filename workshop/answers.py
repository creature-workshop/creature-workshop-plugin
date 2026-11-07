"""What the pane's backend answers with, as models the pane and the tests can hold it to.

GET /project answers with a Project when the directory is in a shellops
project and with a NoProject otherwise; `found` tells the two apart. The
field names are the ones the pane reads, so a change here is a change to
the pane.
"""

from pydantic import BaseModel


class NoProject(BaseModel):
  """The answer outside any project: where the search started, and the refresh interval."""

  found: bool = False
  start: str
  refresh_seconds: int


class DeclaredTool(BaseModel):
  """One tool of the declaration."""

  channel: str
  tool: str
  version: str


class ToolchainRow(BaseModel):
  """One row of `ops install --check`: the tool and whether it is installed right now."""

  tool: str
  version: str
  channel: str
  installed: bool


class Toolchain(BaseModel):
  """What `ops install --check` reported: its rows, whether it succeeded, its stderr and its duration."""

  ok: bool
  rows: list[ToolchainRow]
  stderr: str
  duration_ms: int


class Release(BaseModel):
  """The release record of the lock; both empty before the first release."""

  latest: str = ""
  stable: str = ""


class Project(BaseModel):
  """The answer inside a project. `toolchain` is None when the check was not asked for."""

  found: bool = True
  root: str
  name: str
  summary: str
  declaration: dict[str, str]
  release: Release
  declared: list[DeclaredTool]
  refresh_seconds: int
  toolchain: Toolchain | None = None
