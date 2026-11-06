#!/usr/bin/env python3
"""One React component per file, in a file of the component's name.

  one_component_per_file.py FILE...

Prints one line per finding, `file:line: message`, and exits 1 when there is
any. A component is a function declared at the top level of the file, or an
arrow function assigned to a top-level const, whose name starts with a capital
letter. A file may define one, and its name is then `<Component>.jsx`. A file
that defines none, such as a store or a test, passes whatever its name.

A file that must hold more than one declares the reason on a line of its own,
and is then left alone:

  /* one-component-per-file: allow <reason> */
"""
import re
import sys
from pathlib import Path

COMPONENT = re.compile(r"^(?:export\s+)?(?:default\s+)?(?:function\s+([A-Z]\w*)\s*\(|const\s+([A-Z]\w*)\s*=\s*(?:\([^)]*\)|\w+)\s*=>)", re.MULTILINE)
ALLOW = re.compile(r"/\*\s*one-component-per-file:\s*allow\s+\S")


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
  if ALLOW.search(source):
    return []

  components = components_in(source)
  if len(components) > 1:
    names = ", ".join(name for name, _ in components)
    return [f"{path}:{components[1][1]}: one component per file; this one has {len(components)}: {names}"]

  if len(components) == 1 and path.stem != components[0][0]:
    return [f"{path}:{components[0][1]}: a component's file takes its name: {components[0][0]}.jsx"]

  return []


def components_in(source):
  """[(name, line)] for every top-level component the file defines.

    components_in("export function Chip() {}\\nconst Row = () => 1;")  ->  [("Chip", 1), ("Row", 2)]
  """
  found = []
  for match in COMPONENT.finditer(source):
    name = match.group(1) or match.group(2)
    found.append((name, source.count("\n", 0, match.start()) + 1))

  return found


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
