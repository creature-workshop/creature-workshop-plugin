"""Covers workshop.project.setup and GET /project/setup: how far a checkout is set up, from its files."""

import asyncio
import tempfile
import unittest
from pathlib import Path

from workshop.project.setup import setup_state
from workshop.routes.project import setup


def checkout(root, adopted=False, dispatcher=False):
  """A checkout at root: with .ops/config when adopted, and shell/ops when its dispatcher is installed."""

  root.mkdir(parents=True, exist_ok=True)
  if adopted:
    (root / ".ops" / "config").mkdir(parents=True)

  if dispatcher:
    (root / "shell").mkdir()
    (root / "shell" / "ops").write_text("#!/bin/sh\n")

  return root


class SetupState(unittest.TestCase):
  def test_a_branch_without_a_declaration_has_no_workshop(self):
    with tempfile.TemporaryDirectory() as tmp:
      self.assertEqual(setup_state(checkout(Path(tmp) / "notes")), "no-workshop")

  def test_a_declaration_without_the_dispatcher_is_not_set_up(self):
    with tempfile.TemporaryDirectory() as tmp:
      self.assertEqual(setup_state(checkout(Path(tmp) / "fresh", adopted=True)), "not-set-up")

  def test_a_declaration_and_the_dispatcher_is_ready(self):
    with tempfile.TemporaryDirectory() as tmp:
      self.assertEqual(setup_state(checkout(Path(tmp) / "demo", adopted=True, dispatcher=True)), "ready")

  def test_a_dispatcher_without_a_declaration_still_has_no_workshop(self):
    with tempfile.TemporaryDirectory() as tmp:
      self.assertEqual(setup_state(checkout(Path(tmp) / "odd", dispatcher=True)), "no-workshop")

  def test_a_project_above_the_checkout_does_not_count(self):
    with tempfile.TemporaryDirectory() as tmp:
      checkout(Path(tmp), adopted=True, dispatcher=True)
      self.assertEqual(setup_state(checkout(Path(tmp) / "nested")), "no-workshop")


class SetupRoute(unittest.TestCase):
  def test_answers_the_root_and_its_state(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = checkout(Path(tmp) / "fresh", adopted=True)
      answer = asyncio.run(setup(root=str(root)))
      self.assertEqual((answer.root, answer.state), (str(root), "not-set-up"))
