"""The answer of GET /project/setup: how far one checkout is set up for shellops."""

from typing import Literal

from pydantic import BaseModel


class Setup(BaseModel):
  """Whether the checkout at `root` has a workshop: `no-workshop` when its branch has no .ops/config, else `ready`."""

  root: str
  state: Literal["no-workshop", "ready"]
