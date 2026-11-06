#!/usr/bin/env python3
"""Two-space indentation in every Python file.

  indent_width.py FILE...

Prints one line per finding, `file:line: message`, and exits 1 when there is
any. Every block indents by exactly two spaces more than the block around it,
and no indentation uses a tab. Continuation lines inside brackets are the
author's, since they align with what they continue.
"""
import sys
import tokenize
from pathlib import Path

STEP = 2


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
  with tokenize.open(path) as source:
    try:
      tokens = list(tokenize.generate_tokens(source.readline))
    except (tokenize.TokenError, SyntaxError) as error:
      return [f"{path}:0: cannot tokenize: {error}"]

  return [f"{path}:{line}: {message}" for line, message in findings_in(tokens)]


def findings_in(tokens):
  """(line, message) for every INDENT token that is not two spaces deeper than the last."""
  found = []
  depths = [0]
  for token in tokens:
    if token.type == tokenize.INDENT:
      found.extend(check_indent(token, depths))
    elif token.type == tokenize.DEDENT:
      depths.pop()

  return found


def check_indent(token, depths):
  """Records the new depth and reports it when it is not one step past the last."""
  if "\t" in token.string:
    depths.append(depths[-1] + STEP)
    return [(token.start[0], "a tab in the indentation; two spaces per level")]

  depth = len(token.string)
  depths.append(depth)
  if depth - depths[-2] != STEP:
    return [(token.start[0], f"indented by {depth - depths[-2]} spaces; two per level")]

  return []


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
