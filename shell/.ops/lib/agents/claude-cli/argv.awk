# Prints the headless command line one Claude Code CLI run takes, as a list
# of arguments: the CLI, the flags that make it answer without a terminal,
# what the options add, the session the run belongs to, and the prompt
# last.
#
# Input: the run options, and ahead of them, with --with and in this
#        order: the defaults, which are the claude-cli block
#        __claude_cli__new_options prints and which the options' own block
#        overrides, and the start, {agent, run, prompt, key, session_flag}.
#
# An option left empty is one nobody named, so its flag is left off and the
# CLI keeps its own answer.

function main(line) {
  tree_line(line)
}

# The member of the claude-cli block under a name: the options' own when
# they have it, and the default's otherwise.
function block(name, __own) {
  __own = member(OWN, name)

  return (__own != 0) ? __own : member(DEFAULTS, name)
}

# The text of a node, and the empty string for a missing or null one.
function text(node) {
  return is_present(node) ? text_of(node) : ""
}

# Adds a node to the command line as it is.
function add_node(node) {
  print_node(node, 0, ARGUMENTS)
  ARGUMENTS++
}

# Adds a text to the command line.
function add(argument) {
  print "0." ARGUMENTS ":str=" wrap(argument)
  ARGUMENTS++
}

# Adds a flag and its value when the value is not empty.
function add_flag(flag, value) {
  if (value != "") {
    add(flag)
    add(value)
  }
}

# The tools the block allows, joined with spaces, and the empty string
# when it allows none.
function allowed_tools(__tool, __joined) {
  __joined = ""

  for (__tool = NODE_FIRST[block("allowed_tools")]; __tool != 0; __tool = NODE_NEXT[__tool]) {
    __joined = __joined (__joined == "" ? "" : " ") text(__tool)
  }

  return __joined
}

BEGIN {
  DEFAULTS = tree_ahead()
  START = tree_ahead()
  ROOT = tree_open()
  ARGUMENTS = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  OWN = member(ROOT, "claude-cli")
  add_node(block("command"))
  add("-p")
  add("--output-format")
  add("text")
  add("--permission-mode")
  add_node(block("permission_mode"))
  if (is_present(block("bare")) && text_of(block("bare")) != "false") {
    add("--bare")
  }
  if (text(block("mcp_config")) != "") {
    add("--strict-mcp-config")
    add("--mcp-config")
    add(text(block("mcp_config")))
  }
  if (NODE_COUNT[block("allowed_tools")] > 0) {
    add("--allowedTools")
    add(allowed_tools())
  }
  add_flag("--model", text(member(ROOT, "model")))
  add_flag("--effort", text(block("effort")))
  add_flag("--max-budget-usd", text(block("max_budget_usd")))
  add_node(member(START, "session_flag"))
  add_node(member(START, "agent"))
  add_node(member(START, "prompt"))
}

{ main($0) }
