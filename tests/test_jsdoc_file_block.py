"""Covers shell/lint/jsdoc_file_block.py against the fixtures beside this file."""
import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).parent
FIXTURES = HERE / "fixtures" / "jsdoc_file_block"
LINTER = HERE.parent / "shell" / "lint" / "jsdoc_file_block.py"


def load_linter():
  spec = importlib.util.spec_from_file_location("jsdoc_file_block", LINTER)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


class JsdocFileBlock(unittest.TestCase):
  def setUp(self):
    self.linter = load_linter()

  def test_a_block_with_the_tag_and_words_passes(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "clean.js"), [])

  def test_a_shebang_above_the_block_is_allowed(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "shebang.js"), [])

  def test_a_line_comment_is_not_a_file_block(self):
    findings = self.linter.check_file(FIXTURES / "line_comment.js")
    self.assertEqual(len(findings), 1)
    self.assertIn("/** @file ... */", findings[0])

  def test_the_tag_is_required(self):
    findings = self.linter.check_file(FIXTURES / "no_tag.js")
    self.assertEqual(len(findings), 1)
    self.assertIn("@file", findings[0])


if __name__ == "__main__":
  unittest.main()
