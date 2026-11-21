"""The contract every kind of file fills, and the change a write makes.

    files.read(root, "config/manifest.yaml", "document")
      ->  {"id": "document", "revision": "9f2c...", "values": {"name": "Notes", ...}}

A change is one of three operations on one top-level key, so each key is
untouched (absent), cleared (null) or set (any value, including false, 0 and
an empty string):

- `set`: the key takes `value`.
- `clear`: someone deliberately removed the value; it reads back as null.
- `reset`: the key goes back to untouched, absent from the record.

Every record carries a revision, and a write names the revision it was made
against; a kind refuses a write whose revision is not the current one with
outcomes.Stale. Each operation a kind does not do raises outcomes.Unsupported.
"""

from dataclasses import dataclass
from typing import Any

from workshop.files.outcomes import Unsupported

OPERATIONS = ("set", "clear", "reset")


@dataclass(frozen=True)
class Change:
  """One operation on one top-level key: `op` is set, clear or reset, and `value` matters only to set."""

  op: str
  key: str
  value: Any = None


class Files:
  """The files of one kind, each read as records described by a JSON Schema. Subclasses answer each operation they do; the rest are unsupported."""

  def describe(self, root, source):
    """The JSON Schema of the records in source, {} when there is none."""

    raise Unsupported("A file of this kind has no schema.")

  def list(self, root, source):
    """Every record in source."""

    raise Unsupported("The records of a file of this kind cannot be listed.")

  def read(self, root, source, record_id, revision=None):
    """The record record_id; raises outcomes.Unchanged when revision is its current revision."""

    raise Unsupported("A record of a file of this kind cannot be read.")

  def write(self, root, source, record_id, change, revision):
    """Applies change to the record made at revision, and answers the record after it."""

    raise Unsupported("A record of a file of this kind cannot be changed.")

  def create(self, root, source, values):
    """A new record holding values."""

    raise Unsupported("A record cannot be added to a file of this kind.")

  def delete(self, root, source, record_id, revision):
    """Removes the record made at revision."""

    raise Unsupported("A record cannot be deleted from a file of this kind.")
