"""The answer of the /selection routes: the repository and the checkout a chat session is on."""

from pydantic import BaseModel


class Selection(BaseModel):
  """What the session is on, for a session and its folder: `repository` is the
  selected repository's root, and `selected` is the root of the checkout the
  pane reads, one of that repository's worktrees. Both are empty when the
  session is on none."""

  session: str
  start: str
  repository: str
  selected: str
  refresh_seconds: int
