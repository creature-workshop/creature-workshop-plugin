"""Rewrites one top-level key of a YAML file's lines, leaving every other line as it was.

Comments, the order of the keys and the formatting of every other entry stay
as the user wrote them. A set writes the value, a clear writes null, and a
reset removes the key's lines. A new key goes after the last key present
that the schema lists before it, so a file keeps the schema's order.
"""

import json

from workshop.project.yaml_loader import load_yaml


def changed_lines(lines, change, order):
  """lines with change applied to its key; order is the schema's key order."""

  span = entry_span(lines, change.key)
  entry = entry_for(change)
  if span is None:
    return with_entry_added(lines, entry, preceding(order, change.key))

  start, end = span
  return lines[:start] + entry + lines[end:]


def entry_for(change):
  """The lines change leaves for its key: none for a reset, null for a clear, the value for a set."""

  if change.op == "reset":
    return []

  if change.op == "clear":
    return [f"{change.key}: null\n"]

  return [f"{change.key}: {scalar(change.value)}\n"]


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


def preceding(order, key):
  """The keys order lists before key; every key of order when key is not in it."""

  return order[: order.index(key)] if key in order else list(order)


def with_entry_added(lines, entry, before):
  """lines with entry inserted after the last entry whose key is in before, or appended at the end."""

  if not entry:
    return list(lines)

  present = [at for at, line in enumerate(lines) if line.split(":", 1)[0] in before]
  if present:
    after = entry_span(lines, lines[present[-1]].split(":", 1)[0])[1]
    return lines[:after] + entry + lines[after:]

  return ended(lines) + entry


def ended(lines):
  """lines with a line break after the last one."""

  if not lines or lines[-1].endswith("\n"):
    return list(lines)

  return lines[:-1] + [lines[-1] + "\n"]


def scalar(value):
  """value as a YAML scalar: a string plainly when it reads back the same, else double-quoted; any other value as JSON, which YAML reads the same."""

  if not isinstance(value, str):
    return json.dumps(value)

  try:
    plain = load_yaml(f"key: {value}\n")
  except ImportError:
    raise
  except Exception:
    plain = None

  if isinstance(plain, dict) and plain.get("key") == value:
    return value

  return json.dumps(value, ensure_ascii=False)
