"""The answers of GET /project/adoption, GET /project/adoption/guess and POST
/project/adopt: what the pane suggests for a branch's first declaration,
what the agent guesses for it, and what adopting it did."""

from pydantic import BaseModel, Field


class AdoptionSuggestions(BaseModel):
  """What the adoption form starts with for a checkout: its folder's name as the name, the repository from its origin remote ("" when unknown), and its branch ("" when detached)."""

  root: str
  name: str
  repo: str
  branch: str


class AdoptionGuess(BaseModel):
  """The agent's guesses for the adoption form, read from the checkout's files: `found` is false when there was no model to ask or the call failed, and the values are then empty."""

  root: str
  found: bool
  description: str = ""
  command: str = ""


class Manifest(BaseModel):
  """The values of a new .ops/config/manifest.yaml, as the user gave them."""

  name: str
  description: str
  command_name: str = Field(alias="command-name")
  org: str
  repo: str

  model_config = {"populate_by_name": True}


class AdoptBody(BaseModel):
  """The body of POST /project/adopt: the checkout, its manifest, and whether to commit it."""

  root: str
  manifest: Manifest
  commit: bool = False


class Adopted(BaseModel):
  """What POST /project/adopt did: the path it wrote, whether it committed it, and the checkout's setup state after."""

  root: str
  path: str
  committed: bool
  state: str
