"""Covers shell/lint/blank_after_block.py against the fixtures beside this file."""

import contextlib
import importlib.util
import io
import unittest
from pathlib import Path

HERE = Path(__file__).parent
FIXTURES = HERE / "fixtures" / "blank_after_block"
LINTER = HERE.parent / "shell" / "lint" / "blank_after_block.py"


def load_linter():
  """The linter module, imported from its path."""

  spec = importlib.util.spec_from_file_location("blank_after_block", LINTER)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


class BlankAfterBlock(unittest.TestCase):
  def setUp(self):
    self.linter = load_linter()

  def test_a_clean_file_has_no_findings(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "clean.py"), [])

  def test_a_missing_blank_line_is_reported_at_the_chain_end(self):
    findings = self.linter.check_file(FIXTURES / "missing.py")
    self.assertEqual(len(findings), 1)
    self.assertTrue(findings[0].endswith("missing.py:3: one blank line after this multi-line statement, before the next statement"))

  def test_a_multi_line_assignment_needs_the_blank_line_too(self):
    findings = self.linter.check_file(FIXTURES / "multiline.py")
    self.assertEqual(len(findings), 2)
    self.assertIn("multiline.py:5:", findings[0])
    self.assertIn("multiline.py:15:", findings[1])

  def test_two_blank_lines_are_reported(self):
    findings = self.linter.check_file(FIXTURES / "too_many.py")
    self.assertEqual(len(findings), 1)
    self.assertIn("not 2", findings[0])

  def test_a_comment_counts_as_code(self):
    findings = self.linter.check_file(FIXTURES / "comment.py")
    self.assertEqual(len(findings), 1)
    self.assertIn(":3:", findings[0])

  def test_main_exits_one_on_findings_and_zero_without(self):
    with contextlib.redirect_stdout(io.StringIO()):
      self.assertEqual(self.linter.main([str(FIXTURES / "clean.py")]), 0)
      self.assertEqual(self.linter.main([str(FIXTURES / "missing.py")]), 1)


if __name__ == "__main__":
  unittest.main()
