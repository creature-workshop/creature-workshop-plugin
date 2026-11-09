"""The answers of GET /repos and GET /repos/status: the repositories a session holds, and the state of one."""

from pydantic import BaseModel


class Repo(BaseModel):
  """One repository: its root, and the name the header shows, the root's folder name."""

  root: str
  name: str


class Repos(BaseModel):
  """The repositories a session's directory holds; `inside` is true when the directory is inside the one listed."""

  start: str
  inside: bool
  repos: list[Repo]
  refresh_seconds: int


class RepoStatus(BaseModel):
  """The state of one repository, as a shell prompt shows it. `ok` is false when git could not read it."""

  root: str
  ok: bool
  branch: str = ""
  detached: bool = False
  upstream: bool = False
  ahead: int = 0
  behind: int = 0
  staged: int = 0
  modified: int = 0
  untracked: int = 0
  conflicted: int = 0
