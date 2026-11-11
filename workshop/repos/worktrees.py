"""The worktrees of a git repository, as `git worktree list --porcelain` lists them."""

from pathlib import Path

from ..run.git import git


def worktrees_of(root):
  """The worktrees of the repository root belongs to, main first, each as
  {root, name, branch, head, main, locked}. A bare main repository and a
  worktree whose folder is gone are left out; none at all when git cannot
  list them.

    worktrees_of("/home/someone/demo")  ->  [
      {"root": "/home/someone/demo", "name": "demo", "branch": "main", "head": "1a2b…", "main": True, "locked": False},
      {"root": "/home/someone/demo-fix", "name": "demo-fix", "branch": "fix/x", "head": "3c4d…", "main": False, "locked": False},
    ]
  """

  entries = records(git(root, "worktree", "list", "--porcelain"))
  return [worktree(entry, index == 0) for index, entry in enumerate(entries) if listed(entry)]


def records(text):
  """The entries of porcelain output: one dict per blank-line-separated block, each line's first word its key and the rest its value."""

  blocks = [block for block in text.split("\n\n") if block.strip()]
  return [dict(field(line) for line in block.splitlines()) for block in blocks]


def field(line):
  """One porcelain line as (key, value); a line with a key alone, such as `bare`, has an empty value."""

  key, _, value = line.partition(" ")
  return key, value


def listed(entry):
  """Whether the pane lists an entry: not a bare repository, and not a worktree whose folder is gone."""

  return "bare" not in entry and "prunable" not in entry


def worktree(entry, main):
  """One entry in the shape GET /repos answers, main when git listed it first."""

  return {
    "root": entry["worktree"],
    "name": Path(entry["worktree"]).name,
    "branch": entry.get("branch", "").removeprefix("refs/heads/"),
    "head": entry.get("HEAD", ""),
    "main": main,
    "locked": "locked" in entry,
  }
