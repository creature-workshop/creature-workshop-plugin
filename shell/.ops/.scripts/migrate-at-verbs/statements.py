"""Where a call sits: the statement around it, the function it is in, and the
names the migration invents for the variables it introduces.

A shell variable of a function is named `__<function>__<name>`, as the
shell naming rule says. A temporary that holds a hoisted call is
`__<function>__<verb>_<n>`; the variable a bare call answers into is
`__<function>__out`; in a bats test body, which has no function name, they
are `at<n>` and `at_out`.
"""

from patterns import FUNCTION_DEFINITION, GENERATED_NAME


def statement_bounds(text, depth, start, end):
  """The offsets (first, last) of the statement that holds text[start:end]: back over continuation lines and open `$(`, and forward the same way."""

  first = text.rfind("\n", 0, start) + 1
  while first > 0 and continues_previous_line(text, depth, first):
    first = text.rfind("\n", 0, first - 1) + 1

  last = line_end(text, end)
  while last < len(text) and continues_next_line(text, depth, last):
    last = line_end(text, last + 1)

  return first, last


def continues_previous_line(text, depth, line_start):
  """Whether the line at line_start carries on the line before it: that line ends in a backslash, or a `$(` is still open."""

  previous_end = line_start - 1
  previous_start = text.rfind("\n", 0, previous_end) + 1
  previous = text[previous_start:previous_end]
  return previous.rstrip().endswith("\\") or depth[line_start] > 0


def continues_next_line(text, depth, line_last):
  """Whether the line ending at line_last carries on into the next: it ends in a backslash, or a `$(` is still open."""

  line = text[text.rfind("\n", 0, line_last) + 1:line_last]
  return line.rstrip().endswith("\\") or (line_last + 1 < len(text) and depth[line_last] > 0)


def line_end(text, position):
  """The offset of the newline that ends the line holding position, or the end of the text."""

  end = text.find("\n", position)
  return len(text) if end == -1 else end


def enclosing_function(text, position):
  """The name of the function whose body holds position, or None at the top level or in a bats test body."""

  line_start = text.rfind("\n", 0, position) + 1
  while line_start > 0:
    line_start = text.rfind("\n", 0, line_start - 1) + 1
    line = text[line_start:line_end(text, line_start)]
    if not line or line[0] in " \t":
      continue

    if line.startswith("}"):
      return None

    if line.startswith("#") or line.startswith(":"):
      continue

    match = FUNCTION_DEFINITION.match(line)
    return match.group(1) if match else None

  return None


def variable_prefix(function_name):
  """The prefix of the function's variables: the function's name, with `__` in front when it is a public one."""

  name = function_name.lstrip("@").replace(".", "_")
  return name if name.startswith("__") else "__" + name


def out_variable(function_name, in_bats):
  """The variable a bare call in the function answers into."""

  if function_name is None:
    return "at_out" if in_bats else "__at_out"

  return variable_prefix(function_name) + "__out"


def temporary_name(function_name, verb, ordinal, in_bats):
  """The variable that holds the ordinal-th hoisted call of the verb in the function."""

  if function_name is None:
    return f"at{ordinal}" if in_bats else f"__at{ordinal}"

  return f"{variable_prefix(function_name)}__{verb}_{ordinal}"


def is_generated_name(word):
  """Whether a word is a variable this migration names, which marks a call as already in the register shape."""

  return GENERATED_NAME.fullmatch(word) is not None


def separator(args):
  """The space between the out variable and the arguments, unless the arguments start with their own."""

  return "" if args == "" or args[0] in " \t\\" else " "


def trim_continuation(args):
  """Arguments without the trailing whitespace and the backslash that continued them onto the closing line."""

  args = args.rstrip()
  return args[:-1].rstrip() if args.endswith("\\") else args


def declaration_line(indent, declaration, name):
  """The `local name` line an assignment with a declaration keeps above the call, or nothing."""

  return f"{indent}{declaration}{name}\n" if declaration else ""
