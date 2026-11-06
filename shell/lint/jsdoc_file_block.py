#!/usr/bin/env python3
"""A JSDoc file block at the top of every JavaScript file, after the shebang when there is one.

  jsdoc_file_block.py FILE...

Prints one line per file that lacks one, `file:line: message`, and exits 1
when there is any. The block is the first thing in the file that is not a
shebang or a blank line: it opens with `/**`, names the `@file` tag before it
closes with `*/`, and says something between the two. A `//` comment is not
documentation to JSDoc, TypeScript or an editor, so it does not count.
"""
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
  lines = path.read_text().splitlines()
  start = first_content_line(lines)
  if start is None or not lines[start].lstrip().startswith("/**"):
    return [f"{path}:{(start or 0) + 1}: a JSDoc file block at the top of the file: /** @file ... */"]

  block = block_text(lines, start)
  if block is None:
    return [f"{path}:{start + 1}: the file block never closes with */"]

  if "@file" not in block:
    return [f"{path}:{start + 1}: the file block names the @file tag"]

  if not words_in(block):
    return [f"{path}:{start + 1}: the file block says what the file is for"]

  return []


def first_content_line(lines):
  """The index of the first line that is not blank and not the shebang, or None."""
  for index, line in enumerate(lines):
    if index == 0 and line.startswith("#!"):
      continue

    if line.strip():
      return index

  return None


def block_text(lines, start):
  """The text of the comment block that opens at start, or None when it never closes."""
  collected = []
  for line in lines[start:]:
    collected.append(line)
    if "*/" in line:
      return "\n".join(collected)

  return None


def words_in(block):
  """The words of the block once its syntax and the @file tag are removed."""
  cleaned = block.replace("/**", " ").replace("*/", " ").replace("@file", " ")
  return [word for word in cleaned.replace("*", " ").split() if word.isalnum()]


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
