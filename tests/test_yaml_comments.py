"""Covers shell/lint/yaml_comments.py against the fixtures beside this file."""
import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).parent
FIXTURES = HERE / "fixtures" / "yaml_comments"
LINTER = HERE.parent / "shell" / "lint" / "yaml_comments.py"


def load_linter():
  spec = importlib.util.spec_from_file_location("yaml_comments", LINTER)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


class YamlComments(unittest.TestCase):
  def setUp(self):
    self.linter = load_linter()

  def test_a_clean_file_has_no_findings(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "clean.yml"), [])

  def test_a_line_comment_and_a_trailing_comment_are_each_reported(self):
    findings = self.linter.check_file(FIXTURES / "commented.yml")
    self.assertEqual(len(findings), 2)
    self.assertIn("commented.yml:1:", findings[0])
    self.assertIn("commented.yml:3:", findings[1])

  def test_a_hash_inside_a_quoted_scalar_or_a_url_is_not_a_comment(self):
    self.assertFalse(self.linter.has_comment("note: 'a # b'"))
    self.assertFalse(self.linter.has_comment("url: https://example.test/#anchor"))
    self.assertTrue(self.linter.has_comment("key: value # why"))


if __name__ == "__main__":
  unittest.main()
