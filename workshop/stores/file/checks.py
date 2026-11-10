"""Whether a document's schema takes a change to one top-level key.

The file store writes single values on one line, so it refuses a list or a
mapping, and a string with a line break. Otherwise the schema decides: the
key must be one it describes, a set value must be of a type the key allows
and in its enum when it has one, a clear needs the null type, and a reset
needs the key not to be required.
"""

from workshop.stores.file.types import allowed_types, types_of
from workshop.stores.outcomes import Refused


def check_change(schema, change):
  """Raises outcomes.Refused, with the reason, unless the schema takes change."""

  definition = schema.get("properties", {}).get(change.key)
  if definition is None:
    raise Refused(f"{change.key} is not a key this document's schema describes.")

  checks = {"set": check_set, "clear": check_clear, "reset": check_reset}
  checks[change.op](schema, definition, change)


def check_set(schema, definition, change):
  """Raises unless the value is one the file store writes and the key's definition allows."""

  check_writable(change.key, change.value)
  check_type(definition, change.key, change.value)
  check_in_enum(definition, change.key, change.value)


def check_clear(schema, definition, change):
  """Raises unless the key's definition allows null, the value a clear writes."""

  allowed = allowed_types(definition)
  if allowed and "null" not in allowed:
    raise Refused(f"{change.key} cannot be cleared: its schema has no empty value for it. Set it to a value instead.")


def check_reset(schema, definition, change):
  """Raises when the schema requires the key, so it cannot go back to untouched."""

  if change.key in schema.get("required", []):
    raise Refused(f"{change.key} cannot be removed: the schema requires it.")


def check_writable(key, value):
  """Raises for a value the file store cannot write on one line: a list, a mapping, or a string with a line break."""

  if types_of(value) & {"array", "object"}:
    raise Refused(f"{key} holds a list or a mapping, and the file store only writes single values.")

  if isinstance(value, str) and "\n" in value:
    raise Refused(f"{key} must be one line.")


def check_type(definition, key, value):
  """Raises when the key's definition names types and value is none of them."""

  allowed = allowed_types(definition)
  if allowed and not allowed & types_of(value):
    raise Refused(f"{key} must be {' or '.join(sorted(allowed))}.")


def check_in_enum(definition, key, value):
  """Raises when the key's definition lists the values it takes and value is not one of them."""

  allowed = definition.get("enum")
  if allowed and value not in allowed:
    raise Refused(f"{key} must be one of {', '.join(str(each) for each in allowed)}.")
