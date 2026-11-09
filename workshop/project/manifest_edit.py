"""Changes one field of a project's .ops/config/manifest.yaml in place.

Only the lines of the key being changed are rewritten, so comments, the order
of the keys and every other field stay as the user wrote them. The new file
is parsed before it is written, and nothing is written unless the field reads
back with the new value.

    set_field(root, "description", "Records every working session.")
"""

import json

from workshop.project.declaration import load_yaml

REQUIRED_FIELDS = ("name", "description", "org", "repo")
OPTIONAL_FIELDS = ("command-name",)
EDITABLE_FIELDS = REQUIRED_FIELDS + OPTIONAL_FIELDS


class ManifestEditError(ValueError):
  """Raised when a field cannot be changed; the message says why, for the user."""


def set_field(root, key, value):
  """Sets key to value in the project's manifest, or removes an optional key when value is empty."""

  check_change(key, value)
  path = root / ".ops" / "config" / "manifest.yaml"
  if not path.is_file():
    raise ManifestEditError("The project has no .ops/config/manifest.yaml to change.")

  text = "".join(changed_lines(path.read_text().splitlines(keepends=True), key, value))
  check_reads_back(text, key, value)
  path.write_text(text)


def check_change(key, value):
  """Raises when key is not a field the pane edits, when value has a line break, or when a required field would be emptied."""

  if key not in EDITABLE_FIELDS:
    raise ManifestEditError(f"{key} is not a field the pane can change. It can change {', '.join(EDITABLE_FIELDS)}.")

  if "\n" in value:
    raise ManifestEditError(f"{key} must be one line.")

  if key in REQUIRED_FIELDS and not value.strip():
    raise ManifestEditError(f"{key} cannot be empty: the manifest requires it.")


def changed_lines(lines, key, value):
  """The manifest's lines with key's entry replaced, removed when value is empty, or added when key was missing."""

  span = entry_span(lines, key)
  entry = [] if not value else [f"{key}: {scalar(value)}\n"]
  if span is None:
    return with_entry_added(lines, entry)

  start, end = span
  return lines[:start] + entry + lines[end:]


def entry_span(lines, key):
  """(start, end) of key's top-level entry: its own line and the indented lines that continue its value; None when absent."""

  starts = [at for at, line in enumerate(lines) if line.startswith(f"{key}:")]
  if not starts:
    return None

  start = starts[0]
  end = start + 1
  while end < len(lines) and lines[end][:1] in (" ", "\t"):
    end += 1

  return start, end


def with_entry_added(lines, entry):
  """The lines with entry inserted after the last edited field present, or appended at the end."""

  present = [at for at, line in enumerate(lines) if line.split(":", 1)[0] in EDITABLE_FIELDS]
  if present:
    after = entry_span(lines, lines[present[-1]].split(":", 1)[0])[1]
    return lines[:after] + entry + lines[after:]

  ended = lines[:-1] + [lines[-1] if lines[-1].endswith("\n") else lines[-1] + "\n"] if lines else []
  return ended + entry


def scalar(value):
  """value as a YAML scalar: written plainly when it reads back the same, else as a double-quoted string."""

  try:
    plain = load_yaml(f"key: {value}\n")
  except ImportError:
    raise
  except Exception:
    plain = None

  if isinstance(plain, dict) and plain.get("key") == value:
    return value

  return json.dumps(value, ensure_ascii=False)


def check_reads_back(text, key, value):
  """Raises unless text parses to a mapping whose key is value, or lacks key when value is empty."""

  try:
    loaded = load_yaml(text)
  except ImportError:
    raise
  except Exception as error:
    raise ManifestEditError(f"The manifest would not parse after the change: {error}") from error

  read = loaded.get(key, "") if isinstance(loaded, dict) else None
  if read != value:
    raise ManifestEditError(f"The manifest would read {key} as {read!r} after the change, so it was not written.")
