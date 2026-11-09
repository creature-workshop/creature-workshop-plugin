"""Covers dashboard/plugin_api.py and the routes it includes: that Hermes can
load it by its path and mount every route, and the shape of GET /project,
inside a project and outside one.

The backend is loaded the way Hermes loads it, from the file's path, and the
route is called directly; the project is the golden case `installed`, whose
shell/ops stub prints a check table with every tool installed.
"""

import asyncio
import importlib
import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path

from workshop.models.project import NoProject, Project

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
  """GET /project's answer for a directory, as the model it returns, once the backend is loaded."""

  load_backend()
  route = importlib.import_module("workshop.routes.project")
  return asyncio.run(route.project(path=str(path), check=check))


class Mounting(unittest.TestCase):
  def test_the_router_carries_every_route_the_pane_reads(self):
    paths = {route.path for route in load_backend().router.routes}
    self.assertEqual(paths, {"/about", "/project", "/repos", "/repos/status"})


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
