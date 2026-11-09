"""The git repositories a session holds, found from its directory.

A session's directory inside a repository holds that one repository. A
directory inside none holds every repository below it, up to DEPTH levels
down: a folder with a .git entry (a directory, or the file a linked worktree
or a submodule has) is a repository, and the search does not go inside one,
so a repository's submodules and nested checkouts are not listed beside it.
Hidden folders and the folders in SKIPPED are not searched, and symbolic
links are not followed.
"""

import os
from pathlib import Path

from workshop.git import git

DEPTH = 3

SKIPPED = frozenset({"node_modules"})


def repos_of(start):
  """(inside, roots): whether start is inside a repository, and the roots of the repositories it holds, sorted.

    repos_of("/home/someone/demo/src")  ->  (True, [Path("/home/someone/demo")])
    repos_of("/home/someone/code")  ->  (False, [Path("/home/someone/code/a"), Path("/home/someone/code/b")])
  """

  top = git(start, "rev-parse", "--show-toplevel")
  if top:
    return True, [Path(top)]

  return False, sorted(repos_below(Path(start), DEPTH))


def repos_below(path, depth):
  """The repositories in the folders under path, searching depth levels down."""

  if depth == 0:
    return []

  found = []
  for child in searchable_children(path):
    found.extend([child] if is_repo(child) else repos_below(child, depth - 1))

  return found


def searchable_children(path):
  """The folders directly under path that the search looks at: not hidden, not skipped, not links."""

  try:
    entries = list(os.scandir(path))
  except OSError:
    return []

  return [Path(entry.path) for entry in entries if is_searchable(entry)]


def is_searchable(entry):
  """Whether a directory entry is a folder the search looks at."""

  return entry.is_dir(follow_symlinks=False) and not entry.name.startswith(".") and entry.name not in SKIPPED


def is_repo(path):
  """Whether path is the root of a git repository: it has a .git directory or file."""

  return (path / ".git").exists()
