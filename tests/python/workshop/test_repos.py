"""Covers workshop.repos and workshop.repo_status over real repositories made in a scratch folder:
which repositories a directory holds, and the prompt-style state of one."""

import subprocess
import tempfile
import unittest
from pathlib import Path

from workshop.repo_status import status_of
from workshop.repos import repos_of


def git_command(root, *args):
  """The git command line that runs args at root with the tests' own identity and default branch, so no user or CI config is needed."""

  return ["git", "-C", str(root), "-c", "user.name=t", "-c", "user.email=t@t", "-c", "init.defaultBranch=main", *args]


def git(root, *args):
  """Runs git at root for the tests, quietly, and returns what it printed."""

  return subprocess.run(git_command(root, *args), capture_output=True, text=True, check=True).stdout.strip()


def merge_with_conflict(root, branch):
  """Merges branch into the branch checked out at root, where the merge stops on a conflict, so its failing exit status is expected."""

  subprocess.run(git_command(root, "merge", "-q", branch), capture_output=True)


def repo(path):
  """A repository at path with one commit on main, and path."""

  path.mkdir(parents=True, exist_ok=True)
  git(path, "init", "-q")
  git(path, "commit", "-q", "--allow-empty", "-m", "first")
  return path


class Scratch(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.TemporaryDirectory()
    self.root = Path(self.scratch.name).resolve()

  def tearDown(self):
    self.scratch.cleanup()


class ReposOf(Scratch):
  def test_a_folder_with_no_repository_holds_none(self):
    (self.root / "notes").mkdir()
    self.assertEqual(repos_of(self.root), (False, []))

  def test_a_directory_inside_a_repository_holds_that_one(self):
    demo = repo(self.root / "demo")
    (demo / "src").mkdir()
    self.assertEqual(repos_of(demo / "src"), (True, [demo]))

  def test_a_folder_holds_the_repositories_below_it_sorted(self):
    b = repo(self.root / "b")
    a = repo(self.root / "group" / "a")
    self.assertEqual(repos_of(self.root), (False, [b, a]))

  def test_the_search_does_not_go_inside_a_repository(self):
    outer = repo(self.root / "outer")
    repo(outer / "vendor" / "inner")
    self.assertEqual(repos_of(self.root), (False, [outer]))

  def test_hidden_folders_and_node_modules_are_not_searched(self):
    shown = repo(self.root / "shown")
    repo(self.root / ".worktrees" / "hidden")
    repo(self.root / "node_modules" / "dependency")
    self.assertEqual(repos_of(self.root), (False, [shown]))

  def test_the_search_stops_three_levels_down(self):
    near = repo(self.root / "one" / "two" / "three")
    repo(self.root / "one" / "two" / "x" / "four")
    self.assertEqual(repos_of(self.root), (False, [near]))

  def test_a_linked_worktree_counts_as_a_repository(self):
    main = repo(self.root / "main")
    git(main, "worktree", "add", "-q", str(self.root / "linked"))
    self.assertEqual(repos_of(self.root), (False, [self.root / "linked", main]))


class StatusOf(Scratch):
  def test_a_clean_repository_on_main_without_an_upstream(self):
    demo = repo(self.root / "demo")
    self.assertEqual(status_of(demo), {
      "branch": "main", "detached": False, "upstream": False, "ahead": 0, "behind": 0,
      "staged": 0, "modified": 0, "untracked": 0, "conflicted": 0,
    })

  def test_counts_staged_modified_and_untracked_paths(self):
    demo = repo(self.root / "demo")
    (demo / "a.txt").write_text("a\n")
    (demo / "b.txt").write_text("b\n")
    git(demo, "add", "a.txt", "b.txt")
    git(demo, "commit", "-q", "-m", "files")
    (demo / "a.txt").write_text("a changed\n")
    git(demo, "add", "a.txt")
    (demo / "a.txt").write_text("a changed again\n")
    (demo / "b.txt").write_text("b changed\n")
    (demo / "new.txt").write_text("new\n")
    state = status_of(demo)
    self.assertEqual((state["staged"], state["modified"], state["untracked"]), (1, 2, 1))

  def test_ahead_and_behind_its_upstream(self):
    origin = repo(self.root / "origin")
    git(self.root, "clone", "-q", str(origin), "clone")
    clone = self.root / "clone"
    git(origin, "commit", "-q", "--allow-empty", "-m", "theirs")
    git(clone, "fetch", "-q")
    git(clone, "commit", "-q", "--allow-empty", "-m", "ours one")
    git(clone, "commit", "-q", "--allow-empty", "-m", "ours two")
    state = status_of(clone)
    self.assertEqual((state["upstream"], state["ahead"], state["behind"]), (True, 2, 1))

  def test_a_detached_head_shows_the_short_commit(self):
    demo = repo(self.root / "demo")
    git(demo, "checkout", "-q", "--detach")
    state = status_of(demo)
    self.assertTrue(state["detached"])
    self.assertEqual(state["branch"], git(demo, "rev-parse", "HEAD")[:7])

  def test_a_merge_conflict_counts_as_conflicted(self):
    demo = repo(self.root / "demo")
    (demo / "f.txt").write_text("base\n")
    git(demo, "add", "f.txt")
    git(demo, "commit", "-q", "-m", "base")
    git(demo, "checkout", "-q", "-b", "other")
    (demo / "f.txt").write_text("other\n")
    git(demo, "commit", "-q", "-am", "other")
    git(demo, "checkout", "-q", "main")
    (demo / "f.txt").write_text("main\n")
    git(demo, "commit", "-q", "-am", "main")
    merge_with_conflict(demo, "other")
    self.assertEqual(status_of(demo)["conflicted"], 1)

  def test_none_outside_a_repository(self):
    self.assertIsNone(status_of(self.root))


  def test_a_renamed_path_counts_as_staged(self):
    demo = repo(self.root / "demo")
    (demo / "old.txt").write_text("text\n")
    git(demo, "add", "old.txt")
    git(demo, "commit", "-q", "-m", "old")
    git(demo, "mv", "old.txt", "new.txt")
    state = status_of(demo)
    self.assertEqual((state["staged"], state["modified"], state["untracked"]), (1, 0, 0))

  def test_a_branch_name_with_a_double_quote_reads_back_whole(self):
    demo = repo(self.root / "demo")
    git(demo, "checkout", "-q", "-b", 'say"hi')
    self.assertEqual(status_of(demo)["branch"], 'say"hi')

  def test_a_repository_with_no_commits_is_on_its_branch(self):
    empty = self.root / "empty"
    empty.mkdir()
    git(empty, "init", "-q")
    state = status_of(empty)
    self.assertEqual((state["branch"], state["detached"], state["upstream"]), ("main", False, False))


if __name__ == "__main__":
  unittest.main()
