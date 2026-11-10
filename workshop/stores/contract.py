"""The contract every store fills, and the change a write makes.

    store.read(root, "config/manifest.yaml", "document")
      ->  {"id": "document", "revision": "9f2c...", "values": {"name": "Notes", ...}}

A change is one of three operations on one top-level key, so each key is
untouched (absent), cleared (null) or set (any value, including false, 0 and
an empty string):

- `set`: the key takes `value`.
- `clear`: someone deliberately removed the value; it reads back as null.
- `reset`: the key goes back to untouched, absent from the record.

Every record carries a revision, and a write names the revision it was made
against; a store refuses a write whose revision is not the current one with
outcomes.Stale. Each operation a store does not do raises outcomes.Unsupported.
"""

from dataclasses import dataclass
from typing import Any

from workshop.stores.outcomes import Unsupported

OPERATIONS = ("set", "clear", "reset")


@dataclass(frozen=True)
class Change:
  """One operation on one top-level key: `op` is set, clear or reset, and `value` matters only to set."""

  op: str
  key: str
  value: Any = None


class Store:
  """A source of records described by a JSON Schema. Subclasses answer each operation they do; the rest are unsupported."""

  def describe(self, root, source):
    """The JSON Schema of the records in source, {} when there is none."""

    raise Unsupported("This store does not describe its records.")

  def list(self, root, source):
    """Every record in source."""

    raise Unsupported("This store does not list its records.")

  def read(self, root, source, record_id, revision=None):
    """The record record_id; raises outcomes.Unchanged when revision is its current revision."""

    raise Unsupported("This store does not read records.")

  def write(self, root, source, record_id, change, revision):
    """Applies change to the record made at revision, and answers the record after it."""

    raise Unsupported("This store does not change records.")

  def create(self, root, source, values):
    """A new record holding values."""

    raise Unsupported("This store does not create records.")

  def delete(self, root, source, record_id, revision):
    """Removes the record made at revision."""

    raise Unsupported("This store does not delete records.")
