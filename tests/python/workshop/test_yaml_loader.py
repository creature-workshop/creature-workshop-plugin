"""Covers workshop.project.yaml_loader, and that the manifest template declares the library it reads with."""

import unittest
from pathlib import Path

from workshop.project.yaml_loader import dump_yaml, load_yaml

TEMPLATE = Path(__file__).resolve().parents[3] / "shell" / "actions" / "hermes" / "plugin.yaml.template"


class LoadYaml(unittest.TestCase):
  def test_load_yaml_gives_a_mapping_as_a_dict_with_nested_lists(self):
    self.assertEqual(load_yaml("name: Recording rig\ntools: [ffmpeg, rsync]\n"), {"name": "Recording rig", "tools": ["ffmpeg", "rsync"]})

  def test_load_yaml_gives_none_for_an_empty_document(self):
    self.assertIsNone(load_yaml(""))

  def test_load_yaml_does_not_build_python_objects_from_tags(self):
    with self.assertRaises(Exception):
      load_yaml("!!python/object/apply:os.getcwd []\n")


class DumpYaml(unittest.TestCase):
  def test_dump_yaml_keeps_the_order_of_the_keys_and_writes_lists_as_blocks(self):
    self.assertEqual(dump_yaml({"name": "Notes", "tools": ["ffmpeg"]}), "name: Notes\ntools:\n- ffmpeg\n")

  def test_dump_yaml_writes_a_string_of_several_lines_as_a_literal_block_that_reads_back_the_same(self):
    text = dump_yaml({"description": "One.\nTwo."})
    self.assertEqual(text, "description: |-\n  One.\n  Two.\n")
    self.assertEqual(load_yaml(text), {"description": "One.\nTwo."})


class Declared(unittest.TestCase):
  def test_plugin_yaml_template_declares_pyyaml_with_a_floor_and_an_upper_bound(self):
    declared = load_yaml(TEMPLATE.read_text())["python_dependencies"]
    self.assertEqual(declared, ["PyYAML>=6.0,<7"])


if __name__ == "__main__":
  unittest.main()
