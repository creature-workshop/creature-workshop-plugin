"""Covers workshop.agent.context: what the agent reads about the project its
session is on, in the system prompt and at the start of each turn.

The folders are real ones in a scratch folder: `demo` and `site` are
repositories, and `demo` has a workshop that is set up. The picks are kept
in a scratch data folder.
"""

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests.python.workshop.test_project import make_project
from tests.python.workshop.test_repos import repo
from workshop.about import data
from workshop.selection import picking
from workshop.agent import context, session


class Scratch(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.TemporaryDirectory()
    self.root = Path(self.scratch.name).resolve()
    self.code = self.root / "code"
    self.demo = make_project(repo(self.code / "demo"))
    self.site = repo(self.code / "site")
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
    """Makes folder the directory the agent's session works in."""

    self.patch(session, "directory", str(folder))


class BeforeTurn(Scratch):
  def test_names_the_selected_project_and_says_the_tools_run_in_it(self):
    picking.select_repository("s1", self.code, self.demo)
    told = context.before_turn(session_id="s1", user_message="hello")["context"]
    self.assertIn(f'this session is on the workshop "Demo" at {self.demo}; it declares 2 tools', told)
    self.assertIn("The workshop_* tools run in it.", told)

  def test_follows_a_pick_made_after_the_session_started(self):
    picking.select_repository("s1", self.code, self.site)
    self.assertIn(f"{self.site}, doesn't have a workshop", context.before_turn(session_id="s1")["context"])
    picking.select_repository("s1", self.code, self.demo)
    self.assertIn(f"at {self.demo}", context.before_turn(session_id="s1")["context"])

  def test_a_checkout_with_a_workshop_and_no_shellops_of_its_own_is_on_the_workshop(self):
    (self.demo / "shell" / "ops").unlink()
    picking.select_repository("s1", self.code, self.demo)
    told = context.before_turn(session_id="s1")["context"]
    self.assertIn(f'this session is on the workshop "Demo" at {self.demo}', told)

  def test_says_that_nothing_is_selected_when_the_folder_holds_a_workshop(self):
    told = context.before_turn(session_id="s1")["context"]
    self.assertIn("No repository is selected for this session", told)
    self.assertIn("It holds 2 checkouts below it, and only the user selects one", told)

  def test_says_that_an_unapproved_project_needs_the_users_consent(self):
    picking.select_repository("s1", self.code, self.demo)
    with mock.patch.object(context, "is_approved", return_value=False):
      told = context.before_turn(session_id="s1")["context"]

    self.assertIn("has not been approved for execution yet", told)

  def test_says_nothing_in_a_folder_that_holds_no_workshop(self):
    self.work_in(self.site)
    self.assertIsNone(context.before_turn(session_id="s1"))
    notes = self.root / "notes"
    notes.mkdir()
    self.work_in(notes)
    self.assertIsNone(context.before_turn(session_id="s1"))


class PromptSection(Scratch):
  def test_says_what_the_tools_are_for_where_the_folder_holds_a_workshop(self):
    section = context.prompt_section({})
    self.assertIn("the workshop selected for this session", section)
    self.assertLessEqual(len(section), 800)

  def test_is_empty_in_a_folder_that_holds_no_workshop(self):
    self.work_in(self.site)
    self.assertEqual(context.prompt_section({}), "")


if __name__ == "__main__":
  unittest.main()
