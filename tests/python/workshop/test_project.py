"""Covers workshop.project: finding a project from inside it, reading what it declares."""

import tempfile
import unittest
from pathlib import Path

from workshop.project import declared_tools, find_project, release, summary_line


def make_project(root):
  """A shellops project as init leaves it: the dispatcher, the declaration and a lock."""

  (root / "shell").mkdir(parents=True)
  (root / "shell" / "ops").write_text("#!/bin/sh\n")
  (root / ".ops" / "config").mkdir(parents=True)
  (root / ".ops" / "config" / "manifest.yaml").write_text("name: Demo\norg: creature-workshop\nrepo: demo\n")
  (root / ".ops" / "config" / "tools.yaml").write_text("system:\n  ffmpeg:\n    version: 6.1.1\n  rsync:\n    version: 3.2.7\n")
  (root / ".ops" / "lock").write_text('{"seeds": {}, "release": {"latest": "0.1.0-dev.1", "stable": "0.0.0"}}')
  return root


class FindProject(unittest.TestCase):
  def test_finds_the_project_from_a_directory_inside_it(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = make_project(Path(tmp) / "demo")
      inside = root / "lib" / "deep"
      inside.mkdir(parents=True)
      self.assertEqual(find_project(inside), root.resolve())

  def test_none_outside_any_project(self):
    with tempfile.TemporaryDirectory() as tmp:
      self.assertIsNone(find_project(tmp))

  def test_finds_the_first_project_below_a_directory_above_its_projects(self):
    with tempfile.TemporaryDirectory() as tmp:
      make_project(Path(tmp) / "code" / "beta")
      alpha = make_project(Path(tmp) / "code" / "alpha")
      (Path(tmp) / "code" / "node_modules").mkdir()
      make_project(Path(tmp) / "code" / "node_modules" / "ignored")
      self.assertEqual(find_project(Path(tmp) / "code"), alpha.resolve())

  def test_a_nearer_level_wins_over_name_order(self):
    with tempfile.TemporaryDirectory() as tmp:
      make_project(Path(tmp) / "zeta")
      make_project(Path(tmp) / "alpha" / "deep" / "nested")
      self.assertEqual(find_project(tmp), (Path(tmp) / "zeta").resolve())

  def test_nothing_four_levels_down(self):
    with tempfile.TemporaryDirectory() as tmp:
      make_project(Path(tmp) / "a" / "b" / "c" / "d")
      self.assertIsNone(find_project(tmp))


class Declaration(unittest.TestCase):
  def test_declared_tools_lists_channel_tool_and_version(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = make_project(Path(tmp) / "demo")
      self.assertEqual(declared_tools(root), [("system", "ffmpeg", "6.1.1"), ("system", "rsync", "3.2.7")])

  def test_release_reads_the_lock(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = make_project(Path(tmp) / "demo")
      self.assertEqual(release(root), {"latest": "0.1.0-dev.1", "stable": "0.0.0"})

  def test_summary_line_names_the_project_its_tools_and_its_release(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = make_project(Path(tmp) / "demo")
      line = summary_line(root)
      self.assertIn('"Demo"', line)
      self.assertIn("2 tools", line)
      self.assertIn("0.1.0-dev.1", line)


if __name__ == "__main__":
  unittest.main()
