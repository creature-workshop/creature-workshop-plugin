"""Adopting a branch into shellops: what the pane suggests for its first
declaration, and writing that declaration.

With shellops bundled in the plugin, adopting a branch is writing
.ops/config/manifest.yaml: its name, description, command name, organization
and repository. The other declarations are optional to shellops and are not
written here. When the user asks, the file is committed on its own, so
nothing else in the working tree goes into the commit.
"""

import re
import subprocess
from pathlib import Path

from ..run.environment import child_env
from ..run.git import git
from .yaml_loader import dump_yaml

MANIFEST_PATH = ".ops/config/manifest.yaml"

COMMIT_MESSAGE = "chore: set up workshop files (.ops/)"

REMOTE_PATH = re.compile(r"[:/](?P<org>[^/:]+)/(?P<repo>[^/]+?)(?:\.git)?/?$")
"""The organization and repository at the end of a remote's URL, over https or ssh."""

TIMEOUT_SECONDS = 10


def suggestions(root):
  """What the pane fills the adoption form with for the checkout at root:
  the folder's name as the name, the repository from the origin remote's
  URL ("" when there is none), and the branch the checkout is on (""
  when detached). The organization is left to the user, since a remote's
  path names a group on a forge, which is not always the organization;
  the description and the command are the agent's to guess
  (workshop.project.guess).

    suggestions("/code/notes")  ->  {"name": "notes", "repo": "notes", "branch": "main"}
  """

  path = Path(root)
  _, repo = remote_parts(git(path, "remote", "get-url", "origin"))
  return {
    "name": path.name,
    "repo": repo,
    "branch": git(path, "symbolic-ref", "--short", "-q", "HEAD"),
  }


def remote_parts(url):
  """The organization and the repository a remote URL names, or ("", "") when it names neither.

    remote_parts("git@gitlab.example.com:someone/notes.git")    ->  ("someone", "notes")
    remote_parts("https://github.com/someone/notes")            ->  ("someone", "notes")
  """

  found = REMOTE_PATH.search(url)
  if found is None:
    return "", ""

  return found["org"], found["repo"]


def has_manifest(root):
  """Whether the checkout at root has a .ops/config/manifest.yaml."""

  return (Path(root) / MANIFEST_PATH).is_file()


def write_manifest(root, manifest):
  """Writes manifest, the declaration's values by key, to .ops/config/manifest.yaml under root."""

  path = Path(root) / MANIFEST_PATH
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(dump_yaml(manifest))


def commit_manifest(root):
  """Commits .ops/config/manifest.yaml alone, with COMMIT_MESSAGE, and
  returns git's error, or "" when the commit was made. Whatever else is
  staged stays staged and out of the commit."""

  for args in (["add", "--", MANIFEST_PATH], ["commit", "-m", COMMIT_MESSAGE, "--", MANIFEST_PATH]):
    failure = run_git(root, args)
    if failure:
      return failure

  return ""


def run_git(root, args):
  """Runs git with args at root and returns what it printed on failure, or "" when it succeeded."""

  try:
    done = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, timeout=TIMEOUT_SECONDS, env=child_env())
  except (OSError, subprocess.TimeoutExpired) as error:
    return str(error)

  if done.returncode != 0:
    return (done.stderr or done.stdout).strip() or f"git {args[0]} failed"

  return ""
