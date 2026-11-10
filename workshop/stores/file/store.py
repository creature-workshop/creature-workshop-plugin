"""The file store: fills the Store contract for a shellops document under .ops/config/.

The document is one record, `document`; it cannot be created or deleted, since
shellops owns the file. A write rewrites only the changed key's lines, parses
the new text, and writes nothing unless the key reads back as the change
says. The revision is the sha256 of the file's bytes.
"""

from workshop.project.yaml_loader import load_yaml
from workshop.stores.contract import Store
from workshop.stores.file.checks import check_change
from workshop.stores.file.lines import changed_lines
from workshop.stores.file.location import RECORD_ID, document_path
from workshop.stores.file.schema import schema_for
from workshop.stores.outcomes import NotFound, Refused, Stale, StoreFailure, Unchanged
from workshop.stores.revision import revision_of

ABSENT = object()


class FileStore(Store):
  """A shellops document under .ops/config/ as one record, described by the project's pinned shellops schema."""

  def describe(self, root, source):
    """The project's schema for source, {} when there is none."""

    document_path(root, source)
    return schema_for(root, source)

  def list(self, root, source):
    """The one record: the document."""

    return [self.read(root, source, RECORD_ID)]

  def read(self, root, source, record_id, revision=None):
    """The document as a record; raises outcomes.Unchanged when revision is its current revision."""

    record = record_at(root, source, record_id)
    if revision and revision == record["revision"]:
      raise Unchanged("Nothing changed since that revision.", revision=revision)

    return record

  def write(self, root, source, record_id, change, revision):
    """Applies change to the document made at revision, and answers the document after it."""

    current = record_at(root, source, record_id)
    if revision != current["revision"]:
      raise Stale("The document changed since it was read.", record=current)

    schema = schema_for(root, source)
    check_change(schema, change)
    path = document_path(root, source)
    text = "".join(changed_lines(path.read_text().splitlines(keepends=True), change, list(schema.get("properties", {}))))
    check_reads_back(text, change)
    path.write_text(text)
    return record_at(root, source, record_id)


def record_at(root, source, record_id):
  """The document as a record; raises outcomes.NotFound for another id or a missing file, and StoreFailure when it does not parse."""

  path = document_path(root, source)
  if record_id != RECORD_ID:
    raise NotFound(f"The file store holds one record, {RECORD_ID}, not {record_id}.")

  if not path.is_file():
    raise NotFound(f"The project has no .ops/{source}.")

  data = path.read_bytes()
  return {"id": RECORD_ID, "revision": revision_of(data), "values": values_in(data.decode(), source)}


def values_in(text, source):
  """The mapping in text; {} for an empty file. Raises outcomes.StoreFailure when it does not parse to a mapping."""

  try:
    loaded = load_yaml(text)
  except ImportError:
    raise
  except Exception as error:
    raise StoreFailure(f".ops/{source} does not parse: {error}") from error

  if loaded is None:
    return {}

  if not isinstance(loaded, dict):
    raise StoreFailure(f".ops/{source} does not hold a mapping of keys to values.")

  return loaded


def check_reads_back(text, change):
  """Raises outcomes.Refused unless text parses with change.key as the change says: absent, null, or the value."""

  try:
    loaded = load_yaml(text) or {}
  except ImportError:
    raise
  except Exception as error:
    raise Refused(f"The document would not parse after the change: {error}") from error

  expected = {"reset": ABSENT, "clear": None}.get(change.op, change.value)
  read = loaded.get(change.key, ABSENT) if isinstance(loaded, dict) else ABSENT
  if read is not expected and read != expected:
    raise Refused(f"The document would not read {change.key} back as written, so it was not written.")
