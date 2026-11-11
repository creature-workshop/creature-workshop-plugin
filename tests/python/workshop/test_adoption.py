"""Covers workshop.project.adoption and /project/adoption and /project/adopt: the
adoption form's suggestions, and writing and committing a branch's first manifest."""

import asyncio
import subprocess
import tempfile
import unittest
from pathlib import Path

from fastapi import HTTPException

from workshop.models.adoption import AdoptBody, Manifest
from workshop.project.adoption import remote_parts, suggestions
from workshop.project.yaml_loader import load_yaml
from workshop.routes.project import adopt

MANIFEST = Manifest(name="Notes", description="Notes, kept in git.", **{"command-name": "notes"}, org="someone", repo="notes")
"""The manifest every adoption here writes."""


def repository(root, remote=""):
  """A git repository at root with one commit on main, and origin at remote when one is given."""

  root.mkdir(parents=True)
  for args in (["init", "-q", "-b", "main"], ["config", "user.email", "test@example.com"], ["config", "user.name", "Test"]):
    subprocess.run(["git", "-C", str(root), *args], check=True)

  (root / "README.md").write_text("notes\n")
  subprocess.run(["git", "-C", str(root), "add", "README.md"], check=True)
  subprocess.run(["git", "-C", str(root), "commit", "-q", "-m", "first"], check=True)
  if remote:
    subprocess.run(["git", "-C", str(root), "remote", "add", "origin", remote], check=True)

  return root


def git_out(root, *args):
  """What git prints at root, stripped."""

  return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, check=True).stdout.strip()


class RemoteParts(unittest.TestCase):
  def test_reads_ssh_and_https_urls(self):
    self.assertEqual(remote_parts("git@gitlab.example.com:someone/notes.git"), ("someone", "notes"))
    self.assertEqual(remote_parts("https://github.com/someone/notes"), ("someone", "notes"))

  def test_nothing_from_no_url(self):
    self.assertEqual(remote_parts(""), ("", ""))


class Suggestions(unittest.TestCase):
  def test_suggests_the_folder_the_remotes_repository_and_the_branch(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = repository(Path(tmp) / "notes", "git@gitlab.example.com:someone/notes-repo.git")
      self.assertEqual(suggestions(root), {"name": "notes", "repo": "notes-repo", "branch": "main"})

  def test_leaves_the_repository_empty_without_a_remote(self):
    with tempfile.TemporaryDirectory() as tmp:
      self.assertEqual(suggestions(repository(Path(tmp) / "notes"))["repo"], "")


class Adopt(unittest.TestCase):
  def test_writes_the_manifest_in_order_without_committing_it(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = repository(Path(tmp) / "notes")
      answer = asyncio.run(adopt(AdoptBody(root=str(root), manifest=MANIFEST)))
      written = (root / ".ops" / "config" / "manifest.yaml").read_text()
      self.assertEqual(list(load_yaml(written)), ["name", "description", "command-name", "org", "repo"])
      self.assertEqual((answer.committed, git_out(root, "log", "--format=%s")), (False, "first"))

  def test_commits_the_manifest_alone_when_asked(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = repository(Path(tmp) / "notes")
      (root / "staged.txt").write_text("not mine\n")
      subprocess.run(["git", "-C", str(root), "add", "staged.txt"], check=True)
      answer = asyncio.run(adopt(AdoptBody(root=str(root), manifest=MANIFEST, commit=True)))
      self.assertTrue(answer.committed)
      self.assertEqual(git_out(root, "log", "-1", "--format=%s"), "chore: set up workshop files (.ops/)")
      self.assertEqual(git_out(root, "show", "--name-only", "--format="), ".ops/config/manifest.yaml")
      self.assertEqual(git_out(root, "diff", "--cached", "--name-only"), "staged.txt")

  def test_refuses_a_checkout_that_already_has_a_workshop(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = repository(Path(tmp) / "notes")
      (root / ".ops" / "config").mkdir(parents=True)
      with self.assertRaises(HTTPException) as refused:
        asyncio.run(adopt(AdoptBody(root=str(root), manifest=MANIFEST)))

      self.assertEqual(refused.exception.detail, "notes already has a workshop.")

  def test_says_when_git_did_not_commit(self):
    with tempfile.TemporaryDirectory() as tmp:
      root = Path(tmp) / "plain"
      root.mkdir()
      with self.assertRaises(HTTPException) as refused:
        asyncio.run(adopt(AdoptBody(root=str(root), manifest=MANIFEST, commit=True)))

      self.assertIn("I wrote .ops/config/manifest.yaml, but git didn't commit it", refused.exception.detail)
