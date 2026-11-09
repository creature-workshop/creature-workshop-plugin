"""GET /about: the plugin's own version and the branch of the checkout Hermes
loads it from, for the pane's footer, as a workshop.models.about.About.
"""

from pathlib import Path

from workshop import api
from workshop.about import about as read_about
from workshop.models.about import About

PLUGIN_ROOT = Path(__file__).resolve().parents[2]


@api.register("/about", About)
async def about():
  """The plugin's version and the branch of the checkout it was loaded from."""

  return About(**read_about(PLUGIN_ROOT))
