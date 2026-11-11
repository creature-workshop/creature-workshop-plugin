"""The answers of GET /repos and GET /repos/status: the repositories a session holds, with their worktrees, and the state of one."""

from pydantic import BaseModel


class Worktree(BaseModel):
  """One worktree of a repository: its root, its folder's name, its branch ("" when detached), its commit, whether it is the main one and whether it is locked."""

  root: str
  name: str
  branch: str
  head: str
  main: bool
  locked: bool


class Repo(BaseModel):
  """One repository: its root, the main worktree's; the name the header shows; and its worktrees, main first."""

  root: str
  name: str
  worktrees: list[Worktree] = []


class Repos(BaseModel):
  """The repositories a session's directory holds, and what the session is on.
  `inside` is true when the directory is inside the one listed, and
  `checkout` is then the root of the worktree it is in. `repository` is the
  root of the repository the session is on, and `selected` is the root of
  the checkout of it the pane reads; both are empty when it is on none."""

  start: str
  inside: bool
  checkout: str = ""
  repository: str = ""
  selected: str = ""
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
