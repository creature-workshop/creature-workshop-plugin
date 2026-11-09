"""Covers shell/lint/declarations_first.py against the fixtures beside this file."""

import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parents[2]
FIXTURES = ROOT / "shell" / "lint" / "fixtures" / "declarations_first"
LINTER = ROOT / "shell" / "lint" / "declarations_first.py"


def load_linter():
  """The linter module, imported from its path."""

  spec = importlib.util.spec_from_file_location("declarations_first", LINTER)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


class DeclarationsFirst(unittest.TestCase):
  def setUp(self):
    self.linter = load_linter()

  def test_constants_before_the_functions_have_no_findings(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "first.py"), [])

  def test_a_late_constant_and_a_banner_are_each_reported_in_line_order(self):
    findings = self.linter.check_file(FIXTURES / "late.py")
    self.assertEqual(len(findings), 2)
    self.assertIn("late.py:9: LIMIT is assigned after the first function", findings[0])
    self.assertIn("Move it above add_limit", findings[0])
    self.assertIn("late.py:11: this comment draws a line", findings[1])


if __name__ == "__main__":
  unittest.main()
