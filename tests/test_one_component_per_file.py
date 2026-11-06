"""Covers shell/lint/one_component_per_file.py against the fixtures beside this file."""
import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).parent
FIXTURES = HERE / "fixtures" / "one_component_per_file"
LINTER = HERE.parent / "shell" / "lint" / "one_component_per_file.py"


def load_linter():
  spec = importlib.util.spec_from_file_location("one_component_per_file", LINTER)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


class OneComponentPerFile(unittest.TestCase):
  def setUp(self):
    self.linter = load_linter()

  def test_one_component_in_a_file_of_its_name_passes(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "Clean.jsx"), [])

  def test_a_file_without_components_passes_whatever_its_name(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "store.js"), [])

  def test_two_components_are_reported_at_the_second(self):
    findings = self.linter.check_file(FIXTURES / "two.jsx")
    self.assertEqual(len(findings), 1)
    self.assertIn("two.jsx:6: one component per file; this one has 2: First, Second", findings[0])

  def test_a_misnamed_file_is_reported(self):
    findings = self.linter.check_file(FIXTURES / "misnamed.jsx")
    self.assertEqual(len(findings), 1)
    self.assertIn("Named.jsx", findings[0])

  def test_a_declared_reason_allows_more(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "allowed.jsx"), [])


if __name__ == "__main__":
  unittest.main()
