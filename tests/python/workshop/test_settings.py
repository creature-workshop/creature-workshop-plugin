"""Covers workshop.settings: a setting comes from Hermes's configuration or from the manifest's default,
and the defaults the code falls back to are the ones the manifest template declares."""

import unittest
from pathlib import Path

from workshop.project.yaml_loader import load_yaml
from workshop.settings import DEFAULTS, from_config, value

TEMPLATE = Path(__file__).resolve().parents[3] / "shell" / "actions" / "hermes" / "plugin.yaml.template"


class FromConfig(unittest.TestCase):
  def test_reads_the_value_the_user_set(self):
    config = {"plugins": {"entries": {"creature-workshop": {"settings": {"pane_refresh_seconds": 5}}}}}
    self.assertEqual(from_config(config, "pane_refresh_seconds"), 5)

  def test_falls_back_to_the_default_when_the_plugin_has_no_entry(self):
    self.assertEqual(from_config({}, "pane_refresh_seconds"), 20)

  def test_falls_back_to_the_default_when_the_setting_is_not_set(self):
    config = {"plugins": {"entries": {"creature-workshop": {"settings": {"ops_timeout_seconds": 30}}}}}
    self.assertEqual(from_config(config, "pane_refresh_seconds"), 20)


class Defaults(unittest.TestCase):
  def test_match_the_manifest_template(self):
    schema = load_yaml(TEMPLATE.read_text())["config_schema"]
    self.assertEqual({key: entry["default"] for key, entry in schema.items()}, DEFAULTS)

  def test_value_outside_hermes_is_the_default(self):
    self.assertEqual(value("ops_timeout_seconds"), 120)


if __name__ == "__main__":
  unittest.main()
