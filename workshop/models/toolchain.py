"""The toolchain as `ops install --check` reports it, inside a Project answer."""

from pydantic import BaseModel


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
