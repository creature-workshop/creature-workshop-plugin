"""Whether a checkout has a workshop, read from its files alone.

A branch is adopted when it commits its declaration under .ops/config/, so
every checkout of that branch has it. shellops itself comes with the plugin
(SHOP-101), so a checkout needs nothing more of its own. Nothing here runs a
command.
"""

from pathlib import Path

NO_WORKSHOP = "no-workshop"
READY = "ready"


def setup_state(root):
  """Whether the checkout at root has a workshop: no-workshop when its branch has no .ops/config, else ready.

    setup_state("/code/notes")  ->  "no-workshop"
    setup_state("/code/demo")   ->  "ready"
  """

  return READY if adopted(Path(root)) else NO_WORKSHOP


def adopted(path):
  """Whether the checkout's branch has a shellops declaration, the .ops/config folder."""

  return (path / ".ops" / "config").is_dir()
