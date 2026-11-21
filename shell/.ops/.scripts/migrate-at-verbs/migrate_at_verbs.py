#!/usr/bin/env python3
"""Rewrites every call of a structs value verb from the printing shape,
`x="$(@verb args)"`, to the register shape, `@verb x args`, over the shell
files of one repository, then reports what is left for a hand pass.

Run it once on a checkout:

  python3 .scripts/migrate-at-verbs/migrate_at_verbs.py <repository root>

The structs library itself is migrated by hand and is skipped. A repository
other than shellops names the shellops tree whose verbs it calls in
MIGRATE_SHELLOPS. `--file <path>...` migrates the files named and nothing
else, which is how a conflicted file is redone after a rebase. `--check`
reports what the run would change and writes nothing.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from leftovers import leftovers  # noqa: E402, the modules live beside this script
from repairs import repair
from rewriter import rewrite
from verbs import in_structs_library, shell_files, value_verbs


def main(arguments):
  root = arguments[0]
  verbs = value_verbs(os.environ.get("MIGRATE_SHELLOPS", root))
  if "--file" in arguments:
    migrate_files(arguments[arguments.index("--file") + 1:], verbs)
    return

  migrate_tree(root, verbs, check="--check" in arguments)
  report_leftovers(root, verbs)


def migrate_tree(root, verbs, check):
  """Migrates every shell file under root but the structs library, and prints how many rewrites it made."""

  total = 0
  for path in shell_files(root):
    if in_structs_library(root, path):
      continue

    rewrites, flagged = migrate_file(path, verbs, check)
    total += rewrites
    if check and rewrites:
      print(f"{os.path.relpath(path, root)}: {rewrites} rewrites, {len(flagged)} left for hand")

  print(f"rewrites: {total}")


def migrate_files(paths, verbs):
  """Migrates the files named, whatever they are, and prints each one's count."""

  for path in paths:
    rewrites, flagged = migrate_file(path, verbs, check=False)
    print(f"{path}: {rewrites} rewrites, {len(flagged)} left for hand")


def migrate_file(path, verbs, check):
  """(rewrites, lines left for hand) for one file, written back unless check is set."""

  with open(path) as source:
    text = source.read()

  rewritten, rewrites, flagged = rewrite(path, text, verbs)
  repaired = repair(rewritten, verbs)
  if repaired != text and not check:
    with open(path, "w") as target:
      target.write(repaired)

  return rewrites, flagged


def report_leftovers(root, verbs):
  for line in leftovers(root, verbs):
    print("  leftover:", line)


if __name__ == "__main__":
  main(sys.argv[1:])
