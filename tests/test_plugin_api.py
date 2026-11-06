"""Covers dashboard/plugin_api.py: the shape of GET /project, inside a project and outside one.

The backend is loaded the way Hermes loads it, from the file's path, and
called directly; the project is the golden case `installed`, whose shell/ops
stub prints a check table with every tool installed.
"""
import asyncio
import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path

from workshop.answers import NoProject, Project

HERE = Path(__file__).parent
BACKEND = HERE.parent / "dashboard" / "plugin_api.py"
INSTALLED = HERE / "goldens" / "cases" / "installed" / "input"


def load_backend():
  """The backend module, imported from its path as Hermes imports it."""
  spec = importlib.util.spec_from_file_location("plugin_api", BACKEND)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


def answer_for(path, check="1"):
  """The backend's answer for a directory, as the model it returns."""
  return asyncio.run(load_backend().project(path=str(path), check=check))


class InsideAProject(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.mkdtemp()
    self.root = Path(self.scratch) / "demo"
    shutil.copytree(INSTALLED, self.root)
    (self.root / "shell" / "ops").chmod(0o755)

  def tearDown(self):
    shutil.rmtree(self.scratch)

  def test_answers_a_project_with_the_toolchain_checked(self):
    answer = answer_for(self.root)
    self.assertIsInstance(answer, Project)
    self.assertEqual(answer.root, str(self.root.resolve()))
    self.assertEqual([tool.tool for tool in answer.declared], ["ffmpeg", "rsync"])
    self.assertEqual([row.installed for row in answer.toolchain.rows], [True, True])
    self.assertEqual(answer.refresh_seconds, 20)

  def test_leaves_the_toolchain_out_when_the_check_is_off(self):
    answer = answer_for(self.root, check="0")
    self.assertIsInstance(answer, Project)
    self.assertIsNone(answer.toolchain)

  def test_the_answer_carries_every_field_the_pane_reads(self):
    fields = set(answer_for(self.root).model_dump())
    self.assertEqual(fields, {"found", "root", "name", "summary", "declaration", "release", "declared", "refresh_seconds", "toolchain"})


class OutsideAProject(unittest.TestCase):
  def test_answers_not_found_with_where_the_search_started(self):
    with tempfile.TemporaryDirectory() as tmp:
      answer = answer_for(tmp)
      self.assertIsInstance(answer, NoProject)
      self.assertFalse(answer.found)
      self.assertEqual(answer.start, tmp)
      self.assertEqual(answer.refresh_seconds, 20)
