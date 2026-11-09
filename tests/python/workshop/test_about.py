"""Covers workshop.about: the version comes from the lock, and the branch is the checkout's,
the short commit when HEAD is detached, and empty outside git."""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from workshop.about import about, branch_of


def git(root, *args):
  """Runs git at root for the tests, quietly, and returns what it printed."""

  return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, check=True).stdout.strip()


def checkout(root):
  """A git checkout at root with one commit on a branch named trunk."""

  git(root, "init", "-q", "-b", "trunk")
  git(root, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "first")


class BranchOf(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.TemporaryDirectory()
    self.root = Path(self.scratch.name)

  def tearDown(self):
    self.scratch.cleanup()

  def test_the_branch_checked_out(self):
    checkout(self.root)
    self.assertEqual(branch_of(self.root), "trunk")

  def test_the_short_commit_when_head_is_detached(self):
    checkout(self.root)
    git(self.root, "checkout", "-q", "--detach")
    self.assertEqual(branch_of(self.root), git(self.root, "rev-parse", "--short", "HEAD"))

  def test_empty_outside_git(self):
    self.assertEqual(branch_of(self.root), "")


class AboutRecord(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.TemporaryDirectory()
    self.root = Path(self.scratch.name)
    checkout(self.root)

  def tearDown(self):
    self.scratch.cleanup()

  def test_reads_the_latest_release_of_the_lock(self):
    (self.root / ".ops").mkdir()
    (self.root / ".ops" / "lock").write_text(json.dumps({"release": {"latest": "0.1.0-dev.9", "stable": "0.0.0"}}))
    self.assertEqual(about(self.root), {"version": "0.1.0-dev.9", "branch": "trunk"})

  def test_an_empty_version_before_the_first_release(self):
    self.assertEqual(about(self.root), {"version": "", "branch": "trunk"})


if __name__ == "__main__":
  unittest.main()
