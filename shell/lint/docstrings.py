#!/usr/bin/env python3
"""A doc block at the top of every Python file, and exactly one blank line after every docstring.

  docstrings.py FILE...

Prints one line per finding, `file:line: message`, and exits 1 when there is
any. The file's doc block is the module's docstring: the first statement of
the file, a string, with at least one word in it. A shebang or an encoding
comment above it is fine; a comment or code above it is not, because then it
is not the docstring. After the module's docstring, and after the docstring
of every function and class, exactly one blank line separates it from the
code that follows, so the docstring reads as the thing's own and not as a
note on the first line of its body. A docstring with nothing after it needs
no blank line.
"""

import ast
import sys
from pathlib import Path


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
  """The findings for one file, as `path:line: message` strings."""

  source = path.read_text()
  try:
    tree = ast.parse(source, filename=str(path))
  except SyntaxError as error:
    return [f"{path}:{error.lineno}: cannot parse: {error.msg}"]

  if not (ast.get_docstring(tree) or "").strip():
    return [f"{path}:1: this file has no doc block at its top, and every file opens with one. Add a docstring as the first statement, saying what the file is for."]

  return spacing_findings(path, source.splitlines(), tree)


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
