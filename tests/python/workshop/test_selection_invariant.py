"""Holds the invariant that the pane and the agent are on the same checkout.

For one chat session, what the pane reads through GET /repos and GET
/selection and what the agent's side resolves through workshop.agent.session
are the same checkout in every case: nothing picked, a repository or a
worktree picked in the pane, a pick whose folder is gone, a folder inside a
repository or a linked worktree, a folder that holds one repository below
it, another session, and a chat whose session id changed when Hermes
compressed it. Only the user picks, in the pane: the agent has no tool that
changes what its session is on.

The repositories and worktrees are real ones in a scratch folder, the picks
are kept in a scratch data folder, and the agent's session directory is the
folder the pane asks about.
"""

import asyncio
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from fastapi import HTTPException

from tests.python.workshop.test_repos import git, repo
from workshop.about import data
from workshop.agent import context, session, tools
from workshop.routes import repos as repos_route, selection as route


def seen_by_pane(session_id, folder):
  """The root of the checkout GET /selection answers for the session and its folder, "" for none."""

  return asyncio.run(route.selection(session=session_id, path=str(folder))).selected


def listed_for_pane(session_id, folder):
  """The root of the checkout GET /repos answers for the session beside its repositories, "" for none."""

  return asyncio.run(repos_route.repos(path=str(folder), session=session_id)).selected


def picked_in_pane(session_id, folder, root):
  """Picks the repository at root the way the pane's repository selector does, through POST /selection."""

  body = route.SelectBody(session=session_id, path=str(folder), root=str(root))
  return asyncio.run(route.select(body)).selected


def worktree_picked_in_pane(session_id, folder, root):
  """Picks the worktree at root the way the pane's worktree selector does, through POST /selection/worktree."""

  body = route.SelectBody(session=session_id, path=str(folder), root=str(root))
  return asyncio.run(route.select_worktree(body)).selected


def seen_by_agent(session_id):
  """The root of the checkout the agent's tools, hook and context work from for the session, "" for none."""

  checkout = session.standing(session_id).checkout
  return str(checkout) if checkout else ""


class Scratch(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.TemporaryDirectory()
    self.root = Path(self.scratch.name).resolve()
    self.code = self.root / "code"
    self.alpha = repo(self.code / "alpha")
    self.beta = repo(self.code / "beta")
    self.patch(data, "data_dir", self.root / "data")
    self.work_in(self.code)

  def tearDown(self):
    self.scratch.cleanup()

  def patch(self, target, name, value):
    """Makes target.name answer value until the test ends."""

    patched = mock.patch.object(target, name, return_value=value)
    patched.start()
    self.addCleanup(patched.stop)

  def work_in(self, folder):
    """Makes folder the directory the agent's session works in, and the one the pane asks about."""

    self.folder = folder
    self.patch(session, "directory", str(folder))

  def worktree(self, repository, name):
    """A linked worktree of repository, on a branch of its own, in a folder beside the session's; its root."""

    path = self.root / "worktrees" / name
    git(repository, "worktree", "add", "-q", "-b", name, str(path))
    return path

  def assert_both_on(self, session_id, root):
    """The pane and the agent's side both name the checkout at root for the session, "" for none."""

    expected = str(root) if root else ""
    self.assertEqual(seen_by_pane(session_id, self.folder), expected)
    self.assertEqual(listed_for_pane(session_id, self.folder), expected)
    self.assertEqual(seen_by_agent(session_id), expected)


class OneAnswer(Scratch):
  def test_nothing_is_selected_among_several_repositories_until_one_is_picked(self):
    self.assert_both_on("s1", None)

  def test_a_pick_in_the_pane_is_what_the_agent_works_on(self):
    self.assertEqual(picked_in_pane("s1", self.code, self.beta), str(self.beta))
    self.assert_both_on("s1", self.beta)

  def test_the_agent_has_no_tool_that_changes_what_its_session_is_on(self):
    names = [schema["name"] for schema, _ in tools.registry()]
    self.assertEqual(names, ["workshop_project", "workshop_install", "workshop_test", "workshop_lint"])

  def test_the_later_worktree_picked_in_the_pane_is_where_the_agent_works(self):
    fix = self.worktree(self.alpha, "fix")
    self.work_in(self.alpha)
    worktree_picked_in_pane("s1", self.alpha, fix)
    self.assert_both_on("s1", fix)
    worktree_picked_in_pane("s1", self.alpha, self.alpha)
    self.assert_both_on("s1", self.alpha)

  def test_a_pick_whose_repository_is_gone_leaves_both_on_the_same_answer(self):
    gamma = repo(self.code / "gamma")
    picked_in_pane("s1", self.code, gamma)
    shutil.rmtree(gamma)
    self.assert_both_on("s1", None)

  def test_a_folder_inside_a_repository_has_it_selected_on_both_sides(self):
    self.work_in(self.alpha)
    self.assert_both_on("s1", self.alpha)

  def test_a_folder_that_holds_one_repository_below_it_has_none_on_both_sides_until_the_user_picks_it(self):
    shutil.rmtree(self.beta)
    self.assert_both_on("s1", None)
    picked_in_pane("s1", self.code, self.alpha)
    self.assert_both_on("s1", self.alpha)

  def test_a_folder_with_no_repository_has_none_on_both_sides(self):
    notes = self.root / "notes"
    notes.mkdir()
    self.work_in(notes)
    self.assert_both_on("s1", None)

  def test_a_worktree_picked_in_the_pane_is_where_the_agent_works(self):
    fix = self.worktree(self.alpha, "fix")
    self.assertEqual(worktree_picked_in_pane("s1", self.code, fix), str(fix))
    self.assert_both_on("s1", fix)

  def test_a_repository_picked_again_returns_both_sides_to_its_worktree(self):
    fix = self.worktree(self.alpha, "fix")
    worktree_picked_in_pane("s1", self.code, fix)
    picked_in_pane("s1", self.code, self.beta)
    self.assert_both_on("s1", self.beta)
    picked_in_pane("s1", self.code, self.alpha)
    self.assert_both_on("s1", fix)

  def test_a_picked_worktree_that_is_removed_leaves_both_on_the_main_one(self):
    fix = self.worktree(self.alpha, "fix")
    worktree_picked_in_pane("s1", self.code, fix)
    git(self.alpha, "worktree", "remove", str(fix))
    self.assert_both_on("s1", self.alpha)

  def test_a_folder_inside_a_linked_worktree_has_that_worktree_on_both_sides(self):
    fix = self.worktree(self.alpha, "fix")
    self.work_in(fix)
    self.assert_both_on("s1", fix)

  def test_another_session_in_the_same_folder_keeps_its_own(self):
    picked_in_pane("s1", self.code, self.alpha)
    picked_in_pane("s2", self.code, self.beta)
    self.assert_both_on("s1", self.alpha)
    self.assert_both_on("s2", self.beta)


class Refusals(Scratch):
  def test_the_pane_is_refused_a_folder_that_is_not_one_of_the_repositories(self):
    with self.assertRaises(HTTPException) as refused:
      picked_in_pane("s1", self.code, self.root / "elsewhere")

    self.assertEqual(refused.exception.status_code, 400)
    with self.assertRaises(HTTPException):
      worktree_picked_in_pane("s1", self.code, self.root / "elsewhere")

    self.assert_both_on("s1", None)


class AcrossCompression(Scratch):
  def test_the_pane_under_the_first_id_and_the_agent_under_the_new_one_are_on_the_same_repository(self):
    picked_in_pane("s1", self.code, self.beta)
    context.after_compaction(session_id="s2", old_session_id="s1", kind="summarize", reason="pre_api")
    self.assertEqual(seen_by_pane("s1", self.code), str(self.beta))
    self.assertEqual(seen_by_agent("s2"), str(self.beta))
    self.assert_both_on("s2", self.beta)

  def test_a_pick_under_either_id_reaches_the_other(self):
    context.after_compaction(session_id="s2", old_session_id="s1")
    picked_in_pane("s2", self.code, self.alpha)
    self.assert_both_on("s1", self.alpha)
    picked_in_pane("s1", self.code, self.beta)
    self.assert_both_on("s2", self.beta)

  def test_a_compaction_that_keeps_the_session_id_changes_nothing(self):
    picked_in_pane("s1", self.code, self.beta)
    context.after_compaction(session_id="s1", old_session_id="")
    self.assert_both_on("s1", self.beta)

  def test_a_subagent_is_on_its_parents_repository(self):
    picked_in_pane("s1", self.code, self.beta)
    context.on_subagent_start(parent_session_id="s1", child_session_id="child-1")
    self.assertEqual(seen_by_agent("child-1"), str(self.beta))


if __name__ == "__main__":
  unittest.main()
