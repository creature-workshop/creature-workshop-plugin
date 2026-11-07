#!/usr/bin/env python3
"""A module's constants come before its first function or class, and no comment draws a banner.

  declarations_first.py FILE...

Prints one line per finding, `file:line: message`, and exits 1 when there is
any. Both findings are the same sign: a constant declared in the middle of a
file, next to where it is used, or a banner comment such as `# ---- Helpers
----`, marks a part of the file as a separate unit that nothing enforces. The
language's way to separate code is a file, so the part should move into one.
"""

import ast
import re
import sys
import tokenize
from pathlib import Path

BANNER = re.compile(r"^#\s*[-=─—═_*#]{3,}|[-=─—═_*#]{3,}\s*$")


def main(paths):
  findings = []
  for path in paths:
    findings.extend(check_file(Path(path)))

  for finding in findings:
    print(finding)

  return exit_status(findings)


def exit_status(findings):
  """1 when there is a finding to report, 0 otherwise."""

  if findings:
    return 1

  return 0


def check_file(path):
  """The findings for one file, as `path:line: message` strings, in line order."""

  source = path.read_text()
  findings = late_assignments(path, ast.parse(source)) + banners(path, source)
  return sorted(findings, key=line_of)


def line_of(finding):
  """The line number a finding names, for sorting."""

  return int(finding.split(":")[1])


def late_assignments(path, module):
  """A finding for each top-level assignment that follows the first function or class."""

  findings = []
  first = None
  for statement in module.body:
    if first is None and isinstance(statement, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
      first = statement.name
    elif first is not None and isinstance(statement, (ast.Assign, ast.AnnAssign)):
      findings.append(f"{path}:{statement.lineno}: {names_of(statement)} is assigned after the first function of this file, and a file assigns its constants before its functions. Move it above {first}, or, if it belongs with the functions around it, give those their own file.")

  return findings


def names_of(statement):
  """The names an assignment binds, joined for a message."""

  targets = statement.targets if isinstance(statement, ast.Assign) else [statement.target]
  return ", ".join(ast.unparse(target) for target in targets)


def banners(path, source):
  """A finding for each comment that draws a line across the file."""

  findings = []
  for token in tokenize.generate_tokens(iter(source.splitlines(keepends=True)).__next__):
    if token.type == tokenize.COMMENT and BANNER.search(token.string):
      findings.append(f"{path}:{token.start[0]}: this comment draws a line across the file, which marks a part of it as a separate unit that nothing enforces. Delete the banner and move the part it labels into a file of its own, named for what the banner said.")

  return findings


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
