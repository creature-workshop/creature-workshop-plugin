#!/usr/bin/env python3
"""No comments in a YAML file.

  yaml_comments.py FILE...

Prints one line per comment, `file:line: message`, and exits 1 when there is
any. A comment is a `#` that starts a line or follows whitespace, outside a
quoted scalar. What a comment would say belongs where the thing it describes
is defined: a job's purpose in the doc block of the action the job calls, and
the shape of a file in the README.
"""

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

  findings = []
  for number, line in enumerate(path.read_text().splitlines(), 1):
    if has_comment(line):
      findings.append(f"{path}:{number}: no comments in YAML; say it where the thing it describes is defined")

  return findings


def has_comment(line):
  """True when a `#` outside quotes starts the line or follows whitespace.

    has_comment("# a note")          ->  True
    has_comment("key: value  # why") ->  True
    has_comment("key: 'a # b'")      ->  False
  """

  quote = None
  previous = " "
  for char in line:
    if quote:
      if char == quote:
        quote = None

    elif char in "\"'":
      quote = char
    elif char == "#" and previous.isspace():
      return True

    previous = char

  return False


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
