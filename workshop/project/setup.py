"""Whether a checkout is set up for shellops, read from its files alone.

Setup has two halves. Adopting a repository commits its declaration under
.ops/config/, so every checkout of a branch that has it shares it. Setting up
a checkout (what .ops/boot does on a fresh clone: fetch the shell/.ops
submodule, then run its init) copies the ops dispatcher to shell/ops, which
git ignores, so each worktree is set up on its own. Nothing here runs a
command.
"""

from pathlib import Path

NO_WORKSHOP = "no-workshop"
NOT_SET_UP = "not-set-up"
READY = "ready"


def setup_state(root):
  """How far the checkout at root is set up: no-workshop when its branch has
  no .ops/config, not-set-up when it has one but no shell/ops, else ready.

    setup_state("/code/notes")              ->  "no-workshop"
    setup_state("/code/demo-fresh-clone")   ->  "not-set-up"
    setup_state("/code/demo")               ->  "ready"
  """

  path = Path(root)
  if not adopted(path):
    return NO_WORKSHOP

  if not dispatcher_installed(path):
    return NOT_SET_UP

  return READY


def adopted(path):
  """Whether the checkout's branch has a shellops declaration, the .ops/config folder."""

  return (path / ".ops" / "config").is_dir()


def dispatcher_installed(path):
  """Whether shellops' init has copied its dispatcher into the checkout, at shell/ops."""

  return (path / "shell" / "ops").is_file()
