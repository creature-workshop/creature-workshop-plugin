#!/usr/bin/env python3
"""A doc block at the top of every Python file, after the shebang when there is one.

  module_docstring.py FILE...

Prints one line per file that lacks one, `file:1: message`, and exits 1 when
there is any. The doc block is the module's docstring: the first statement of
the file, a string, with at least one word in it. A shebang or an encoding
comment above it is fine; a comment or code above it is not, because then it
is not the docstring.
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

  return 1 if findings else 0


def check_file(path):
  """The findings for one file, as `path:line: message` strings."""
  source = path.read_text()
  try:
    tree = ast.parse(source, filename=str(path))
  except SyntaxError as error:
    return [f"{path}:{error.lineno}: cannot parse: {error.msg}"]

  if not (ast.get_docstring(tree) or "").strip():
    return [f"{path}:1: a doc block at the top of the file, saying what it is for"]

  return []


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
