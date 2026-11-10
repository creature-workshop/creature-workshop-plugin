#!/usr/bin/env python3
"""Every YAML read goes through load_yaml in workshop/project/declaration.py.

  yaml_imports.py FILE...

Prints one line per finding, `file:line: message`, and exits 1 when there is
any. A Python file outside declaration.py must not import ruamel.yaml, yaml
or hermes_yaml directly: it calls load_yaml, which picks the right library
at runtime and keeps the fallback chain in one place.
"""

import ast
import sys
from pathlib import Path

ALLOWED_FILE = "workshop/project/yaml_loader.py"

FORBIDDEN_MODULES = frozenset([
  "ruamel.yaml",
  "ruamel",
  "yaml",
  "hermes_yaml",
])


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

  if is_allowed(path):
    return []

  try:
    tree = ast.parse(path.read_text(), filename=str(path))
  except SyntaxError:
    return []

  return [
    f"{path}:{node.lineno}: import YAML through load_yaml in workshop/project/yaml_loader.py, not directly"
    for node in ast.walk(tree)
    if is_forbidden_import(node)
  ]


def is_allowed(path):
  """Whether this file is the one place that may import YAML libraries directly."""

  return str(path).replace("\\", "/").endswith(ALLOWED_FILE)


def is_forbidden_import(node):
  """Whether the AST node is an import of a YAML library."""

  if isinstance(node, ast.Import):
    return any(is_forbidden_name(alias.name) for alias in node.names)

  if isinstance(node, ast.ImportFrom):
    return is_forbidden_name(node.module or "")

  return False


def is_forbidden_name(module_name):
  """Whether the module name is or starts with a forbidden YAML module."""

  for forbidden in FORBIDDEN_MODULES:
    if module_name == forbidden or module_name.startswith(forbidden + "."):
      return True

  return False


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
