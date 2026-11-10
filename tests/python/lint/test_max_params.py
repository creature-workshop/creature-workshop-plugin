"""Covers shell/lint/max_params.py against its fixtures under shell/lint/fixtures/max_params/."""

import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parents[2]
FIXTURES = ROOT / "shell" / "lint" / "fixtures" / "max_params"
LINTER = ROOT / "shell" / "lint" / "max_params.py"


def load_linter():
  """The linter module, imported from its path."""

  spec = importlib.util.spec_from_file_location("max_params", LINTER)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


class MaxParams(unittest.TestCase):
  def setUp(self):
    self.linter = load_linter()

  def test_five_parameters_a_methods_self_and_star_args_are_within_the_limit(self):
    self.assertEqual(self.linter.check_file(FIXTURES / "few.py"), [])

  def test_six_parameters_counting_star_star_kwargs_are_each_reported(self):
    findings = self.linter.check_file(FIXTURES / "many.py")
    self.assertEqual(len(findings), 2)
    self.assertIn("many.py:4: write takes 6 parameters", findings[0])
    self.assertIn("many.py:8: call takes 6 parameters", findings[1])
