"""The answer of GET /project/dependencies/explain: why a project has one of its declared tools."""

from pydantic import BaseModel


class DependencyExplanation(BaseModel):
  """Why the project at root has the tool, in the words of the model named by `model`: `found` is false when there was no model to ask or the call failed; the explanation and the model are then empty and `reason` says why."""

  root: str
  tool: str
  found: bool
  explanation: str = ""
  reason: str = ""
  model: str = ""
