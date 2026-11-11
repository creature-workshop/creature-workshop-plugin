"""Per-project consent: a project must be approved before the plugin runs
shell commands in it.

Only the user approves a project, and in one way: they add the project's
root to the approved_projects setting, which is empty until they fill it.
The agent has no way to approve one. No tool and no route takes an approval,
and what the agent reads about an unapproved project tells it to ask the
user and not to change the setting.

Every path that leads to ops.run checks consent first: the tool handlers, the
guard hook, and the dashboard backend. The pane and the system prompt section
read the declaration without running anything, so they do not need consent.
"""

from pathlib import Path

from . import settings


def is_approved(root):
  """Whether the user has approved running shell commands in this project: the
  approved_projects setting lists its root."""

  return resolved(root) in listed_projects(settings.value("approved_projects"))


def listed_projects(setting):
  """The project roots the approved_projects setting lists, each as an absolute
  path with no links or `..` in it. An entry that is not text is left out, and
  so is everything when the setting is not a list.

    listed_projects(["~/code/demo/", 7])  ->  frozenset({"/home/someone/code/demo"})
  """

  if not isinstance(setting, list):
    return frozenset()

  return frozenset(resolved(entry) for entry in setting if isinstance(entry, str) and entry.strip())


def resolved(root):
  """A project's root as the setting and a caller are compared: absolute, with no links or `..` in it.

    resolved("~/code/demo/")  ->  "/home/someone/code/demo"
  """

  return str(Path(root).expanduser().resolve())


def require_consent(root):
  """None when the project is approved, else an error message for the agent."""

  if is_approved(root):
    return None

  return (
    f"The workshop at {root} has not been approved for execution, so nothing was run. "
    f"Only the user can approve it: they add {root} to the approved_projects setting of the "
    f"creature-workshop plugin, under Settings → Plugins in Hermes Desktop or under "
    f"plugins.entries.creature-workshop.settings in Hermes's configuration. "
    f"Tell the user this, and do not change that setting yourself."
  )
