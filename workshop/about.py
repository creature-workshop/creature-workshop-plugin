"""What the plugin is, for the pane's footer: its version and the branch its checkout is on.

The version is `release.latest` of the plugin's own .ops/lock, the one the
release job writes. The branch is the one git has checked out at the
plugin's root, which is the worktree Hermes loads the plugin from: the
short commit when HEAD is detached, as a catalog install is, and empty
where the root is not in a git checkout at all.
"""

import subprocess

from workshop.project import release


def about(root):
  """The version and the branch of the plugin at root.

    about("/home/someone/.hermes/plugins/creature-workshop")  ->  {"version": "0.1.0-dev.9", "branch": "main"}
  """

  return {"version": release(root).get("latest", ""), "branch": branch_of(root)}


def branch_of(root):
  """The branch checked out at root, the short commit when HEAD is detached, "" outside git.

    branch_of(<a checkout on main>)  ->  "main"
    branch_of(<a checkout at a commit>)  ->  "5434e03"
    branch_of("/tmp")  ->  ""
  """

  name = git(root, "rev-parse", "--abbrev-ref", "HEAD")
  if name == "HEAD":
    return git(root, "rev-parse", "--short", "HEAD")

  return name


def git(root, *args):
  """What `git <args>` prints at root, stripped, or "" when git fails or is missing."""

  try:
    done = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, timeout=5)
  except (OSError, subprocess.TimeoutExpired):
    return ""

  if done.returncode != 0:
    return ""

  return done.stdout.strip()
