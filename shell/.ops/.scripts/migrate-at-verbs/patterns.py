"""The shapes of shell the migration recognises, as compiled patterns.

Every pattern has a line above it that says what shape it matches; the
module that uses one says what it does with a match.
"""

import re

# `<<TAG`, `<<'TAG'` or `<<-TAG`: the operator that opens a heredoc, with its tag.
HEREDOC_OPENER = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")

# `$(@verb`, the opening of a substitution that runs a structs verb.
VERB_SUBSTITUTION = re.compile(r"\$\(@([a-z_]+)(?=[\s)])")

# `name() {` at the start of a line: a function's definition, @-prefixed names included.
FUNCTION_DEFINITION = re.compile(r"^(@?[A-Za-z_][A-Za-z0-9_.]*)\(\)\s*\{")

# A shell variable name.
IDENTIFIER = re.compile(r"[A-Za-z_]\w*")

# A variable this migration names: an out variable, a temporary, or a bats test's at<n>.
GENERATED_NAME = re.compile(r"(__\w+__out|__\w+_\d+|__at\d+|at\d+|at_out)$")

# What comes before `$(@verb` when the statement is an assignment: the indent, an optional condition keyword, an optional chain such as `[ -n "$x" ] ||`, an optional declaration such as `local`, the name and the opening quote.
ASSIGNMENT_BEFORE = re.compile(
  r'(?P<indent>[ \t]*)(?P<keyword>(?:if|elif|while|until)[ \t]+)?(?P<chain>(?:(?:[^\n]|\\\n)*?(?:\|\||&&)[ \t]*(?:\\\n[ \t]*)?)?)'
  r'(?P<declaration>(?:local|export|readonly)[ \t]+)?(?P<name>[A-Za-z_]\w*)=(?P<quote>"?)')

# What may follow the assignment's `)"`: a chain such as `|| return 1`, or `; then`.
ASSIGNMENT_AFTER = re.compile(r'"?[ \t]*(?P<suffix>(?:\\\n[ \t]*)?(?:\|\||&&|;)[^\n]*)?[ \t]*', re.S)

# `name="$(` on one line, `@verb args` on the next, and `)"` on a line of its own.
MULTI_LINE_ASSIGNMENT = re.compile(
  r'^(?P<indent>[ \t]*)(?P<declaration>(?:local|export|readonly)[ \t]+)?(?P<name>[A-Za-z_]\w*)="\$\(\n[ \t]*@(?P<verb>[a-z_]+)'
  r'(?P<args>(?:[^\n]*\\\n)*[^\n]*)\n[ \t]*\)"[ \t]*$', re.M)

# A case pattern at the start of a line, with a command after it: `*) ` or `-h|--help) `.
CASE_PATTERN = re.compile(r"^[ \t]*[^\s()][^()\n]*\)[ \t]+(?=\S)")

# `@verb` at the start of a line: a bare statement.
BARE_STATEMENT = re.compile(r"^([ \t]*)@([a-z_]+)(?=\s|$)", re.M)

# `| @verb args` at the end of a line: a verb at the tail of a pipeline.
PIPE_TAIL = re.compile(r"((?<!\|)\|(?!\|)[ \t]*)@([a-z_]+)[ \t]+([^\n;]*?)[ \t]*$", re.M)

# bats's `run @verb`, with or without `-N` or `!`.
BATS_RUN = re.compile(r"^([ \t]*run[ \t]+(?:-\d+[ \t]+|![ \t]+)?)@([a-z_]+)\b", re.M)

# A trailing `|| return 1`, `&& ...` or `;` on a statement.
SUFFIX = re.compile(r"\s*((?:\|\||&&)\s+[^\n]*?|;)\s*$")

# A redirect of stdout to a file, `> file` or `>> file`, but not of another descriptor.
STDOUT_REDIRECT = re.compile(r"\s(?<![0-9])>>?\s*[^\s;&|]+")

# A redirect of stdout to /dev/null.
TO_DEV_NULL = re.compile(r"\s*(?<![0-9])>\s*/dev/null")

# `@verb name args; `: a call already inlined into a condition list or after a case pattern.
INLINED_CALL = re.compile(r"@[a-z_]+ [A-Za-z_]\w*[^;\n]*; ")

# `@verb name args` on a line of its own: a call the rewrite hoisted.
HOISTED_CALL = re.compile(r"^([ \t]*)@([a-z_]+) ([A-Za-z_]\w*)(.*)$")

# A function defined on one line, `name() { body; }`.
ONE_LINE_FUNCTION = re.compile(
  r"^(?P<indent>[ \t]*)(?P<definition>(?:function[ \t]+)?(?P<name>@?[A-Za-z_][\w.]*)\(\)[ \t]*\{[ \t]+)(?P<body>.*\S)[ \t]*\}[ \t]*$")

# `$(@verb` inside a one-liner's body.
NESTED_SUBSTITUTION = re.compile(r"\$\(@([a-z_]+)(?=[\s)])")

# `@verb args` as the last command of a one-liner.
TRAILING_CALL = re.compile(r"@([a-z_]+)(\s+.*)?$", re.S)

# A bare `@true;`, `@false;` or `@null;`.
BARE_BOOLEAN = re.compile(r"(\s)@(true|false|null);")

# An if, elif, while or until line whose condition starts with inlined calls.
CONDITION_LIST = re.compile(r"^([ \t]*(?:if|elif|while|until)[ \t]+)((?:@[a-z_]+ [A-Za-z_]\w*[^;]*; )+)(.*)$")

# A bare value verb after a case pattern or a keyword on the same line, `*) @false ;;`, with what ends it.
INLINE_BARE = re.compile(
  r"(?P<lead>(?:\)|\bthen|\belse|\bdo|\{|;|&&|\|\|)[ \t]+)@(?P<verb>[a-z_]+)(?P<args>(?:[ \t]+[^;|&}\n]*?)?)(?P<tail>[ \t]*(?:;;|;|&&|\|\||$))")

# A shellcheck or lint directive with hoisted calls between it and the command it covers.
DIRECTIVE_ABOVE_HOIST = re.compile(
  r"^([ \t]*# (?:shellcheck|structs-lint|inline-comment-check)[^\n]*\n)((?:[ \t]*@[a-z_]+ [A-Za-z_]\w*[^\n]*\n)+)", re.M)

# `@is_zero @verb`, `@succeeds @verb` or `@fails @verb`: a value verb run as a command.
VERB_AS_COMMAND = re.compile(r"@(is_zero|succeeds|fails)[ \t]+@([a-z_]+)")

# A bare call, under `run` or not, whose first argument is a value rather than a variable name.
BARE_WITH_A_VALUE_FIRST = re.compile(r"""^[ \t]*(?:run[ \t]+(?:-\d+[ \t]+|![ \t]+)?)?@([a-z_]+)[ \t]+(?=[.\[{\-0-9]|'|"(?!\$))""", re.M)
