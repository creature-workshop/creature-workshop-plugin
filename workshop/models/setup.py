"""The answer of GET /project/setup: how far one checkout is set up for shellops."""

from typing import Literal

from pydantic import BaseModel


class Setup(BaseModel):
  """How far the checkout at `root` is set up: `no-workshop` when its branch has no .ops/config, `not-set-up` when the checkout has no shell/ops yet, else `ready`."""

  root: str
  state: Literal["no-workshop", "not-set-up", "ready"]
