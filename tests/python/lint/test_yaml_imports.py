"""Covers shell/lint/yaml_imports.py against its fixtures under shell/lint/fixtures/yaml_imports/."""

import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parents[2]
FIXTURES = ROOT / "shell" / "lint" / "fixtures" / "yaml_imports"
LINTER = ROOT / "shell" / "lint" / "yaml_imports.py"
LOADER = ROOT / "workshop" / "project" / "yaml_loader.py"


def load_linter():
  """The linter module, imported from its path."""

  spec = importlib.util.spec_from_file_location("yaml_imports", LINTER)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


class YamlImports(unittest.TestCase):
  def setUp(self):
    self.linter = load_linter()

  def test_check_file_reports_nothing_for_a_module_that_imports_load_yaml(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "through_loader.py"), [])

  def test_check_file_reports_each_import_of_yaml_hermes_yaml_and_ruamel(self):
    findings = self.linter.check_file(FIXTURES / "direct.py")
    self.assertEqual(len(findings), 3)
    self.assertIn("direct.py:3: import YAML through load_yaml", findings[0])
    self.assertIn("direct.py:4: import YAML through load_yaml", findings[1])
    self.assertIn("direct.py:5: import YAML through load_yaml", findings[2])

  def test_check_file_reports_nothing_for_the_loader_which_imports_yaml(self):
    self.assertIn("import yaml", LOADER.read_text())
    self.assertEqual(self.linter.check_file(LOADER), [])


if __name__ == "__main__":
  unittest.main()
