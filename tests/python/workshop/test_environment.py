"""Covers workshop.run.environment, and that ops, git and status start their programs in the environment it gives."""

import os
import tempfile
import unittest
from unittest import mock

from workshop.repos import status
from workshop.run import environment, git, ops

HERMES_ENVIRON = {
  "PATH": "/usr/bin:/bin",
  "HOME": "/home/someone",
  "LANG": "en_US.UTF-8",
  "LC_ALL": "C",
  "TERM": "xterm",
  "OPENAI_API_KEY": "sk-secret",
  "GITHUB_TOKEN": "ghp-secret",
  "HERMES_HOME": "/home/someone/.hermes",
  "SSH_AUTH_SOCK": "/run/user/1000/ssh-agent",
  "SHELLOPS_DIR": "/home/someone/other/shell/.ops",
  "PROJ": "/home/someone/other",
  "HTTPS_PROXY": "http://proxy:3128",
}

INHERITED = {"PATH", "HOME", "LANG", "LC_ALL", "TERM"}

SECRET = {"OPENAI_API_KEY": "sk-secret"}


class Inherited(unittest.TestCase):
  def test_inherited_keeps_only_the_listed_variables_and_the_locale(self):
    self.assertEqual(set(environment.inherited(HERMES_ENVIRON)), INHERITED)

  def test_inherited_keeps_each_value_as_it_was(self):
    self.assertEqual(environment.inherited(HERMES_ENVIRON)["HOME"], "/home/someone")

  def test_inherited_keeps_a_variable_the_passthrough_names(self):
    kept = environment.inherited(HERMES_ENVIRON, frozenset(["HTTPS_PROXY"]))
    self.assertEqual(set(kept), INHERITED | {"HTTPS_PROXY"})

  def test_inherited_adds_nothing_for_a_passthrough_name_that_is_not_set(self):
    kept = environment.inherited(HERMES_ENVIRON, frozenset(["NO_PROXY"]))
    self.assertEqual(set(kept), INHERITED)


class PassthroughNames(unittest.TestCase):
  def test_passthrough_names_keeps_the_variable_names_of_a_list(self):
    self.assertEqual(environment.passthrough_names(["HTTPS_PROXY", "NO_PROXY"]), frozenset(["HTTPS_PROXY", "NO_PROXY"]))

  def test_passthrough_names_leaves_out_an_entry_that_is_not_a_variable_name(self):
    self.assertEqual(environment.passthrough_names(["HTTPS_PROXY", "not a name", "A=b", 7, ""]), frozenset(["HTTPS_PROXY"]))

  def test_passthrough_names_is_empty_when_the_setting_is_not_a_list(self):
    self.assertEqual(environment.passthrough_names("HTTPS_PROXY"), frozenset())


class ChildEnv(unittest.TestCase):
  def test_child_env_is_the_inherited_part_of_this_process_when_the_setting_is_empty(self):
    with mock.patch.dict(os.environ, HERMES_ENVIRON, clear=True):
      self.assertEqual(set(environment.child_env()), INHERITED)

  def test_child_env_adds_the_variables_the_setting_names(self):
    with mock.patch.dict(os.environ, HERMES_ENVIRON, clear=True):
      with mock.patch.object(environment.settings, "value", return_value=["HTTPS_PROXY"]):
        self.assertEqual(set(environment.child_env()), INHERITED | {"HTTPS_PROXY"})


class Programs(unittest.TestCase):
  def test_ops_dispatch_runs_its_command_without_a_secret_of_this_process(self):
    with tempfile.TemporaryDirectory() as tmp:
      with mock.patch.dict(os.environ, SECRET):
        printed = ops.dispatch(tmp, ["env"], 10).stdout

    self.assertIn("PATH=", printed)
    self.assertNotIn("OPENAI_API_KEY", printed)

  def test_git_starts_git_without_a_secret_of_this_process(self):
    with mock.patch.dict(os.environ, SECRET):
      with mock.patch.object(git.subprocess, "run") as run:
        git.git("/home/someone/demo", "rev-parse", "HEAD")

    self.assertIn("PATH", run.call_args.kwargs["env"])
    self.assertNotIn("OPENAI_API_KEY", run.call_args.kwargs["env"])

  def test_status_of_starts_the_status_action_without_a_secret_of_this_process(self):
    with mock.patch.dict(os.environ, SECRET):
      with mock.patch.object(status.subprocess, "run") as run:
        run.return_value.returncode = 1
        status.status_of("/home/someone/demo")

    self.assertIn("PATH", run.call_args.kwargs["env"])
    self.assertNotIn("OPENAI_API_KEY", run.call_args.kwargs["env"])


if __name__ == "__main__":
  unittest.main()
