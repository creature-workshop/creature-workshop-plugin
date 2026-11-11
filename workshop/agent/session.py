"""What the agent's side of the plugin knows about the session it runs in:
its directory, as Hermes resolves it, and where it stands, which is the
checkout it is on and that checkout's project.

The tools, the terminal hook and the line the agent reads each turn all
find the session's project with `project` or `standing`, which ask
workshop.selection for the session's checkout, as the pane's backend does.
"""

import os
from dataclasses import dataclass
from pathlib import Path

from ..project.declaration import counted, find_project
from ..project.setup import NO_WORKSHOP, NOT_SET_UP, setup_state
from ..selection.state import state

MISSING = {
  NO_WORKSHOP: "The checkout selected for this session, {checkout}, doesn't have a workshop: its branch has no .ops/config.",
  NOT_SET_UP: "The checkout selected for this session, {checkout}, has a workshop that isn't set up yet. To set it up, run .ops/boot in it.",
}


@dataclass(frozen=True)
class Standing:
  """Where a session stands: its folder, the roots of the checkouts the folder
  holds, the checkout the session is on, and the root of that checkout's
  project. `checkout` is None when the session is on none, and `root` is
  None when it is on none or on one whose workshop is missing or not set up."""

  folder: str
  held: tuple
  checkout: Path | None
  root: Path | None


def directory():
  """The directory the session works in: Hermes's configured one, else this process's."""

  try:
    from agent.runtime_cwd import resolve_agent_cwd

    return str(resolve_agent_cwd())
  except Exception:
    return os.getcwd()


def standing(session_id):
  """Where the session with this id stands right now, from one reading of its folder."""

  folder = directory()
  now = state(session_id, folder)
  checkout = Path(now.checkout) if now.checkout else None
  root = find_project(checkout) if checkout else None
  return Standing(folder=folder, held=now.checkouts, checkout=checkout, root=root)


def project(session_id):
  """(root, problem) for the project the session is on. root is None when the
  session is on no checkout, or on one whose workshop is missing or not set
  up, and problem then says which, for the agent to read."""

  stands = standing(session_id)
  if stands.root is None:
    return None, problem_of(stands)

  return stands.root, None


def problem_of(stands):
  """Why a session that stands like this is on no project, and what changes that."""

  if stands.checkout is not None:
    return MISSING[setup_state(stands.checkout)].format(checkout=stands.checkout)

  if not stands.held:
    return (f"No repository is selected for this session: its folder, {stands.folder}, is not inside a git "
        "repository and holds none. The workshop_* tools work on a git repository that has a workshop.")

  return (f"No repository is selected for this session: its folder, {stands.folder}, is not inside a git "
      f"repository. It holds {counted(len(stands.held), 'checkout')} below it, and only the user selects one, "
      "in the Workshop pane.")


def holds_a_workshop(stands):
  """Whether any checkout the session's folder holds has a workshop, set up or not."""

  return any(setup_state(root) != NO_WORKSHOP for root in stands.held)
