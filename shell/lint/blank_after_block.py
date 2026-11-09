#!/usr/bin/env python3
"""Exactly one blank line after every statement that spans more than one line, when another statement follows.

  blank_after_block.py FILE...

Prints one line per finding, `file:line: message`, and exits 1 when there is
any. An if chain, a loop, a with or try block, and a multi-line assignment,
call or return all count: a statement that ends its block needs nothing after
it, and one followed by a statement in the same block needs one blank line
between its last line and the next line of code. A comment between the two
counts as code: the blank line goes before the comment.

Two statements are left to PEP 8: a function or class definition, which takes
two blank lines at module level, and a docstring, which the code follows at
once. When the next statement is a definition, one blank line or two is
accepted, so a module-level constant that spans lines can sit above a def.
"""

import ast
import sys
from pathlib import Path

BODY_FIELDS = ("body", "orelse", "finalbody", "handlers")
DEFINITIONS = (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)


def main(paths):
  """Prints the findings for every file named, and gives the exit status: 1 when there is any."""

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
  """The findings for one file, as `path:line: message` strings."""

  source = path.read_text()
  try:
    tree = ast.parse(source, filename=str(path))
  except SyntaxError as error:
    return [f"{path}:{error.lineno}: cannot parse: {error.msg}"]

  lines = source.splitlines()
  return [f"{path}:{line}: {message}" for line, message in findings_in(tree, lines)]


def findings_in(tree, lines):
  """(line, message) for every multi-line statement in the tree that the rule rejects."""

  found = []
  for body in statement_lists(tree):
    for statement, following in zip(body, body[1:]):
      if spans_lines(statement):
        found.extend(check_gap(statement, following, lines))

  return found


def statement_lists(tree):
  """Every list of statements in the tree: the module's, each function's, each branch's."""

  for node in ast.walk(tree):
    for field in BODY_FIELDS:
      value = getattr(node, field, None)
      if isinstance(value, list) and value and isinstance(value[0], ast.stmt):
        yield value


def spans_lines(statement):
  """Whether the statement takes more than one line and is one the rule covers."""

  if isinstance(statement, DEFINITIONS) or docstring(statement):
    return False

  return statement.end_lineno > statement.lineno


def docstring(statement):
  """Whether a statement is a docstring: an expression that is only a string."""

  return isinstance(statement, ast.Expr) and isinstance(statement.value, ast.Constant) and isinstance(statement.value.value, str)


def check_gap(statement, following, lines):
  """The finding for the gap between a multi-line statement and the statement after it, if any."""

  blank = blank_lines_after(statement.end_lineno, lines)
  if blank == 1 or (blank == 2 and isinstance(following, DEFINITIONS)):
    return []

  if blank == 0:
    return [(statement.end_lineno, "one blank line after this multi-line statement, before the next statement")]

  return [(statement.end_lineno, f"one blank line after this multi-line statement, not {blank}")]


def blank_lines_after(line_number, lines):
  """How many whitespace-only lines follow the line at line_number (1-based)."""

  count = 0
  for line in lines[line_number:]:
    if line.strip():
      break

    count += 1

  return count


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
