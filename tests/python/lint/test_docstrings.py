"""Covers shell/lint/docstrings.py against the fixtures beside this file."""

import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parents[2]
FIXTURES = ROOT / "shell" / "lint" / "fixtures" / "docstrings"
LINTER = ROOT / "shell" / "lint" / "docstrings.py"


def load_linter():
  """The linter module, imported from its path."""

  spec = importlib.util.spec_from_file_location("docstrings", LINTER)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


class Docstrings(unittest.TestCase):
  def setUp(self):
    self.linter = load_linter()

  def test_one_blank_line_after_each_docstring_has_no_findings(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "spaced.py"), [])

  def test_a_file_without_a_doc_block_is_reported_on_line_one(self):
    findings = self.linter.check_file(FIXTURES / "none.py")
    self.assertEqual(len(findings), 1)
    self.assertIn("none.py:1: this file has no doc block", findings[0])

  def test_no_blank_line_and_two_blank_lines_are_each_reported_by_name(self):
    findings = self.linter.check_file(FIXTURES / "crowded.py")
    self.assertEqual(len(findings), 3)
    self.assertIn("crowded.py:1: the docstring of the module is followed by 0 blank lines", findings[0])
    self.assertIn("crowded.py:6: the docstring of add_limit is followed by 0 blank lines", findings[1])
    self.assertIn("crowded.py:11: the docstring of double is followed by 2 blank lines", findings[2])

  def test_a_function_or_class_without_a_docstring_is_reported_by_name(self):
    findings = self.linter.check_file(FIXTURES / "undocumented.py")
    self.assertEqual(len(findings), 2)
    self.assertIn("undocumented.py:3: add_limit has no docstring", findings[0])
    self.assertIn("undocumented.py:10: reset has no docstring", findings[1])

  def test_a_test_file_needs_no_docstring_on_its_test_classes_and_methods(self):
    self.assertEqual(self.linter.check_file(HERE / "test_docstrings.py"), [])


if __name__ == "__main__":
  unittest.main()
