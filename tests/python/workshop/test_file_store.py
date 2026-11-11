"""Covers workshop.stores.file: the file store passes the store contract suite,
and a change to recording-rig's manifest (workshop/stores/file/manifest.fixture.yaml,
in a copy of the golden case `installed` with the plugin's pinned shellops
schemas), and to a flags document described by
workshop/stores/file/flags.fixture.schema.json, rewrites only its own line, keeps comments and the other keys,
quotes a value only when it must, keeps untouched, cleared and set apart, and
refuses what the schema does not take without touching the file.
"""

import shutil
import tempfile
import unittest
from pathlib import Path

from tests.python.workshop.store_contract import StoreContract
from workshop.project.yaml_loader import load_yaml
from workshop.stores.contract import Change
from workshop.stores.file.schema import schema_for
from workshop.stores.file.store import FileStore
from workshop.stores.outcomes import NotFound, Refused, StoreFailure

REPOSITORY = Path(__file__).resolve().parents[3]
FIXTURE = REPOSITORY / "workshop" / "stores" / "file" / "manifest.fixture.yaml"
FLAGS_SCHEMA = REPOSITORY / "workshop" / "stores" / "file" / "flags.fixture.schema.json"
INSTALLED = Path(__file__).parent / "goldens" / "cases" / "installed" / "input"
MANIFEST = "config/manifest.yaml"


def project_copy(scratch):
  """A shellops project under scratch with the fixture manifest and the pinned shellops schemas."""

  root = Path(scratch) / "demo"
  shutil.copytree(INSTALLED, root)
  shutil.copytree(REPOSITORY / "shell" / ".ops" / "schema", root / "shell" / ".ops" / "schema")
  shutil.copy(FIXTURE, root / ".ops" / "config" / "manifest.yaml")
  return root


class AProject(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.mkdtemp()
    self.root = project_copy(self.scratch)
    self.store = FileStore()
    self.source = MANIFEST
    self.manifest = self.root / ".ops" / "config" / "manifest.yaml"

  def tearDown(self):
    shutil.rmtree(self.scratch)

  def change(self, op, key, value=None):
    """Applies one change at the current revision and answers the record after it."""

    record = self.store.read(self.root, MANIFEST, "document")
    return self.store.write(self.root, MANIFEST, "document", Change(op, key, value), record["revision"])

  def lines(self):
    """The manifest's lines as they are on disk now."""

    return self.manifest.read_text().splitlines()


class FileStoreContract(StoreContract, AProject):
  def accepted_change(self):
    """Sets the description."""

    return Change("set", "description", "Records sessions from one key.")

  def refused_change(self):
    """Empties the required name by removing it."""

    return Change("reset", "name")

  def unread_source(self):
    """The lock, which is not a config document."""

    return "lock"


class Describing(AProject):
  def test_the_schema_is_the_projects_own_with_references_followed(self):
    schema = schema_for(self.root, MANIFEST)
    self.assertIn("name", schema["required"])
    self.assertEqual(schema["properties"]["command-name"]["type"], "string")
    self.assertEqual(schema["properties"]["default-channel"]["enum"], ["dev", "stable"])

  def test_a_checkout_without_shellops_takes_the_schema_from_the_plugins_shellops(self):
    shutil.rmtree(self.root / "shell")
    schema = schema_for(self.root, MANIFEST)
    self.assertIn("name", schema["required"])
    self.assertEqual(schema["properties"]["command-name"]["type"], "string")

  def test_a_document_without_a_schema_describes_as_empty(self):
    self.assertEqual(self.store.describe(self.root, "config/nothing.yaml"), {})


class Reading(AProject):
  def test_a_missing_document_is_not_found(self):
    with self.assertRaises(NotFound):
      self.store.read(self.root, "config/lint.yaml", "document")

  def test_a_document_that_does_not_parse_is_a_store_failure(self):
    self.manifest.write_text("name: [unclosed\n")
    with self.assertRaises(StoreFailure):
      self.store.read(self.root, MANIFEST, "document")


class Writing(AProject):
  def test_a_set_rewrites_only_its_own_line(self):
    before = self.lines()
    self.change("set", "description", "Records sessions from one key.")
    after = self.lines()
    self.assertEqual(after[2], "description: Records sessions from one key.")
    self.assertEqual(after[:2] + after[3:], before[:2] + before[3:])

  def test_a_string_that_would_not_read_back_plainly_is_quoted(self):
    self.change("set", "description", "Keeps: notes # and more")
    self.assertEqual(self.lines()[2], 'description: "Keeps: notes # and more"')
    self.assertEqual(load_yaml(self.manifest.read_text())["description"], "Keeps: notes # and more")

  def test_an_empty_string_is_a_value_not_a_removal(self):
    after = self.change("set", "command-name", "")
    self.assertEqual(after["values"]["command-name"], "")
    self.assertIn('command-name: ""', self.lines())


  def test_a_new_key_goes_after_the_last_key_the_schema_lists_before_it(self):
    self.change("set", "command-name", "rec")
    self.assertEqual(self.lines()[6], "command-name: rec")
    self.assertEqual(self.lines()[7], "naming:")

  def test_a_reset_removes_the_key_so_it_reads_as_untouched(self):
    self.change("set", "command-name", "rec")
    after = self.change("reset", "command-name")
    self.assertNotIn("command-name", after["values"])
    self.assertEqual(self.manifest.read_text(), FIXTURE.read_text())

  def test_what_the_schema_refuses_leaves_the_file_alone(self):
    refusals = [
      (Change("reset", "name"), "requires"),
      (Change("set", "description", "two\nlines"), "one line"),
      (Change("set", "default-channel", "nightly"), "one of dev, stable"),
      (Change("set", "name", 3), "must be string"),
      (Change("set", "naming", "x"), "must be object"),
      (Change("set", "naming", {"major": "x"}), "single values"),
      (Change("clear", "command-name"), "cannot be cleared"),
      (Change("set", "nonsense", "x"), "not a key"),
    ]

    for change, reason in refusals:
      with self.subTest(change=change), self.assertRaisesRegex(Refused, reason):
        self.change(change.op, change.key, change.value)

    self.assertEqual(self.manifest.read_text(), FIXTURE.read_text())


class TheThreeStates(AProject):
  def setUp(self):
    super().setUp()
    shutil.copy(FLAGS_SCHEMA, self.root / "shell" / ".ops" / "schema" / "flags.schema.json")
    (self.root / ".ops" / "config" / "flags.yaml").write_text("")

  def flag(self, op, key, value=None):
    """Applies one change to the flags document and answers its values after it."""

    record = self.store.read(self.root, "config/flags.yaml", "document")
    return self.store.write(self.root, "config/flags.yaml", "document", Change(op, key, value), record["revision"])["values"]

  def test_false_and_zero_are_values(self):
    self.assertIs(self.flag("set", "ship", False)["ship"], False)
    self.assertEqual(self.flag("set", "retries", 0)["retries"], 0)
    self.assertEqual((self.root / ".ops" / "config" / "flags.yaml").read_text(), "ship: false\nretries: 0\n")

  def test_a_clear_writes_null_where_the_schema_allows_it_and_reads_as_cleared(self):
    values = self.flag("clear", "override")
    self.assertIn("override", values)
    self.assertIsNone(values["override"])

  def test_a_clear_is_refused_where_the_schema_has_no_null(self):
    with self.assertRaisesRegex(Refused, "cannot be cleared"):
      self.flag("clear", "ship")

  def test_a_reset_takes_a_cleared_key_back_to_untouched(self):
    self.flag("clear", "override")
    self.assertNotIn("override", self.flag("reset", "override"))

