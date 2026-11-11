"""Covers workshop.project.setup and GET /project/setup: whether a checkout has a workshop, from its files."""

import asyncio
import tempfile
import unittest
from pathlib import Path

from workshop.project.setup import setup_state
from workshop.routes.project import setup


def checkout(root, adopted=False):
  """A checkout at root, with .ops/config when adopted."""

  root.mkdir(parents=True, exist_ok=True)
  if adopted:
    (root / ".ops" / "config").mkdir(parents=True)

  return root


class SetupState(unittest.TestCase):
  def test_a_branch_without_a_declaration_has_no_workshop(self):
    with tempfile.TemporaryDirectory() as tmp:
      self.assertEqual(setup_state(checkout(Path(tmp) / "notes")), "no-workshop")

  def test_a_declaration_is_ready_without_a_shellops_of_its_own(self):
    with tempfile.TemporaryDirectory() as tmp:
      self.assertEqual(setup_state(checkout(Path(tmp) / "demo", adopted=True)), "ready")

  def test_a_project_above_the_checkout_does_not_count(self):
    with tempfile.TemporaryDirectory() as tmp:
      checkout(Path(tmp), adopted=True)
      self.assertEqual(setup_state(checkout(Path(tmp) / "nested")), "no-workshop")


class SetupRoute(unittest.TestCase):
  def test_answers_the_root_and_its_state(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = checkout(Path(tmp) / "notes")
      answer = asyncio.run(setup(root=str(root)))
      self.assertEqual((answer.root, answer.state), (str(root), "no-workshop"))
