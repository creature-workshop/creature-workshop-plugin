#!/usr/bin/env python3
"""A doc block at the top of every Python file and on every function and
class, and exactly one blank line after every docstring.

  docstrings.py FILE...

Prints one line per finding, `file:line: message`, and exits 1 when there is
any. The file's doc block is the module's docstring: the first statement of
the file, a string, with at least one word in it. A shebang or an encoding
comment above it is fine; a comment or code above it is not, because then it
is not the docstring. Every function and class carries a docstring too, as
every JavaScript function carries a JSDoc block, except in a test file
(test_*.py), where a test class, a `test_*` method and the setUp and
tearDown methods are named for what they do. After the module's docstring, and after the docstring
of every function and class, exactly one blank line separates it from the
code that follows, so the docstring reads as the thing's own and not as a
note on the first line of its body. A docstring with nothing after it needs
no blank line.
"""

import ast
import sys
from pathlib import Path

TEST_FIXTURE_METHODS = {"setUp", "tearDown", "setUpClass", "tearDownClass"}


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

  if not (ast.get_docstring(tree) or "").strip():
    return [f"{path}:1: this file has no doc block at its top, and every file opens with one. Add a docstring as the first statement, saying what the file is for."]

  return missing_findings(path, tree) + spacing_findings(path, source.splitlines(), tree)


def missing_findings(path, tree):
  """A finding for each function and class without a docstring that needs one."""

  return [missing_finding(path, node) for node in ast.walk(tree) if needs_docstring(path, node) and docstring_of(node) is None]


def missing_finding(path, node):
  """The finding for a function or class without a docstring."""

  return f"{path}:{node.lineno}: {node.name} has no docstring, and every function and class says what it does for its caller. Add one as the first statement of its body."


def needs_docstring(path, node):
  """Whether a node is a function or class that must carry a docstring: any, except the test classes and test methods of a test file."""

  if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
    return False

  return not (is_test_file(path) and is_test_part(node))


def is_test_file(path):
  """Whether a file is a test module, test_*.py."""

  return path.name.startswith("test_")


def is_test_part(node):
  """Whether a node in a test file is named for what it does: a class, a `test_*` method, or a setUp or tearDown method."""

  return isinstance(node, ast.ClassDef) or node.name.startswith("test_") or node.name in TEST_FIXTURE_METHODS


def spacing_findings(path, lines, tree):
  """A finding for each docstring, of the module or of any function or class, that
  the wrong number of blank lines follows."""

  findings = []
  for node in ast.walk(tree):
    docstring = docstring_of(node)
    if docstring is None or docstring is last_in(node):
      continue

    blanks = blank_lines_after(lines, docstring.end_lineno)
    if blanks != 1:
      findings.append(f"{path}:{docstring.end_lineno}: the docstring of {name_of(node)} is followed by {blanks} blank lines, and exactly one separates a docstring from the code after it. Leave one empty line after it.")

  return findings


def docstring_of(node):
  """The docstring statement of a module, function or class, or None."""

  body = getattr(node, "body", None)
  if not isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) or not body:
    return None

  first = body[0]
  if isinstance(first, ast.Expr) and isinstance(first.value, ast.Constant) and isinstance(first.value.value, str):
    return first

  return None


def last_in(node):
  """The last statement of the node's body."""

  return node.body[-1]


def blank_lines_after(lines, lineno):
  """How many blank lines follow the line, counted from the line after it."""

  count = 0
  for line in lines[lineno:]:
    if line.strip():
      break

    count += 1

  return count


def name_of(node):
  """What to call the node in a message: the module, or the function or class by name."""

  if isinstance(node, ast.Module):
    return "the module"

  return node.name


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
