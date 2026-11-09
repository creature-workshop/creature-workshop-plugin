"""Covers workshop.project.manifest_edit over a copy of
workshop/project/manifest_edit.fixture.yaml: a change rewrites only its own
line, keeps comments and the other keys, quotes a value only when it must,
adds and removes the optional command-name, and refuses what the manifest
cannot take without touching the file.
"""

import shutil
import tempfile
import unittest
from pathlib import Path

from workshop.project.declaration import load_yaml
from workshop.project.manifest_edit import ManifestEditError, set_field

FIXTURE = Path(__file__).resolve().parents[3] / "workshop" / "project" / "manifest_edit.fixture.yaml"


class SetField(unittest.TestCase):
  def setUp(self):
    self.root = Path(tempfile.mkdtemp())
    self.manifest = self.root / ".ops" / "config" / "manifest.yaml"
    self.manifest.parent.mkdir(parents=True)
    shutil.copy(FIXTURE, self.manifest)

  def tearDown(self):
    shutil.rmtree(self.root)

  def lines(self):
    """The manifest's lines as they are on disk now."""

    return self.manifest.read_text().splitlines()

  def test_a_change_rewrites_only_its_own_line(self):
    before = self.lines()
    set_field(self.root, "description", "Records sessions from one key.")
    after = self.lines()
    self.assertEqual(after[2], "description: Records sessions from one key.")
    self.assertEqual(after[:2] + after[3:], before[:2] + before[3:])

  def test_a_value_that_would_not_read_back_plainly_is_quoted(self):
    set_field(self.root, "description", "Keeps: notes # and more")
    self.assertEqual(self.lines()[2], 'description: "Keeps: notes # and more"')
    self.assertEqual(load_yaml(self.manifest.read_text())["description"], "Keeps: notes # and more")

  def test_a_missing_optional_key_is_added_after_the_edited_fields(self):
    set_field(self.root, "command-name", "rec")
    self.assertEqual(self.lines()[6], "command-name: rec")
    self.assertEqual(self.lines()[7], "naming:")

  def test_an_empty_optional_key_is_removed(self):
    set_field(self.root, "command-name", "rec")
    set_field(self.root, "command-name", "")
    self.assertEqual(self.manifest.read_text(), FIXTURE.read_text())

  def test_a_required_field_cannot_be_emptied_and_the_file_is_left_alone(self):
    with self.assertRaisesRegex(ManifestEditError, "requires"):
      set_field(self.root, "name", "  ")

    self.assertEqual(self.manifest.read_text(), FIXTURE.read_text())

  def test_only_the_fields_the_pane_edits_can_be_changed(self):
    with self.assertRaisesRegex(ManifestEditError, "not a field"):
      set_field(self.root, "naming", "x")

  def test_a_value_must_be_one_line(self):
    with self.assertRaisesRegex(ManifestEditError, "one line"):
      set_field(self.root, "description", "two\nlines")

  def test_a_project_without_a_manifest_says_so(self):
    self.manifest.unlink()
    with self.assertRaisesRegex(ManifestEditError, "no .ops/config/manifest.yaml"):
      set_field(self.root, "name", "x")
