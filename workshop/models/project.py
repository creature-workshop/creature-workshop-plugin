"""The answers of GET /project: a Project inside a shellops project, a NoProject outside one.

`found` tells the two apart.
"""

from pydantic import BaseModel

from workshop.models.toolchain import Toolchain


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
  approved: bool = False
  toolchain: Toolchain | None = None
