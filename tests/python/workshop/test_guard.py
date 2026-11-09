"""Covers workshop.agent.guard: which terminal commands the hook blocks, what it says, and when it re-runs the check.

The project is the golden case `missing`, whose shell/ops stub reports ffmpeg
installed and rsync missing.
"""

import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from workshop.agent import guard
from workshop.run import ops

HERE = Path(__file__).parent
MISSING = HERE / "goldens" / "cases" / "missing" / "input"


def terminal(command, workdir):
  """The hook's answer for a terminal call of the command in the directory."""

  return guard.before_tool_call("terminal", {"command": command, "workdir": str(workdir)}, "")


class InAProject(unittest.TestCase):
  def setUp(self):
    guard.CACHE.clear()
    self.scratch = tempfile.mkdtemp()
    self.root = Path(self.scratch) / "demo"
    shutil.copytree(MISSING, self.root)
    (self.root / "shell" / "ops").chmod(0o755)

  def tearDown(self):
    shutil.rmtree(self.scratch)

  def test_a_declared_tool_that_is_missing_is_blocked_with_the_version_and_the_fix(self):
    answer = terminal("rsync -a src/ dst/", self.root)
    self.assertEqual(answer["action"], "block")
    self.assertIn("rsync is declared in .ops/config/tools.yaml at 3.2.7 on the system channel", answer["message"])
    self.assertIn("workshop_install, tools: [rsync], check: false", answer["message"])

  def test_a_declared_tool_that_is_installed_passes(self):
    self.assertIsNone(terminal("ffmpeg -i in.wav out.mp3", self.root))

  def test_an_undeclared_program_passes(self):
    self.assertIsNone(terminal("ls -la", self.root))

  def test_the_tool_is_found_behind_a_wrapper_and_inside_a_pipeline(self):
    self.assertEqual(terminal("sudo rsync -a src/ dst/", self.root)["action"], "block")
    self.assertEqual(terminal("cat list | rsync -a --files-from=- src/ dst/", self.root)["action"], "block")

  def test_another_tool_passes_whatever_its_arguments(self):
    self.assertIsNone(guard.before_tool_call("read_file", {"path": "rsync"}, ""))

  def test_the_check_runs_once_until_forgotten(self):
    with mock.patch.object(guard.ops, "run", wraps=ops.run) as run:
      terminal("rsync -a src/ dst/", self.root)
      terminal("rsync -a src/ dst/", self.root)
      self.assertEqual(run.call_count, 1)
      guard.forget(self.root)
      terminal("rsync -a src/ dst/", self.root)
      self.assertEqual(run.call_count, 2)


class OutsideAProject(unittest.TestCase):
  def test_passes_without_running_anything(self):
    with tempfile.TemporaryDirectory() as tmp:
      with mock.patch.object(guard.ops, "run") as run:
        self.assertIsNone(terminal("rsync -a src/ dst/", tmp))
        run.assert_not_called()


class ProgramsOf(unittest.TestCase):
  def test_one_program_per_segment_without_wrappers_assignments_and_options(self):
    self.assertEqual(guard.programs_of("FOO=1 sudo rsync -a src dst | tee log"), ["rsync", "tee"])
    self.assertEqual(guard.programs_of("cd lib && ../bin/ffmpeg -i a b; echo done"), ["cd", "ffmpeg", "echo"])

  def test_broken_quoting_still_finds_the_program(self):
    self.assertEqual(guard.programs_of("rsync 'unterminated"), ["rsync"])

  def test_an_empty_command_runs_nothing(self):
    self.assertEqual(guard.programs_of(""), [])


if __name__ == "__main__":
  unittest.main()
