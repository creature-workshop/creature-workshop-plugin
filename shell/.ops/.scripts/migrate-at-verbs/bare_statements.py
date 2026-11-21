"""The rewrite of every bare statement that is a value verb, `@verb args`:
it answers into the function's out variable and prints it, and a stdout
redirect or a pipe that followed the call follows the println instead.
Output sent to /dev/null is dropped with the call's printing.
"""

from lexer import lex
from patterns import BARE_STATEMENT, STDOUT_REDIRECT, SUFFIX, TO_DEV_NULL
from statements import enclosing_function, out_variable, separator, trim_continuation


def rewrite_bare_statements(text, value_verbs, in_bats):
  """(text, rewrites) with every bare value verb answering into a variable and printing it."""

  rewrites = 0
  position = 0
  while True:
    bare = next_bare_statement(text, position, value_verbs)
    if bare is None:
      return text, rewrites

    statement = bare_replacement(text, bare, in_bats)
    text = text[:bare.first] + statement + text[bare.last:]
    rewrites += 1
    position = bare.first + len(statement)


def next_bare_statement(text, position, value_verbs):
  """The first bare value verb at the start of a line from position on, with its statement's bounds, or None."""

  lexed = lex(text)
  for match in BARE_STATEMENT.finditer(text, position):
    if not lexed.code[match.start()] or match.group(2) not in value_verbs:
      continue

    if continues_a_line(text, match.start()):
      continue

    return BareStatement(text, match)

  return None


def continues_a_line(text, line_start):
  """Whether the line is the continuation of the one before it, or the verb line of a multi-line assignment."""

  if line_start == 0:
    return False

  previous = text[text.rfind("\n", 0, line_start - 1) + 1:line_start - 1].rstrip()
  return previous.endswith("\\") or previous.endswith("$(")


def bare_replacement(text, bare, in_bats):
  """`@verb args [> file] [| cmd]` becomes `@verb out args` and `println "$out" [> file] [| cmd]`; output sent to /dev/null is dropped."""

  out = out_variable(enclosing_function(text, bare.first), in_bats)
  parts = BareParts(bare)
  statement = f"{bare.indent}@{bare.verb} {out}{separator(parts.args)}{parts.args}{parts.suffix}"
  if not parts.discards:
    return f'{statement}\n{bare.indent}println "${out}"{parts.redirect}{parts.tail}'

  if parts.tail:
    return f"{statement}\n{bare.indent}true{parts.tail}"

  return statement


class BareParts:
  """A bare statement taken apart: its arguments, its chain suffix, its pipe tail, its stdout redirect, and whether it discards its output."""

  def __init__(self, bare):
    head, self.tail = split_pipeline(bare.statement)
    head, self.suffix = split_suffix(head)
    self.discards = TO_DEV_NULL.search(head) is not None
    head = TO_DEV_NULL.sub("", head)
    head, self.redirect = split_redirect(head) if not self.discards else (head, "")
    self.args = trim_continuation(head[len(bare.indent) + 1 + len(bare.verb):])


class BareStatement:
  """One bare `@verb args` statement, with its continuation lines."""

  def __init__(self, text, match):
    self.indent = match.group(1)
    self.verb = match.group(2)
    self.first = match.start()
    last = text.find("\n", self.first)
    last = len(text) if last == -1 else last
    while text[self.first:last].rstrip().endswith("\\"):
      following = text.find("\n", last + 1)
      last = len(text) if following == -1 else following

    self.last = last
    self.statement = text[self.first:last]


def split_pipeline(statement):
  """(head, tail): the statement before the first pipe at its own depth outside double quotes, and the pipe with the rest."""

  lexed = lex(statement)
  in_double_quotes = False
  index = 0
  while index < len(statement):
    character = statement[index]
    if lexed.code[index] and character == "\\":
      index += 2
      continue

    if lexed.code[index] and character == '"':
      in_double_quotes = not in_double_quotes

    if lexed.code[index] and not in_double_quotes and lexed.depth[index] == 0 and character == "|":
      if statement[index:index + 2] == "||" or (index > 0 and statement[index - 1] == "|"):
        index += 2
        continue

      return statement[:index].rstrip(), " " + statement[index:].strip()

    index += 1

  return statement, ""


def split_suffix(head):
  """(head, suffix): the statement without a trailing `|| return 1`, `&& ...` or `;`, and that suffix."""

  match = SUFFIX.search(head)
  if not match or "\n" in match.group(0):
    return head, ""

  suffix = match.group(1).strip()
  return head[:match.start()], suffix if suffix.startswith(";") else " " + suffix


def split_redirect(head):
  """(head, redirect): the statement without its stdout redirect to a file, and that redirect; a `>` inside quotes is text."""

  lexed = lex(head)
  in_double_quotes = False
  for index, character in enumerate(head):
    if lexed.code[index] and character == '"' and (index == 0 or head[index - 1] != "\\"):
      in_double_quotes = not in_double_quotes

    match = STDOUT_REDIRECT.match(head, index)
    if match and lexed.code[index] and not in_double_quotes:
      return head[:index] + head[match.end():], match.group(0)

  return head, ""
