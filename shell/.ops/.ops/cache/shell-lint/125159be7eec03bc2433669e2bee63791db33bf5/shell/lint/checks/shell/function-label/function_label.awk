# The function-label check. Loaded with the scanner runtime and the doc-block
# library:
#
#   awk -v root=<repository root> -f scan.awk -f doc_block.awk -f function_label.awk
#
# Finds, in the files given:
#
#   - a function doc that opens on anything but PUB_FUN or FUN
#   - a PUB_FUN or FUN label on a block that no function follows
#   - a label that disagrees with the function's name
#
# The rules it reads by:
#
#   - A function doc is a doc block whose closer is followed by a function
#     definition. A `#` line between them, a shellcheck directive, does not
#     part them; a blank line does.
#   - PUB_FUN is for a library module's public surface: a function in a .sh
#     under lib/ or interpreter/, named without the leading `__` of a
#     private function (ADR 000031), and not a plugin's role.
#   - FUN is for every other function: a private one, a plugin's role (an
#     `@` name indented inside the plugin's outer function), and any
#     function of an entrypoint or of a template one is written from.
#   - An `@` name at column zero is a structs verb, and public.
#   - A plugin's outer `@<kind>.<name>()` is no function to the scanner; the
#     doc above it keeps its label.
#
# The lowering reads the label for the function's visibility (ADR 000039),
# so the label and the name have to agree.
#
# Output: "<name>:<lineno>: <message>", <lineno> being FNR, awk's line number
# within the current file. Vars: -v root=<dir> keys the files under the
# repository root; -v fname=<display name> (default FILENAME).

# The file's key: its path under the repository root, or from its last lib/ or
# interpreter/ component when it sits elsewhere, so a fixture is still a
# library file. A path with neither keys to nothing.
function file_key(path) {
  if (root != "" && index(path, root "/") == 1) {
    return repo_key(path)
  }
  return library_key(path)
}

# True when KEY is a library file: a .sh under a library root
# (library_root.awk), and not a template for an entrypoint, whose functions
# are an entrypoint's.
function is_library(key) {
  return (under_library_root(key) && key ~ /\.sh$/ && key !~ /\.template\.sh$/)
}

# True when TERM is one of the two labels a function doc opens on.
function is_function_label(term) {
  return (term == "PUB_FUN" || term == "FUN")
}

# The name a function-definition LINE defines: `git__tracked_files` from
# `git__tracked_files() {`, `@run` from `  @run() {`.
function defined_name(line, __name) {
  __name = line
  sub(/^[ \t]*function[ \t]+/, "", __name)
  sub(/^[ \t]*/, "", __name)
  sub(/[ \t]*\(.*$/, "", __name)
  return __name
}

# True when the function-definition LINE defines a plugin's role: an `@` name
# indented inside the plugin's outer function.
function is_role_def(line) {
  return (line ~ /^[ \t]+(function[ \t]+)?@/)
}

# The label the doc of the function NAME, defined on LINE, opens on: PUB_FUN
# for a library function that is neither private nor a role, FUN otherwise.
function expected_label(name, line) {
  if (!library) {
    return "FUN"
  }
  if (name ~ /^__/ || is_role_def(line)) {
    return "FUN"
  }
  return "PUB_FUN"
}

# What the function NAME, defined on LINE, is to its callers, for the
# finding's prose.
function reach_of(name, line) {
  if (!library) {
    return "an entrypoint's function"
  }
  if (is_role_def(line)) {
    return "a plugin's role"
  }
  if (name ~ /^__/) {
    return "private to its module"
  }
  return "public"
}

# Judges the doc block that just closed against its follower LINE, the line
# right after its closer (empty at end of file). One followed by a function
# is judged against the function's name; any other may carry any label but a
# function doc's.
function settle_block(line, __name, __want) {
  awaiting = 0
  if (!is_func_def(line)) {
    if (is_function_label(pending_term)) {
      note(pending_at, pending_term " names a function doc; this block is not followed by a function")
    }
    return
  }
  __name = defined_name(line)
  __want = expected_label(__name, line)
  if (pending_term == __want) {
    return
  }
  if (is_function_label(pending_term)) {
    note(pending_at, pending_term " above " __name ", which is " reach_of(__name, line) "; open on " __want)
    return
  }
  note(pending_at, "function doc opens on " pending_term "; " __name " is " reach_of(__name, line) ", so it opens on " __want)
}

# Reads one line inside a heredoc: the closer ends it, and a doc block's
# closer hands the block to the line that follows.
function read_heredoc_line(line) {
  if (!closes_heredoc(line)) {
    return
  }
  in_heredoc = 0
  if (in_doc) {
    in_doc = 0
    awaiting = 1
  }
}

# Reads one line of code: settles the doc block that just closed against it,
# unless it is a comment addressed to a tool, and opens the heredoc it starts.
function read_code_line(line) {
  if (awaiting && !is_comment(line)) {
    settle_block(line)
  }
  if (opens_heredoc(line)) {
    in_heredoc = 1
    if (opens_doc_block(line)) {
      in_doc = 1
      pending_at = FNR
      pending_term = term
    }
  }
}

# Resets to the state a fresh file starts in.
function begin_file() {
  library = is_library(file_key(FILENAME))
  awaiting = 0
  in_heredoc = 0
  in_doc = 0
}

FNR == 1 {
  begin_file()
}

{
  if (in_heredoc) {
    read_heredoc_line($0)
  } else {
    read_code_line($0)
  }
}

END {
  if (awaiting) {
    settle_block("")
  }
}
