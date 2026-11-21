"""The repairs that follow the rewrite of a file: the shapes the rewrite
places badly or cannot see, each put right by one pass over the text.
"""

import re

from lexer import lex
from statements import enclosing_function, out_variable, is_generated_name
from patterns import BARE_BOOLEAN, CASE_PATTERN, CONDITION_LIST, DIRECTIVE_ABOVE_HOIST, HOISTED_CALL, INLINED_CALL, INLINE_BARE, NESTED_SUBSTITUTION, ONE_LINE_FUNCTION, TRAILING_CALL


def repair(text, value_verbs):
  """The text after every repair, in the order they depend on each other."""

  text = fold_case_hoists(text)
  text = repair_one_line_functions(text, value_verbs)
  text = order_condition_calls(text)
  text = answer_inline_bare_calls(text, value_verbs)
  text = keep_directives_above_their_command(text)
  return text


def fold_case_hoists(text):
  """A call hoisted above a case pattern's line moves onto that line, after the pattern, where the shell allows a command."""

  lines = text.split("\n")
  folded = []
  index = 0
  while index < len(lines):
    hoists, next_index = hoists_from(lines, index)
    if hoists and next_index < len(lines) and consumed_by_pattern_line(hoists, lines[next_index]):
      folded.append(fold_into_pattern_line(hoists, lines[next_index]))
      index = next_index + 1
      continue

    folded.append(lines[index])
    index += 1

  return "\n".join(folded)


def hoists_from(lines, index):
  """The run of hoisted calls that starts at index, and the index after it."""

  hoists = []
  while index < len(lines) and is_hoist(lines[index]):
    hoists.append(HOISTED_CALL.match(lines[index]))
    index += 1

  return hoists, index


def is_hoist(line):
  """Whether a line is a call the rewrite hoisted: a verb answering into a name the migration made up, on one line."""

  match = HOISTED_CALL.match(line)
  return match is not None and is_generated_name(match.group(3)) and not line.rstrip().endswith("\\")


def consumed_by_pattern_line(hoists, line):
  """Whether line is a case pattern's line that reads every hoisted temporary, directly or through a later hoist."""

  if not CASE_PATTERN.match(line):
    return False

  return all(reads_temporary(hoists[position:], line) for position in range(len(hoists)))


def reads_temporary(hoists, line):
  """Whether the first hoist's temporary is read by the line or by one of the hoists after it."""

  temporary = "$" + hoists[0].group(3)
  return temporary in line or any(temporary in later.group(4) for later in hoists[1:])


def fold_into_pattern_line(hoists, line):
  pattern = CASE_PATTERN.match(line)
  calls = "; ".join(f"@{hoist.group(2)} {hoist.group(3)}{hoist.group(4)}" for hoist in hoists)
  return f"{pattern.group(0)}{calls}; {line[pattern.end():]}"


def repair_one_line_functions(text, value_verbs):
  """A function defined on one line keeps its calls inside: the hoists above it that it reads move in, a nested `$(@verb ...)` hoists inside the body, a bare @true, @false or @null gets its variable, and a trailing value verb answers through println."""

  lines = text.split("\n")
  repaired = []
  for line in lines:
    definition = ONE_LINE_FUNCTION.match(line)
    if not definition:
      repaired.append(line)
      continue

    hoists = take_hoists_above(repaired, line)
    repaired.append(repaired_one_liner(definition, hoists, value_verbs))

  return "\n".join(repaired)


def take_hoists_above(repaired, line):
  """Removes from the lines so far the run of hoists directly above a one-liner that it reads, directly or through a later hoist, and returns them."""

  run = []
  while repaired and is_hoist(repaired[-1]):
    run.insert(0, repaired.pop())

  while run and not reads_temporary([HOISTED_CALL.match(hoist) for hoist in run], line):
    repaired.append(run.pop(0))

  return [hoist.strip() for hoist in run]


def repaired_one_liner(definition, hoists, value_verbs):
  """The one-liner with the hoists first, then the nested calls, then its body with every verb answering."""

  out = out_variable(definition.group("name"), False)
  body, nested = hoist_nested_calls(definition.group("body").rstrip().rstrip(";"), out[:-5], value_verbs)
  segments = answered_bare_booleans(body, out).split("; ")
  segments[-1] = answered_trailing_call(segments[-1], out, value_verbs)
  return f"{definition.group('indent')}{definition.group('definition')}{'; '.join(hoists + nested + segments)}; }}"


def answered_bare_booleans(body, out):
  """The body with every bare `@true;`, `@false;` or `@null;` answering into out and printing it."""

  return BARE_BOOLEAN.sub(lambda match: f'{match.group(1)}@{match.group(2)} {out}; println "${out}";', body)


def hoist_nested_calls(body, prefix, value_verbs):
  """(body, hoists): the body with every `$(@verb args)` replaced by a temporary, innermost first, and the calls that fill them."""

  hoists = []
  while True:
    inner = innermost_nested_call(body, value_verbs)
    if inner is None:
      return body, hoists

    start, end, verb = inner
    temporary = f"{prefix}__{verb}_{len(hoists) + 1}"
    args = body[start + 3 + len(verb):end].strip()
    hoists.append(f"@{verb} {temporary}{' ' + args if args else ''}")
    body = body[:start] + "$" + temporary + body[end + 1:]


def innermost_nested_call(body, value_verbs):
  """The first `$(@verb ...)` in body that holds no other, as (start, end of its `)`, verb), or None."""

  for match in NESTED_SUBSTITUTION.finditer(body):
    if match.group(1) not in value_verbs:
      continue

    end = matching_paren(body, match.start())
    if end > 0 and "$(@" not in body[match.start() + 2:end]:
      return match.start(), end, match.group(1)

  return None


def matching_paren(text, start):
  """The index of the `)` that closes the `$(` at start, or -1."""

  depth = 0
  index = start
  while index < len(text):
    if text[index] == "\\":
      index += 2
      continue

    if text.startswith("$(", index):
      depth += 1
      index += 2
      continue

    if text[index] == ")":
      depth -= 1
      if depth == 0:
        return index

    index += 1

  return -1


def answered_trailing_call(segment, out, value_verbs):
  """A trailing `@verb args` of a one-liner answers into out and prints it; one already in the register shape stays."""

  match = TRAILING_CALL.match(segment.strip())
  if not match or match.group(1) not in value_verbs:
    return segment

  first_word = (match.group(2) or "").split()
  if first_word and is_generated_name(first_word[0]):
    return segment

  return f'@{match.group(1)} {out}{match.group(2) or ""}; println "${out}"'


def order_condition_calls(text):
  """In a condition list of inlined calls, the call that fills a temporary comes before the call that reads it."""

  lines = text.split("\n")
  for index, line in enumerate(lines):
    condition = CONDITION_LIST.match(line)
    if condition:
      lines[index] = condition.group(1) + "".join(ordered_calls(INLINED_CALL.findall(condition.group(2)))) + condition.group(3)

  return "\n".join(lines)


def ordered_calls(calls):
  """The calls with each one after the calls whose temporaries it reads."""

  pending = [(re.match(r"@[a-z_]+ ([A-Za-z_]\w*)", call).group(1), call) for call in calls]
  ordered = []
  while pending:
    ready = next((entry for entry in pending if reads_none_of(entry, pending)), pending[0])
    pending.remove(ready)
    ordered.append(ready[1])

  return ordered


def reads_none_of(entry, pending):
  name, call = entry
  return not any(f"${other}" in call for other, _ in pending if other != name)


def answer_inline_bare_calls(text, value_verbs):
  """A bare value verb after a case pattern or a keyword on the same line, `*) @false ;;`, answers into the function's out variable and prints it."""

  lexed = lex(text)
  pieces = []
  position = 0
  for match in INLINE_BARE.finditer(text):
    if match.group("verb") not in value_verbs or not lexed.code[match.start("verb")]:
      continue

    first_word = match.group("args").split()
    if first_word and is_generated_name(first_word[0]):
      continue

    out = out_variable(enclosing_function(text, match.start()), False)
    pieces.append(text[position:match.start()])
    pieces.append(f'{match.group("lead")}@{match.group("verb")} {out}{match.group("args").rstrip()}; println "${out}"{spaced_tail(match.group("tail"))}')
    position = match.end()

  pieces.append(text[position:])
  return "".join(pieces)


def spaced_tail(tail):
  """The separator after an answered call: `;;` and a chain keep a space before them, a lone `;` does not."""

  tail = tail.strip()
  return tail if tail in ("", ";") else " " + tail


def keep_directives_above_their_command(text):
  """A shellcheck or lint directive stays directly above the command it covers, below any call hoisted there."""

  return DIRECTIVE_ABOVE_HOIST.sub(lambda match: match.group(2) + match.group(1), text)
