"""Covers workshop.selection: which repository and which checkout a session is
on, how a pick is made and kept, and how the ids of one chat share their picks.

The repositories and worktrees are real ones made in a scratch folder, and
the picks are kept in a scratch data folder, so no test reads or writes the
user's own.
"""

import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests.python.workshop.test_repos import git, repo
from workshop.about import data
from workshop.selection import picking, picks, state

DEMO = {
  "root": "/code/demo",
  "name": "demo",
  "worktrees": [
    {"root": "/code/demo", "main": True},
    {"root": "/code/demo-fix", "main": False},
  ],
}


class Scratch(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.TemporaryDirectory()
    self.root = Path(self.scratch.name).resolve()
    self.code = self.root / "code"
    self.alpha = repo(self.code / "alpha")
    self.beta = repo(self.code / "beta")
    data = mock.patch.object(data, "data_dir", return_value=self.root / "data")
    data.start()
    self.addCleanup(data.stop)

  def tearDown(self):
    self.scratch.cleanup()

  def worktree(self, repository, name):
    """A linked worktree of repository, on a branch of its own, in a folder beside the session's; its root."""

    path = self.root / "worktrees" / name
    git(repository, "worktree", "add", "-q", "-b", name, str(path))
    return path

  def on(self, session_id, folder=None):
    """(repository, checkout) the session is on in folder, the scratch code folder when none is given."""

    now = state.state(session_id, folder or self.code)
    return now.repository, now.checkout


class ChosenCheckout(unittest.TestCase):
  def test_the_picked_worktree_while_it_is_listed(self):
    self.assertEqual(state.chosen_checkout(DEMO, "/code/demo-fix", ""), "/code/demo-fix")

  def test_the_worktree_the_folder_is_inside_without_a_pick(self):
    self.assertEqual(state.chosen_checkout(DEMO, "", "/code/demo-fix"), "/code/demo-fix")

  def test_a_pick_wins_over_the_worktree_the_folder_is_inside(self):
    self.assertEqual(state.chosen_checkout(DEMO, "/code/demo", "/code/demo-fix"), "/code/demo")

  def test_the_main_worktree_without_either(self):
    self.assertEqual(state.chosen_checkout(DEMO, "", ""), "/code/demo")

  def test_a_pick_that_is_no_longer_listed_is_ignored(self):
    self.assertEqual(state.chosen_checkout(DEMO, "/code/gone", ""), "/code/demo")

  def test_the_repository_itself_when_git_lists_no_worktrees(self):
    self.assertEqual(state.chosen_checkout({"root": "/code/notes", "worktrees": []}, "", ""), "/code/notes")


class State(Scratch):
  def test_a_folder_with_several_repositories_has_none_selected_until_one_is_picked(self):
    self.assertEqual(self.on("s1"), ("", ""))
    picking.select_repository("s1", self.code, self.beta)
    self.assertEqual(self.on("s1"), (str(self.beta), str(self.beta)))

  def test_a_folder_inside_a_repository_is_on_that_repository(self):
    (self.alpha / "src").mkdir()
    self.assertEqual(self.on("s1", self.alpha / "src"), (str(self.alpha), str(self.alpha)))
    self.assertEqual(state.selected("s1", self.alpha / "src"), self.alpha)

  def test_a_folder_inside_a_linked_worktree_is_on_that_worktree_of_its_repository(self):
    fix = self.worktree(self.alpha, "fix")
    self.assertEqual(self.on("s1", fix), (str(self.alpha), str(fix)))

  def test_a_folder_that_holds_one_repository_below_it_has_none_selected_until_it_is_picked(self):
    shutil.rmtree(self.beta)
    self.assertEqual(self.on("s1"), ("", ""))
    picking.select_repository("s1", self.code, self.alpha)
    self.assertEqual(self.on("s1"), (str(self.alpha), str(self.alpha)))

  def test_a_folder_that_holds_only_worktrees_of_one_repository_has_none_selected_until_it_is_picked(self):
    self.worktree(self.alpha, "one")
    self.worktree(self.alpha, "two")
    worktrees = self.root / "worktrees"
    self.assertEqual(self.on("s1", worktrees), ("", ""))
    picking.select_repository("s1", worktrees, self.alpha)
    self.assertEqual(self.on("s1", worktrees), (str(self.alpha), str(self.alpha)))

  def test_each_session_has_its_own_pick(self):
    picking.select_repository("s1", self.code, self.alpha)
    picking.select_repository("s2", self.code, self.beta)
    self.assertEqual(self.on("s1")[0], str(self.alpha))
    self.assertEqual(self.on("s2")[0], str(self.beta))

  def test_a_later_pick_replaces_an_earlier_one(self):
    picking.select_repository("s1", self.code, self.alpha)
    picking.select_repository("s1", self.code, self.beta)
    self.assertEqual(self.on("s1")[0], str(self.beta))

  def test_a_pick_whose_repository_is_deleted_is_ignored(self):
    gamma = repo(self.code / "gamma")
    picking.select_repository("s1", self.code, gamma)
    shutil.rmtree(gamma)
    self.assertEqual(self.on("s1"), ("", ""))

  def test_a_pick_does_not_follow_the_session_to_another_folder(self):
    picking.select_repository("s1", self.code, self.beta)
    notes = self.root / "notes"
    notes.mkdir()
    self.assertEqual(self.on("s1", notes), ("", ""))

  def test_without_a_folder_nothing_is_selected(self):
    self.assertEqual(state.state("s1", ""), state.Selection())
    self.assertIsNone(state.selected("s1", ""))

  def test_the_state_lists_the_checkouts_the_folder_holds(self):
    self.assertEqual(state.state("s1", self.code).checkouts, (str(self.alpha), str(self.beta)))


class SelectWorktree(Scratch):
  def test_picks_the_worktree_and_the_repository_it_belongs_to(self):
    fix = self.worktree(self.alpha, "fix")
    now = picking.select_worktree("s1", self.code, fix)
    self.assertEqual((now.repository, now.checkout), (str(self.alpha), str(fix)))
    self.assertEqual(self.on("s1"), (str(self.alpha), str(fix)))

  def test_a_repository_keeps_its_worktree_while_the_session_is_on_another(self):
    fix = self.worktree(self.alpha, "fix")
    picking.select_worktree("s1", self.code, fix)
    picking.select_repository("s1", self.code, self.beta)
    self.assertEqual(self.on("s1"), (str(self.beta), str(self.beta)))
    picking.select_repository("s1", self.code, self.alpha)
    self.assertEqual(self.on("s1"), (str(self.alpha), str(fix)))

  def test_picking_the_main_worktree_leaves_a_linked_one(self):
    fix = self.worktree(self.alpha, "fix")
    picking.select_worktree("s1", self.code, fix)
    picking.select_worktree("s1", self.code, self.alpha)
    self.assertEqual(self.on("s1"), (str(self.alpha), str(self.alpha)))

  def test_a_picked_worktree_that_is_removed_falls_back_to_the_main_one(self):
    fix = self.worktree(self.alpha, "fix")
    picking.select_worktree("s1", self.code, fix)
    git(self.alpha, "worktree", "remove", str(fix))
    self.assertEqual(self.on("s1"), (str(self.alpha), str(self.alpha)))

  def test_answers_however_the_root_was_written(self):
    written = f"{self.code}/alpha/../beta/"
    self.assertEqual(picking.select_worktree("s1", self.code, written).checkout, str(self.beta))

  def test_refuses_a_folder_inside_a_worktree_that_is_not_its_root(self):
    (self.alpha / "src").mkdir()
    with self.assertRaises(picking.NotSelectable):
      picking.select_worktree("s1", self.code, self.alpha / "src")

  def test_refuses_a_worktree_of_a_repository_the_folder_holds_no_checkout_of(self):
    outside = repo(self.root / "outside")
    with self.assertRaises(picking.NotSelectable) as refused:
      picking.select_worktree("s1", self.code, outside)

    self.assertIn("is not a worktree of a repository that the session's folder", str(refused.exception))
    self.assertEqual(self.on("s1"), ("", ""))


class SelectRepository(Scratch):
  def test_refuses_a_folder_that_is_not_a_repository(self):
    with self.assertRaises(picking.NotSelectable) as refused:
      picking.select_repository("s1", self.code, self.root / "elsewhere")

    self.assertIn("is not the root of a repository that the session's folder", str(refused.exception))
    self.assertEqual(self.on("s1"), ("", ""))

  def test_refuses_a_linked_worktree_which_is_not_a_repositorys_root(self):
    fix = self.worktree(self.alpha, "fix")
    with self.assertRaises(picking.NotSelectable):
      picking.select_repository("s1", self.code, fix)

  def test_refuses_without_a_session_or_without_a_root(self):
    with self.assertRaises(picking.NotSelectable) as refused:
      picking.select_repository("", self.code, self.alpha)

    self.assertIn("no chat session", str(refused.exception))
    with self.assertRaises(picking.NotSelectable):
      picking.select_repository("s1", self.code, "")

  def test_tells_the_panes_that_the_selection_changed(self):
    with mock.patch.object(picking, "announce") as announce:
      picking.select_repository("s1", self.code, self.alpha)

    announce.assert_called_once_with("s1")


class Repositories(Scratch):
  def test_lists_each_repository_with_its_worktrees_as_the_pane_lists_them(self):
    fix = self.worktree(self.alpha, "fix")
    listed = state.repositories(self.code)
    self.assertEqual([each["root"] for each in listed], [str(self.alpha), str(self.beta)])
    self.assertEqual([each["root"] for each in listed[0]["worktrees"]], [str(self.alpha), str(fix)])

  def test_none_without_a_folder(self):
    self.assertEqual(state.repositories(""), [])


class Continued(Scratch):
  def test_an_id_that_continues_a_chat_reads_its_picks(self):
    fix = self.worktree(self.alpha, "fix")
    picking.select_worktree("s1", self.code, fix)
    picks.continued("s2", "s1")
    self.assertEqual(self.on("s2"), (str(self.alpha), str(fix)))

  def test_a_pick_made_under_either_id_is_read_under_both(self):
    picks.continued("s2", "s1")
    picking.select_repository("s2", self.code, self.alpha)
    self.assertEqual(self.on("s1")[0], str(self.alpha))
    picking.select_repository("s1", self.code, self.beta)
    self.assertEqual(self.on("s2")[0], str(self.beta))

  def test_a_chat_compressed_twice_is_still_one_chat(self):
    picking.select_repository("s1", self.code, self.beta)
    picks.continued("s2", "s1")
    picks.continued("s3", "s2")
    self.assertEqual(picks.chat_of("s3"), "s1")
    self.assertEqual(self.on("s3")[0], str(self.beta))

  def test_picks_made_under_the_new_id_before_the_link_become_the_chats_picks(self):
    fix = self.worktree(self.beta, "fix")
    picking.select_repository("s1", self.code, self.alpha)
    picking.select_worktree("s2", self.code, fix)
    picks.continued("s2", "s1")
    self.assertEqual(self.on("s1"), (str(self.beta), str(fix)))

  def test_a_link_that_would_make_a_chat_continue_itself_is_not_recorded(self):
    picks.continued("s2", "s1")
    picks.continued("s1", "s2")
    self.assertEqual(picks.chat_of("s1"), "s1")
    self.assertEqual(picks.chat_of("s2"), "s1")

  def test_an_empty_id_links_nothing(self):
    picks.continued("s2", "")
    picks.continued("", "s1")
    self.assertEqual(picks.chat_of("s2"), "s2")


class Files(Scratch):
  def test_a_session_id_with_any_characters_keeps_its_pick_inside_the_data_folder(self):
    picking.select_repository("../../etc/passwd", self.code, self.alpha)
    kept = sorted((self.root / "data" / "selection").iterdir())
    self.assertEqual(len(kept), 1)
    self.assertEqual(self.on("../../etc/passwd")[0], str(self.alpha))


if __name__ == "__main__":
  unittest.main()
