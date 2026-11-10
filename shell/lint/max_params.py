#!/usr/bin/env python3
"""No function takes more than five parameters.

  max_params.py FILE...

Prints one line per finding, `file:line: message`, and exits 1 when there is
any. A method's `self` or `cls` is not counted. `*args` and `**kwargs` each
count as one. Past five, the parameters that travel together belong in one
object, such as a dataclass, or in `*args` or `**kwargs`.
"""

import ast
import sys
from pathlib import Path

MAX_PARAMS = 5
RECEIVERS = ("self", "cls")


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
  """The findings for one file, as `path:line: message` strings, in line order."""

  functions = [node for node in ast.walk(ast.parse(path.read_text())) if is_function(node)]
  findings = [finding(path, node) for node in functions if count_of(node) > MAX_PARAMS]
  return sorted(findings, key=line_of)


def is_function(node):
  """True for a function, an async function or a lambda."""

  return isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda))


def count_of(function):
  """How many parameters function takes, leaving out a leading self or cls, with *args and **kwargs as one each."""

  arguments = function.args
  named = arguments.posonlyargs + arguments.args + arguments.kwonlyargs
  if named and named[0].arg in RECEIVERS:
    named = named[1:]

  return len(named) + (arguments.vararg is not None) + (arguments.kwarg is not None)


def finding(path, function):
  """The finding for a function that takes too many parameters."""

  name = getattr(function, "name", "this lambda")
  count = count_of(function)
  return (
    f"{path}:{function.lineno}: {name} takes {count} parameters, and a function takes at most {MAX_PARAMS}. "
    "Gather the parameters that travel together into one object, such as a dataclass, or take *args or **kwargs."
  )


def line_of(finding):
  """The line number a finding names, for sorting."""

  return int(finding.split(":")[1])


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
