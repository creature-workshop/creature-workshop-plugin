"""Covers workshop.run.ops and workshop.project.check_table: the check table's rows and the shape a run reports."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests.python.workshop.test_consent import approving
from tests.python.workshop.test_repos import repo
from workshop.agent import session, tools
from workshop.project import check_table
from workshop.run import ops

CHECK_TABLE = """Status     Tool                   Version        Channel
------------------------------------------------------------
 ✓      ffmpeg                 6.1.1          system
 ✗      rsync                  3.2.7          system
"""


class ParseCheckTable(unittest.TestCase):
  def test_rows_with_installed_from_the_mark(self):
    rows = check_table.parse(CHECK_TABLE)
    self.assertEqual(rows, [
      {"tool": "ffmpeg", "version": "6.1.1", "channel": "system", "installed": True},
      {"tool": "rsync", "version": "3.2.7", "channel": "system", "installed": False},
    ])

  def test_empty_text_gives_no_rows(self):
    self.assertEqual(check_table.parse(""), [])


class Run(unittest.TestCase):
  def test_reports_the_dispatcher_output_and_duration(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = Path(tmp)
      (root / "shell").mkdir()
      (root / "shell" / "ops").write_text("#!/bin/sh\necho \"ran $*\"\n")
      (root / "shell" / "ops").chmod(0o755)
      with approving(root):
        outcome = ops.run(root, ["install", "--check"])

      self.assertTrue(outcome["ok"])
      self.assertEqual(outcome["stdout"].strip(), "ran install --check")
      self.assertEqual(outcome["command"], "shell/ops install --check")
      self.assertGreaterEqual(outcome["duration_ms"], 0)

  def test_a_failing_command_is_reported_not_raised(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = Path(tmp)
      (root / "shell").mkdir()
      (root / "shell" / "ops").write_text("#!/bin/sh\necho nope >&2\nexit 3\n")
      (root / "shell" / "ops").chmod(0o755)
      with approving(root):
        outcome = ops.run(root, ["lint"])

      self.assertFalse(outcome["ok"])
      self.assertEqual(outcome["stderr"].strip(), "nope")

  def test_runs_nothing_in_a_project_the_user_has_not_approved(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = Path(tmp)
      (root / "shell").mkdir()
      (root / "shell" / "ops").write_text("#!/bin/sh\ntouch ran\n")
      (root / "shell" / "ops").chmod(0o755)
      outcome = ops.run(root, ["lint"])
      self.assertFalse(outcome["ok"])
      self.assertIn("has not been approved for execution", outcome["stderr"])
      self.assertFalse((root / "ran").exists())


class Tools(unittest.TestCase):
  def test_a_tool_in_a_session_on_no_repository_answers_with_an_error_not_an_exception(self):
    with tempfile.TemporaryDirectory() as tmp, mock.patch.object(session, "directory", return_value=tmp):
      answer = json.loads(tools.workshop_project({}))
      self.assertFalse(answer["ok"])
      self.assertIn("No repository is selected for this session", answer["error"])

  def test_a_tool_in_a_repository_without_a_workshop_says_so(self):
    with tempfile.TemporaryDirectory() as tmp, mock.patch.object(session, "directory", return_value=tmp):
      repo(Path(tmp))
      answer = json.loads(tools.workshop_lint({}))
      self.assertFalse(answer["ok"])
      self.assertIn("doesn't have a workshop", answer["error"])

  def test_test_verb_is_checked(self):
    with tempfile.TemporaryDirectory() as tmp, mock.patch.object(session, "directory", return_value=tmp):
      root = repo(Path(tmp))
      (root / "shell").mkdir()
      (root / "shell" / "ops").write_text("#!/bin/sh\n")
      (root / ".ops" / "config").mkdir(parents=True)
      answer = json.loads(tools.workshop_test({"verb": "bogus"}))
      self.assertFalse(answer["ok"])
      self.assertIn("verb must be", answer["error"])


if __name__ == "__main__":
  unittest.main()


class Logging(unittest.TestCase):
  def test_a_failed_run_is_logged_as_a_warning_with_its_stderr(self):
    with tempfile.TemporaryDirectory() as tmp:
      with approving(tmp), self.assertLogs("creature-workshop", level="WARNING") as logged:
        ops.run(tmp, ["install", "--check"])

      self.assertIn("shell/ops install --check failed", logged.output[0])

  def test_a_successful_run_is_logged_as_info(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = Path(tmp)
      (root / "shell").mkdir()
      (root / "shell" / "ops").write_text("#!/bin/sh\nexit 0\n")
      (root / "shell" / "ops").chmod(0o755)
      with approving(root), self.assertLogs("creature-workshop", level="INFO") as logged:
        ops.run(root, ["lint"])

      self.assertIn("INFO:creature-workshop:shell/ops lint in", logged.output[0])
