"""The repositories a set of checkouts belongs to: worktrees of one
repository, which share its git common directory, are one repository,
named for and rooted at its main worktree.
"""

from pathlib import Path

from workshop.repos.worktrees import worktrees_of
from workshop.run.git import git


def repositories(checkouts):
  """One {root, name, worktrees} per repository the checkouts belong to, in
  the order of the first checkout of each. The root is the main worktree's,
  or, for a bare main repository, the first linked worktree's; a checkout
  git cannot read stands alone, rooted at itself.

    repositories([Path("/code/demo-fix"), Path("/code/demo")])  ->  [{"root": "/code/demo", "name": "demo", "worktrees": [...]}]
  """

  found = {}
  for checkout in checkouts:
    key = common_dir(checkout) or str(checkout)
    if key not in found:
      found[key] = repository(checkout, key)

  return list(found.values())


def common_dir(checkout):
  """The absolute git common directory of a checkout, which its worktrees share, or "" when git cannot read it."""

  return git(checkout, "rev-parse", "--path-format=absolute", "--git-common-dir")


def repository(checkout, common):
  """The repository a checkout belongs to, given its git common directory."""

  worktrees = worktrees_of(checkout)
  main = next((each for each in worktrees if each["main"]), None)
  root = (main or (worktrees[0] if worktrees else {"root": str(checkout)}))["root"]
  return {"root": root, "name": name_of(main, common, checkout), "worktrees": worktrees}


def name_of(main, common, checkout):
  """The name the header shows: the main worktree's folder, else the bare repository's folder without .git, else the checkout's folder."""

  if main:
    return main["name"]

  if common.endswith(".git") and not common.endswith("/.git"):
    return Path(common).name.removesuffix(".git")

  return Path(checkout).name
