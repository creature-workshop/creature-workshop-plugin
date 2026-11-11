"""Covers workshop.consent: only the user approves a project, by listing its
root in the approved_projects setting, and the agent has no tool and no route
that approves one.

The project is a real one in a scratch folder, in a repository of its own.
`approving` is how every test suite approves a project: it stands in for
Hermes's configuration with the setting filled.
"""

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests.python.workshop.test_project import make_project
from tests.python.workshop.test_repos import repo
from workshop import consent, settings
from workshop.agent import session, tools
from workshop.agent.schemas import INSTALL_SCHEMA


def approving(*roots):
  """A patch of Hermes's configuration in which the approved_projects setting
  lists roots. Use it as a context manager, or start it and stop it.

    with approving(root):
      ops.run(root, ["lint"])
  """

  entry = {"settings": {"approved_projects": [str(root) for root in roots]}}
  return mock.patch.object(settings, "hermes_config", return_value={"plugins": {"entries": {settings.PLUGIN_ID: entry}}})


class Scratch(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.TemporaryDirectory()
    self.addCleanup(self.scratch.cleanup)
    self.top = Path(self.scratch.name).resolve()
    self.root = make_project(repo(self.top / "demo"))
    directory = mock.patch.object(session, "directory", return_value=str(self.root))
    directory.start()
    self.addCleanup(directory.stop)


class IsApproved(Scratch):
  def test_no_project_is_approved_until_the_user_lists_one(self):
    self.assertFalse(consent.is_approved(self.root))

  def test_a_project_the_setting_lists_is_approved(self):
    with approving(self.root):
      self.assertTrue(consent.is_approved(self.root))

  def test_the_setting_approves_only_the_roots_it_lists(self):
    with approving(self.top / "other"):
      self.assertFalse(consent.is_approved(self.root))

  def test_a_folder_inside_a_listed_project_is_not_approved_by_it(self):
    with approving(self.root):
      self.assertFalse(consent.is_approved(self.root / "shell"))

  def test_a_root_is_approved_however_the_setting_writes_its_path(self):
    with approving(f"{self.root}/", self.top / "demo" / ".." / "demo"):
      self.assertTrue(consent.is_approved(self.root))


class ListedProjects(unittest.TestCase):
  def test_each_entry_is_an_absolute_path_without_a_trailing_slash(self):
    with tempfile.TemporaryDirectory() as tmp:
      top = Path(tmp).resolve()
      self.assertEqual(consent.listed_projects([f"{top}/demo/", f"{top}/demo/../site"]), {f"{top}/demo", f"{top}/site"})

  def test_an_entry_that_is_not_text_is_left_out(self):
    self.assertEqual(consent.listed_projects([7, None, "", "  "]), frozenset())

  def test_a_setting_that_is_not_a_list_lists_nothing(self):
    self.assertEqual(consent.listed_projects("/home/someone/demo"), frozenset())


class RequireConsent(Scratch):
  def test_is_none_for_an_approved_project(self):
    with approving(self.root):
      self.assertIsNone(consent.require_consent(self.root))

  def test_tells_the_agent_that_only_the_user_can_approve_the_project(self):
    denial = consent.require_consent(self.root)
    self.assertIn(f"{self.root} has not been approved for execution", denial)
    self.assertIn("Only the user can approve it", denial)
    self.assertIn("approved_projects", denial)
    self.assertIn("do not change that setting yourself", denial)
    self.assertNotIn("approve: true", denial)


class AgentTools(Scratch):
  def test_workshop_install_has_no_argument_that_approves_a_project(self):
    self.assertNotIn("approve", INSTALL_SCHEMA["parameters"]["properties"])
    self.assertNotIn("approve: true", INSTALL_SCHEMA["description"])

  def test_workshop_install_does_not_approve_a_project_when_the_call_says_approve(self):
    answer = json.loads(tools.workshop_install({"approve": True}))
    self.assertFalse(answer["ok"])
    self.assertIn("has not been approved for execution", answer["error"])
    self.assertFalse(consent.is_approved(self.root))

  def test_every_tool_runs_nothing_in_an_unapproved_project(self):
    (self.root / "shell" / "ops").write_text("#!/bin/sh\ntouch ran\n")
    (self.root / "shell" / "ops").chmod(0o755)
    for tool in (tools.workshop_project, tools.workshop_install, tools.workshop_test, tools.workshop_lint):
      json.loads(tool({}))

    self.assertFalse((self.root / "ran").exists())

  def test_a_tool_runs_in_a_project_the_setting_lists(self):
    (self.root / "shell" / "ops").write_text("#!/bin/sh\ntouch ran\n")
    (self.root / "shell" / "ops").chmod(0o755)
    with approving(self.root):
      json.loads(tools.workshop_lint({}))

    self.assertTrue((self.root / "ran").exists())


if __name__ == "__main__":
  unittest.main()
