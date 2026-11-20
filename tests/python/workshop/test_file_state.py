"""Covers workshop.repos.file_state, and through it shell/actions/git/file-state,
over a real repository made in a scratch folder: the state git gives one
file as it is committed, changed, staged, added, deleted, ignored and left
in conflict, and "none" where git has nothing to say about it. Also covers
GET /repos/file-state, which answers that state.
"""

import asyncio
import importlib
import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path

from tests.python.workshop.test_repos import git, merge_with_conflict, repo
from workshop.repos.file_state import state_of

BACKEND = Path(__file__).resolve().parents[3] / "dashboard" / "plugin_api.py"

NAME = "notes.yaml"


def route_module():
  """workshop.routes.repos, once the backend is loaded the way Hermes loads it."""

  spec = importlib.util.spec_from_file_location("plugin_api", BACKEND)
  spec.loader.exec_module(importlib.util.module_from_spec(spec))
  return importlib.import_module("workshop.routes.repos")


class AFileInARepository(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.mkdtemp()
    self.root = repo(Path(self.scratch) / "demo")
    self.file = self.root / NAME

  def tearDown(self):
    shutil.rmtree(self.scratch)

  def commit(self, text):
    """Writes text to the file and commits it."""

    self.file.write_text(text)
    git(self.root, "add", NAME)
    git(self.root, "commit", "-q", "-m", "notes")

  def state(self):
    """state_of for the file."""

    return state_of(self.root, self.file)

  def test_state_of_a_committed_file_is_clean(self):
    self.commit("name: Notes\n")
    self.assertEqual(self.state(), "clean")

  def test_state_of_a_file_changed_in_the_working_tree_is_modified(self):
    self.commit("name: Notes\n")
    self.file.write_text("name: Field notes\n")
    self.assertEqual(self.state(), "modified")

  def test_state_of_a_file_with_a_staged_change_is_modified(self):
    self.commit("name: Notes\n")
    self.file.write_text("name: Field notes\n")
    git(self.root, "add", NAME)
    self.assertEqual(self.state(), "modified")

  def test_state_of_a_file_the_commit_does_not_have_is_new_staged_or_not(self):
    self.file.write_text("name: Notes\n")
    self.assertEqual(self.state(), "new")
    git(self.root, "add", NAME)
    self.assertEqual(self.state(), "new")

  def test_state_of_a_file_added_to_the_index_and_then_removed_is_deleted(self):
    self.file.write_text("name: Notes\n")
    git(self.root, "add", NAME)
    self.file.unlink()
    self.assertEqual(self.state(), "deleted")

  def test_state_of_a_committed_file_removed_from_the_working_tree_is_deleted(self):
    self.commit("name: Notes\n")
    self.file.unlink()
    self.assertEqual(self.state(), "deleted")

  def test_state_of_a_file_left_in_conflict_by_a_merge_is_conflict(self):
    self.commit("name: Notes\n")
    git(self.root, "switch", "-q", "-c", "other")
    self.commit("name: Theirs\n")
    git(self.root, "switch", "-q", "main")
    self.commit("name: Ours\n")
    merge_with_conflict(self.root, "other")
    self.assertEqual(self.state(), "conflict")

  def test_state_of_a_file_git_ignores_is_none(self):
    (self.root / ".gitignore").write_text(f"{NAME}\n")
    self.file.write_text("name: Notes\n")
    self.assertEqual(self.state(), "none")

  def test_state_of_a_file_that_is_not_there_and_never_was_is_none(self):
    self.assertEqual(self.state(), "none")

  def test_the_file_state_route_answers_the_root_the_path_and_the_state(self):
    self.commit("name: Notes\n")
    self.file.write_text("name: Field notes\n")
    answer = asyncio.run(route_module().file_state(root=str(self.root), path=str(self.file)))
    self.assertEqual(answer.model_dump(), {"root": str(self.root), "path": str(self.file), "state": "modified"})


class OutsideARepository(unittest.TestCase):
  def test_state_of_a_file_in_a_folder_with_no_repository_is_none(self):
    with tempfile.TemporaryDirectory() as scratch:
      file = Path(scratch) / NAME
      file.write_text("name: Notes\n")
      self.assertEqual(state_of(scratch, file), "none")


if __name__ == "__main__":
  unittest.main()
