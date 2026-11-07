"""Covers workshop.ops: the check table's rows and the shape a run reports."""

import json
import tempfile
import unittest
from pathlib import Path

from workshop import check_table, ops, tools

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
      outcome = ops.run(root, ["lint"])
      self.assertFalse(outcome["ok"])
      self.assertEqual(outcome["stderr"].strip(), "nope")


class Tools(unittest.TestCase):
  def test_a_tool_outside_a_project_answers_with_an_error_not_an_exception(self):
    with tempfile.TemporaryDirectory() as tmp:
      answer = json.loads(tools.workshop_project({"path": tmp}))
      self.assertFalse(answer["ok"])
      self.assertIn("not inside a shellops project", answer["error"])

  def test_test_verb_is_checked(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = Path(tmp)
      (root / "shell").mkdir()
      (root / "shell" / "ops").write_text("#!/bin/sh\n")
      (root / ".ops" / "config").mkdir(parents=True)
      answer = json.loads(tools.workshop_test({"path": tmp, "verb": "bogus"}))
      self.assertFalse(answer["ok"])
      self.assertIn("verb must be", answer["error"])


if __name__ == "__main__":
  unittest.main()


class Logging(unittest.TestCase):
  def test_a_failed_run_is_logged_as_a_warning_with_its_stderr(self):
    with tempfile.TemporaryDirectory() as tmp:
      with self.assertLogs("creature-workshop", level="WARNING") as logged:
        ops.run(tmp, ["install", "--check"])

      self.assertIn("shell/ops install --check failed", logged.output[0])

  def test_a_successful_run_is_logged_as_info(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = Path(tmp)
      (root / "shell").mkdir()
      (root / "shell" / "ops").write_text("#!/bin/sh\nexit 0\n")
      (root / "shell" / "ops").chmod(0o755)
      with self.assertLogs("creature-workshop", level="INFO") as logged:
        ops.run(root, ["lint"])

      self.assertIn("INFO:creature-workshop:shell/ops lint in", logged.output[0])
