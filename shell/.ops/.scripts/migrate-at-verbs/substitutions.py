"""The rewrite of every `$(@verb args)` in a file, innermost first, by the
shape of the statement around it: an assignment becomes `@verb name args`,
a call in an if or while condition is inlined before the test, a call on a
case pattern's line is inlined after the pattern, and any other call hoists
to a temporary on the line above. A statement the script cannot place
without changing its meaning is marked for a hand pass.
"""

import re

from lexer import lex
from patterns import ASSIGNMENT_AFTER, ASSIGNMENT_BEFORE, CASE_PATTERN, INLINED_CALL, MULTI_LINE_ASSIGNMENT
from statements import statement_bounds, enclosing_function, temporary_name, separator, trim_continuation, declaration_line

HAND_MARK = "# TODO(migrate-at-verbs): finish by hand"

CONDITION_KEYWORDS = ("if", "elif", "while", "until")

KEYWORDS_NOTHING_GOES_BEFORE = ("elif", "else", "then", "do")


def rewrite_substitutions(text, value_verbs, in_bats):
  """(text, rewrites, lines left for hand) with every substitution of a value verb in the register shape."""

  pass_ = Substitutions(text, value_verbs, in_bats)
  pass_.run()
  return pass_.text, pass_.rewrites, pass_.flagged_lines


class Substitutions:
  def __init__(self, text, value_verbs, in_bats):
    self.text = text
    self.value_verbs = value_verbs
    self.in_bats = in_bats
    self.temporaries = 0
    self.rewrites = 0
    self.flagged_lines = []
    self.left_for_hand = set()

  def run(self):
    """Rewrites `$(@verb ...)` one at a time, innermost first, until none is left that the script can place."""

    while True:
      self.rewrite_multi_line_assignments()
      lexed = lex(self.text)
      candidate = self.innermost_candidate(lexed)
      if candidate is None:
        return

      self.rewrite_one(candidate, lexed)

  def innermost_candidate(self, lexed):
    """The first `$(@verb` that holds no other and has not been left for hand work, with its statement's bounds."""

    for opener in lexed.openers:
      if not lexed.code[opener.start] or opener.verb not in self.value_verbs:
        continue

      if self.holds_another(opener, lexed):
        continue

      first, last = statement_bounds(self.text, lexed.depth, opener.start, opener.end)
      if (opener.verb, self.text[first:last]) in self.left_for_hand:
        continue

      return opener, first, last

    return None

  def holds_another(self, opener, lexed):
    """Whether another value-verb substitution sits inside this one."""

    return any(
      inner.start > opener.start and inner.end <= opener.end and lexed.code[inner.start] and inner.verb in self.value_verbs
      for inner in lexed.openers)

  def rewrite_multi_line_assignments(self):
    """`name="$(` on one line, `@verb args` on the next and `)"` on its own line becomes `@verb name args`."""

    self.text = MULTI_LINE_ASSIGNMENT.sub(self.multi_line_assignment_replacement, self.text)

  def multi_line_assignment_replacement(self, match):
    if match.group("verb") not in self.value_verbs:
      return match.group(0)

    self.rewrites += 1
    args = trim_continuation(match.group("args"))
    declaration = declaration_line(match.group("indent"), match.group("declaration"), match.group("name"))
    return f"{declaration}{match.group('indent')}@{match.group('verb')} {match.group('name')}{separator(args)}{args}"

  def rewrite_one(self, candidate, lexed):
    """Rewrites one substitution by the shape of the statement around it."""

    opener, first, last = candidate
    call = Call(self.text, opener, first, last)
    if self.rewrite_assignment(call):
      return

    if self.rewrite_in_case_branch(call):
      return

    if self.rewrite_in_condition(call):
      return

    if self.must_be_done_by_hand(call, lexed):
      self.flag(call)
      return

    self.hoist(call)

  def rewrite_assignment(self, call):
    """`name="$(@verb args)"`, with or without a chain or a keyword before it, becomes `@verb name args`. Answers whether the statement had that shape."""

    before = ASSIGNMENT_BEFORE.fullmatch(call.before)
    after = ASSIGNMENT_AFTER.fullmatch(call.after)
    if not (before and after):
      return False

    if (before.group("quote") == '"') != call.quoted or "$(" in before.group("chain") or "`" in before.group("chain"):
      return False

    keyword = before.group("keyword") or ""
    suffix = assignment_suffix(after.group("suffix"))
    declaration = "" if keyword else declaration_line(call.indent, before.group("declaration"), before.group("name"))
    statement = f"{declaration}{call.indent}{keyword}{before.group('chain')}@{call.verb} {before.group('name')}{separator(call.args)}{call.args}{suffix}"
    self.replace(call.first, call.last, statement)
    return True

  def rewrite_in_case_branch(self, call):
    """On a case pattern's line, `pattern) ... $(@verb args) ...` becomes `pattern) @verb t args; ... $t ...`. Answers whether it did."""

    pattern = CASE_PATTERN.match(call.statement)
    if not pattern or "\n" in call.args or call.opener.start < call.first + pattern.end():
      return False

    temporary = self.temporary(call)
    head_end = after_inlined_calls(call.statement, pattern.end())
    rest = call.rest_with(head_end, temporary)
    self.replace(call.first, call.last, f"{call.statement[:head_end]}@{call.verb} {temporary}{separator(call.args)}{call.args}; {rest}")
    return True

  def rewrite_in_condition(self, call):
    """In an if, elif, while or until condition, the call runs first in the list: `if @verb t args; [ "$t" ... ]; then`. Answers whether it did."""

    if call.keyword not in CONDITION_KEYWORDS or "\n" in call.args:
      return False

    temporary = self.temporary(call)
    head_length = len(call.indent) + len(call.keyword)
    condition_start = head_length + len(call.statement[head_length:]) - len(call.statement[head_length:].lstrip())
    head_end = after_inlined_calls(call.statement, condition_start)
    rest = call.rest_with(head_end, temporary)
    self.replace(call.first, call.last, f"{call.statement[:head_end].rstrip()} @{call.verb} {temporary}{separator(call.args)}{call.args}; {rest}")
    return True

  def must_be_done_by_hand(self, call, lexed):
    """Whether hoisting above the statement would change its meaning: a keyword nothing may go before, a chain before the call, or a multi-line condition."""

    if call.keyword in KEYWORDS_NOTHING_GOES_BEFORE:
      return True

    if call.keyword in CONDITION_KEYWORDS and call.keyword != "if":
      return True

    return call.keyword != "if" and self.chained_before(call, lexed)

  def chained_before(self, call, lexed):
    """Whether a `&&` or `||` at the statement's own depth comes before the call."""

    for index in range(call.first, call.opener.start - 1):
      if lexed.code[index] and lexed.depth[index] == lexed.depth[call.first] and self.text[index:index + 2] in ("||", "&&"):
        return True

    return False

  def hoist(self, call):
    """The call moves to a temporary on the line above the statement, which reads the temporary where the call was."""

    temporary = self.temporary(call)
    hoisted = f"{call.indent}@{call.verb} {temporary}{separator(call.args)}{call.args}\n"
    reference = temporary if call.in_arithmetic else "$" + temporary
    statement = self.text[call.first:call.opener.start] + reference + self.text[call.opener.end:call.last]
    self.replace(call.first, call.last, hoisted + statement)

  def flag(self, call):
    """Marks the statement for hand work and leaves it as it is."""

    self.left_for_hand.add((call.verb, call.statement))
    self.flagged_lines.append(self.text.count("\n", 0, call.first) + 2)
    self.text = self.text[:call.first] + call.indent + HAND_MARK + "\n" + self.text[call.first:]

  def temporary(self, call):
    """A new temporary for the call, named for the function it is in."""

    self.temporaries += 1
    return temporary_name(enclosing_function(self.text, call.first), call.verb, self.temporaries, self.in_bats)

  def replace(self, first, last, statement):
    self.rewrites += 1
    self.text = self.text[:first] + statement + self.text[last:]


class Call:
  """One `$(@verb args)` and the statement around it."""

  def __init__(self, text, opener, first, last):
    self.opener = opener
    self.verb = opener.verb
    self.first = first
    self.last = last
    self.statement = text[first:last]
    self.before = text[first:opener.start]
    self.after = text[opener.end:last]
    self.args = trim_continuation(text[opener.start + 3 + len(opener.verb):opener.end - 1])
    self.indent = re.match(r"[ \t]*", self.statement).group(0)
    self.quoted = opener.start > 0 and text[opener.start - 1] == '"' and opener.end < len(text) and text[opener.end] == '"'
    first_word = self.statement.lstrip().split(None, 1)
    self.keyword = first_word[0] if first_word else ""
    self.in_arithmetic = self.before.count("$((") > self.before.count("))")

  def rest_with(self, offset, temporary):
    """The statement from offset on, with the call replaced by the temporary."""

    rest = self.statement[offset:]
    call_at = self.opener.start - self.first - offset
    return rest[:call_at] + "$" + temporary + rest[call_at + (self.opener.end - self.opener.start):]


def after_inlined_calls(statement, offset):
  """The offset after the run of calls already inlined at offset, so a new one goes after the calls that fill what it reads."""

  while True:
    match = INLINED_CALL.match(statement, offset)
    if not match:
      return offset

    offset = match.end()


def assignment_suffix(suffix):
  """What followed the assignment, `|| return 1` or `; then`, as it goes after the call."""

  if not suffix:
    return ""

  suffix = suffix.lstrip()
  return suffix if suffix.startswith(";") else " " + suffix
