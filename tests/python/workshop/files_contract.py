"""The contract suite every kind passes: mix FilesContract into a
unittest.TestCase and fill in its hooks, and the kind is held to the Files
contract of workshop.files.contract.

    class DocumentFilesContract(FilesContract, unittest.TestCase):
      def make_files(self): ...

The hooks give the kind, a source holding one record, a change the schema
takes and one it refuses, a source the kind does not read, and whether the
kind creates and deletes records.
"""

from workshop.files.contract import Change
from workshop.files.outcomes import NotFound, Refused, Stale, Unchanged, Unsupported


class FilesContract:
  """The cases every kind answers the same way. A subclass sets self.root, self.files and self.source in setUp."""

  creates_records = False

  def accepted_change(self):
    """A change the kind's schema takes for the record."""

    raise NotImplementedError

  def refused_change(self):
    """A change the kind's schema refuses for the record."""

    raise NotImplementedError

  def unread_source(self):
    """A source the kind does not read."""

    raise NotImplementedError

  def first(self):
    """The first record the file lists."""

    return self.files.list(self.root, self.source)[0]

  def test_describes_its_records_with_a_json_schema(self):
    """The kind describes its records with a JSON Schema."""

    self.assertIsInstance(self.files.describe(self.root, self.source), dict)

  def test_a_listed_record_reads_the_same_by_its_id(self):
    """A listed record reads the same by its id, and has an id, a revision and values."""

    record = self.first()
    self.assertEqual(self.files.read(self.root, self.source, record["id"]), record)
    self.assertEqual(set(record), {"id", "revision", "values"})

  def test_a_read_at_the_current_revision_is_unchanged(self):
    """A read that names the current revision answers unchanged."""

    record = self.first()
    with self.assertRaises(Unchanged):
      self.files.read(self.root, self.source, record["id"], record["revision"])

  def test_a_write_at_the_current_revision_answers_the_record_after_it_with_a_new_revision(self):
    """A write at the current revision answers the record after it, with a new revision."""

    record = self.first()
    change = self.accepted_change()
    after = self.files.write(self.root, self.source, record["id"], change, record["revision"])
    self.assertEqual(after["values"][change.key], change.value)
    self.assertNotEqual(after["revision"], record["revision"])

  def test_a_write_at_an_old_revision_is_stale_carries_the_current_record_and_changes_nothing(self):
    """A write at an old revision is stale, carries the current record, and changes nothing."""

    record = self.first()
    change = self.accepted_change()
    current = self.files.write(self.root, self.source, record["id"], change, record["revision"])
    with self.assertRaises(Stale) as raised:
      self.files.write(self.root, self.source, record["id"], Change("reset", change.key), record["revision"])

    self.assertEqual(raised.exception.carried["record"], current)
    self.assertEqual(self.first(), current)

  def test_a_refused_change_changes_nothing(self):
    """A change the schema refuses leaves the record as it was."""

    record = self.first()
    with self.assertRaises(Refused):
      self.files.write(self.root, self.source, record["id"], self.refused_change(), record["revision"])

    self.assertEqual(self.first(), record)

  def test_a_source_it_does_not_read_is_refused(self):
    """A source the kind does not read is refused."""

    with self.assertRaises(Refused):
      self.files.list(self.root, self.unread_source())

  def test_an_unknown_record_is_not_found(self):
    """An id the file does not hold is not found."""

    with self.assertRaises(NotFound):
      self.files.read(self.root, self.source, "no-such-record")

  def test_creating_and_deleting_are_done_or_unsupported(self):
    """A kind that does not create records refuses create and delete as unsupported."""

    if self.creates_records:
      return

    record = self.first()
    with self.assertRaises(Unsupported):
      self.files.create(self.root, self.source, {})

    with self.assertRaises(Unsupported):
      self.files.delete(self.root, self.source, record["id"], record["revision"])
