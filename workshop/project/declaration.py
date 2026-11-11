"""Finding the shellops project a folder is in, and reading what it declares.

A shellops project has shell/ops, the dispatcher its init copies in, and a
declaration under .ops/config/. The declaration files are YAML; the lock,
.ops/lock, is JSON written by ops install and the release job. The tools and
the pane read a project through this module and nothing else: which files
it has, what its manifest says, which tools it declares, and what its last
release was.
"""

import json
from pathlib import Path

from .setup import READY, setup_state
from .yaml_loader import load_yaml

DECLARATION_FILES = ("manifest.yaml", "tools.yaml", "ecosystems.yaml", "imports.yaml", "lint.yaml")


def find_project(start):
  """The shellops project a folder is in: the nearest one at or above start, or None.

    find_project("/home/me/proj/lib/x")  ->  Path("/home/me/proj")
    find_project("/home/me/code")        ->  None
  """

  return project_above(Path(start).resolve())


def is_project(candidate):
  """Whether a folder is the root of a shellops project: a checkout that is set up, with .ops/config and shell/ops."""

  return setup_state(candidate) == READY


def project_above(path):
  """The nearest project at or above path, or None."""

  for candidate in (path, *path.parents):
    if is_project(candidate):
      return candidate

  return None


def declaration(root):
  """The project's declaration files as text, keyed by file name, for the ones that exist."""

  config = Path(root) / ".ops" / "config"
  return {name: (config / name).read_text() for name in DECLARATION_FILES if (config / name).is_file()}


def manifest(root):
  """The manifest's fields as a mapping, empty when the file is missing or unreadable."""

  text = declaration(root).get("manifest.yaml")
  if not text:
    return {}

  try:
    loaded = load_yaml(text)
  except Exception:
    return {}

  return mapping_or_empty(loaded)


def lock(root):
  """The lock as a mapping, empty when the project has none yet."""

  path = Path(root) / ".ops" / "lock"
  if not path.is_file():
    return {}

  try:
    return json.loads(path.read_text())
  except ValueError:
    return {}


def release(root):
  """The release record the lock carries: {"latest": ..., "stable": ...}, or empty."""

  return mapping_or_empty(lock(root).get("release"))


def mapping_or_empty(value):
  """The value when it is a mapping, else an empty one."""

  if isinstance(value, dict):
    return value

  return {}


def declared_tools(root):
  """[(channel, tool, version)] for every tool the project's own declaration names."""

  text = declaration(root).get("tools.yaml")
  if not text:
    return []

  try:
    loaded = load_yaml(text) or {}
  except Exception:
    return []

  found = []
  for channel, entries in loaded.items():
    if not isinstance(entries, dict):
      continue

    for tool, entry in entries.items():
      found.append((channel, tool, version_of(entry)))

  return found


def version_of(entry):
  """The version a tool's entry declares, as text; empty when the entry is not a mapping."""

  if isinstance(entry, dict):
    return str(entry.get("version", ""))

  return ""


def summary_line(root):
  """One sentence about the project, for a prompt or a pane header.

    summary_line(root)  ->  'This directory is the shellops project "Recording rig" at /home/me/rig; it declares 2 tools and its latest release is 0.1.0-dev.1.'
  """

  name = manifest(root).get("name") or Path(root).name
  tools = declared_tools(root)
  return (f'This directory is the shellops project "{name}" at {root}; '
      f"it declares {counted(len(tools), 'tool')}{release_tail(release(root))}.")


def counted(count, noun):
  """The count with the noun, plural except for one: counted(2, "tool") -> "2 tools"."""

  if count == 1:
    return f"1 {noun}"

  return f"{count} {noun}s"


def release_tail(record):
  """The clause about the latest release for the summary, empty before the first release."""

  latest = record.get("latest")
  if not latest:
    return ""

  return f" and its latest release is {latest}"
