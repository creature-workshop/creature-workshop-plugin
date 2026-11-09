"""The answer of GET /about: what the plugin itself is."""

from pydantic import BaseModel


class About(BaseModel):
  """The plugin itself: `release.latest` of its lock, and the branch of the checkout it runs from."""

  version: str
  branch: str
