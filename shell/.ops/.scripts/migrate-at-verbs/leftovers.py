"""What the scripted pass leaves for a hand pass: every call still in the
printing shape, and every mark the rewrite left on a statement it could not
place.
"""

import os
import re

from lexer import lex
from substitutions import HAND_MARK
from verbs import in_structs_library, shell_files
from patterns import BARE_WITH_A_VALUE_FIRST, VERB_AS_COMMAND


def leftovers(root, value_verbs):
  """One line per leftover under root: its file, line and what it is."""

  found = []
  for path in shell_files(root):
    if in_structs_library(root, path):
      continue

    text = open(path).read()
    relative = os.path.relpath(path, root)
    found.extend(leftovers_in(relative, text, value_verbs))

  return found


def leftovers_in(relative, text, value_verbs):
  """The leftovers of one file, of every kind, as lines that name the file."""

  lexed = lex(text)
  found = []
  found.extend(substitutions_left(text, lexed, value_verbs))
  found.extend(verbs_run_as_commands(text, lexed, value_verbs))
  found.extend(hand_marks(text))
  found.extend(bare_calls_with_a_value_first(text, lexed, value_verbs))
  return [f"{relative}:{line}: {what}" for line, what in found]


def substitutions_left(text, lexed, value_verbs):
  """(line, what) for every `$(@verb ...)` still in the code."""

  return [
    (line_of(text, opener.start), f"$(@{opener.verb} is still a substitution")
    for opener in lexed.openers
    if lexed.code[opener.start] and opener.verb in value_verbs]


def verbs_run_as_commands(text, lexed, value_verbs):
  """(line, what) for every value verb that @is_zero, @succeeds or @fails runs as a command, which would print nothing."""

  return [
    (line_of(text, match.start()), f"{match.group(0)} runs a value verb as a command")
    for match in VERB_AS_COMMAND.finditer(text)
    if lexed.code[match.start()] and match.group(2) in value_verbs]


def hand_marks(text):
  """(line, what) for every statement the rewrite marked for hand work."""

  return [(line_of(text, match.start()), HAND_MARK) for match in re.finditer(re.escape(HAND_MARK), text)]


def bare_calls_with_a_value_first(text, lexed, value_verbs):
  """(line, what) for every bare call whose first argument is a value, which is the printing shape."""

  return [
    (line_of(text, match.start()), f"bare @{match.group(1)} whose first argument is a value, not a variable")
    for match in BARE_WITH_A_VALUE_FIRST.finditer(text)
    if lexed.code[match.start()] and match.group(1) in value_verbs]


def line_of(text, position):
  """The 1-based line that holds position."""

  return text.count("\n", 0, position) + 1
