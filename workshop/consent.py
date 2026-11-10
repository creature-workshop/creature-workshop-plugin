"""Per-project consent: a project must be approved before the plugin runs
shell commands in it.

The user approves a project once, and the approval is stored in a JSON file
under the plugin's data directory. Every path that leads to ops.run checks
consent first: the tool handlers, the guard hook, and the dashboard backend.
The pane and the system prompt section read the declaration without running
anything, so they do not need consent.
"""

import json
import logging
from pathlib import Path

log = logging.getLogger("creature-workshop")

CONSENT_FILE = "approved-projects.json"


def is_approved(root):
  """Whether the user has approved running shell commands in this project."""

  return str(root) in _approved_set()


def approve(root):
  """Records the user's approval for a project. Returns True when the
  project was not already approved, False when it was."""

  key = str(root)
  approved = _approved_set()
  if key in approved:
    return False

  approved.add(key)
  _save(approved)
  log.info("Approved project %s", key)
  return True


def revoke(root):
  """Removes the user's approval for a project."""

  key = str(root)
  approved = _approved_set()
  if key not in approved:
    return False

  approved.discard(key)
  _save(approved)
  log.info("Revoked approval for project %s", key)
  return True


def approved_projects():
  """The set of approved project roots, as strings."""

  return _approved_set()


def require_consent(root):
  """None when the project is approved, else an error message for the agent."""

  if is_approved(root):
    return None

  return (
    f"The shellops project at {root} has not been approved for execution. "
    f"The creature-workshop plugin needs the user's consent before it runs "
    f"shell commands in a project. Ask the user to approve it, then call "
    f"workshop_install with approve: true and path: \"{root}\"."
  )


def _data_dir():
  """The plugin's data directory, which Hermes provides."""

  try:
    from hermes_cli.plugins import plugin_data_dir

    return Path(plugin_data_dir("creature-workshop"))
  except ImportError:
    return Path.home() / ".hermes" / "plugin-data" / "creature-workshop"


def _consent_path():
  """The path of the file that lists the approved project roots."""
  return _data_dir() / CONSENT_FILE


def _approved_set():
  """The set of approved project roots from disk."""

  path = _consent_path()
  if not path.is_file():
    return set()

  try:
    data = json.loads(path.read_text())
    if isinstance(data, list):
      return set(data)
  except (ValueError, OSError):
    pass

  return set()


def _save(approved):
  """Writes the approved set to disk."""

  path = _consent_path()
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(json.dumps(sorted(approved), indent=2) + "\n")
