"""Finding the shellops project a session is in, and reading what it declares.

A shellops project has shell/ops, the dispatcher its init copies in, and a
declaration under .ops/config/. The declaration files are YAML; the lock,
.ops/lock, is JSON written by ops install and the release job. The tools and
the pane read a project through this module and nothing else: which files
it has, what its manifest says, which tools it declares, and what its last
release was.
"""
import json
from pathlib import Path

DECLARATION_FILES = ("manifest.yaml", "tools.yaml", "ecosystems.yaml", "imports.yaml", "lint.yaml")
SEARCH_DEPTH = 3
SKIPPED_DIRECTORY_NAMES = ("node_modules", "target", "dist", "build")


def find_project(start):
  """The shellops project a session at start is in: the nearest one at or above
  start, else the first one below it, else None.

  A session inside a project finds that project. A session above its
  projects, at ~ or a code folder, finds the first project up to three
  levels down, in name order; a session that keeps several there sees one
  until the pane shows them all.

    find_project("/home/me/proj/lib/x")  ->  Path("/home/me/proj")
    find_project("/home/me/code")        ->  Path("/home/me/code/alpha")
  """
  path = Path(start).resolve()
  return project_above(path) or project_below(path)


def is_project(candidate):
  return (candidate / "shell" / "ops").is_file() and (candidate / ".ops" / "config").is_dir()


def project_above(path):
  """The nearest project at or above path, or None."""
  for candidate in (path, *path.parents):
    if is_project(candidate):
      return candidate

  return None


def project_below(path):
  """The first project below path, nearest level first and in name order within a
  level, down to SEARCH_DEPTH levels; None when there is none."""
  level = [path]
  for _ in range(SEARCH_DEPTH):
    children = [child for parent in level for child in subdirectories(parent)]
    for child in children:
      if is_project(child):
        return child

    level = children

  return None


def subdirectories(path):
  """The directories in path worth searching: not hidden, not a build output,
  in name order; none when path cannot be read."""
  try:
    entries = sorted(path.iterdir())
  except OSError:
    return []

  return [entry for entry in entries if entry.is_dir() and not entry.name.startswith(".") and entry.name not in SKIPPED_DIRECTORY_NAMES]


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
  except ImportError:
    raise
  except Exception:
    return {}

  return loaded if isinstance(loaded, dict) else {}


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
  record = lock(root).get("release")
  return record if isinstance(record, dict) else {}


def declared_tools(root):
  """[(channel, tool, version)] for every tool the project's own declaration names."""
  text = declaration(root).get("tools.yaml")
  if not text:
    return []

  try:
    loaded = load_yaml(text) or {}
  except ImportError:
    raise
  except Exception:
    return []

  found = []
  for channel, entries in loaded.items():
    if not isinstance(entries, dict):
      continue

    for tool, entry in entries.items():
      version = entry.get("version", "") if isinstance(entry, dict) else ""
      found.append((channel, tool, str(version)))

  return found


def load_yaml(text):
  """The document in text, parsed by ruamel.yaml inside Hermes, which ships it, and by PyYAML elsewhere.

  Raises ImportError when neither is installed, so a missing parser is an error the
  tools report and never an empty declaration. Both are public packages: the
  catalog asks plugins to keep off Hermes's own modules.
  """
  try:
    from ruamel.yaml import YAML
  except ImportError:
    import yaml

    return yaml.safe_load(text)

  return YAML(typ="safe").load(text)


def summary_line(root):
  """One sentence about the project, for a prompt or a pane header.

    summary_line(root)  ->  'This directory is the shellops project "Recording rig" at /home/me/rig; it declares 2 tools and its latest release is 0.1.0-dev.1.'
  """
  name = manifest(root).get("name") or Path(root).name
  tools = declared_tools(root)
  latest = release(root).get("latest")
  tail = f" and its latest release is {latest}" if latest else ""
  return (f'This directory is the shellops project "{name}" at {root}; '
      f"it declares {len(tools)} tool{'s' if len(tools) != 1 else ''}{tail}.")
