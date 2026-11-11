"""The JSON Schema of a file store document: the project's own, from its pinned
shell/.ops/schema/, so the pane describes the file as the shellops the
project runs reads it, or else the one in the shellops that comes with the
plugin (SHOP-101), for a checkout with no shellops of its own. References
to other schema files are followed for each top-level property. A document
without a schema answers {}.
"""

import json
from pathlib import Path

from workshop.stores.file.location import stem_of

BUNDLED_SCHEMAS = Path(__file__).resolve().parents[3] / "shell" / ".ops" / "schema"


def schema_for(root, source):
  """The schema of source in the project at root, with each property's file reference resolved; {} when there is none."""

  path = schema_path(root, f"{stem_of(source)}.schema.json")
  if path is None:
    return {}

  schema = json.loads(path.read_text())
  properties = {key: resolved(value, path.parent) for key, value in schema.get("properties", {}).items()}
  return {**schema, "properties": properties}


def schema_path(root, name):
  """The schema file called name: the project's own when it has one, else the plugin's; None when neither has it."""

  for folder in (root / "shell" / ".ops" / "schema", BUNDLED_SCHEMAS):
    if (folder / name).is_file():
      return folder / name

  return None


def resolved(definition, folder):
  """definition, or what its `$ref` to `<file>#/<pointer>` in folder points at; definition itself when the reference cannot be followed."""

  reference = definition.get("$ref", "") if isinstance(definition, dict) else ""
  file_name, _, pointer = reference.partition("#")
  if not file_name or not (folder / file_name).is_file():
    return definition

  target = json.loads((folder / file_name).read_text())
  for part in [part for part in pointer.split("/") if part]:
    target = target.get(part, {}) if isinstance(target, dict) else {}

  return target or definition
