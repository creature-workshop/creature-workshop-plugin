# The file-label check. Loaded with the scanner runtime and the doc-block
# library:
#
#   awk -v root=<repository root> -f scan.awk -f doc_block.awk -f file_label.awk
#
# Finds, in the files given:
#
#   - a library file whose file doc opens on anything but MODULE or FRAGMENT
#   - a MODULE or FRAGMENT label on a block that is not a file doc
#   - an entrypoint whose top doc is a doc block rather than its HELP usage
#   - an import of a FRAGMENT from outside the fragment's own directory
#
# The rules it reads by:
#
#   - A doc block documents the line right after its closer. A `#` line
#     between them, a shellcheck directive, does not part them; a blank
#     line does.
#   - The file doc is the first doc block met before any function that
#     documents no definition.
#   - A library file is a .sh under lib/ or interpreter/ that is not a
#     plugin (*.op.sh). Its file doc opens on MODULE when a file outside its
#     directory imports it, and on FRAGMENT otherwise (ADR 000039).
#   - An entrypoint, any other shell file, documents itself in its usage,
#     opened on HELP (ADR 000039). A plugin's file doc is not ruled yet.
#   - A fragment is its directory's own. An import of one from another
#     directory is the private reach ADR 000031 names.
#   - `# file-label-check: allow` within three lines above a block exempts
#     it, for a file that is neither a module nor an entrypoint.
#
# Only the files given are read, so an importer outside them is seen in the
# full sweep alone, and the verdict on imports waits until every file is
# read.
#
# Output: "<name>:<lineno>: <message>", <lineno> being FNR, awk's line number
# within the current file. Vars: -v root=<dir> keys the files under the
# repository root; -v fname=<display name> (default FILENAME).

# The file's key: its path under the repository root, `lib/git/api.sh`. A
# path outside the root is keyed from its last lib/ or interpreter/
# component, so a fixture written elsewhere is still a library file; a path
# with neither keys to nothing.
function file_key(path) {
  if (root != "" && index(path, root "/") == 1) {
    return repo_key(path)
  }
  return library_key(path)
}

# The directory a key sits in: `lib/git` for `lib/git/api.sh`.
function dir_of(key) {
  sub(/\/[^\/]*$/, "", key)
  return key
}

# True when KEY is a plugin, whose file doc is not ruled yet.
function is_plugin(key) {
  return (key ~ /\.op\.sh$/)
}

# True when KEY is a library file: a .sh under a library root
# (library_root.awk) that is not a plugin. An executable under lib/ with no
# suffix is an entrypoint.
function is_library(key) {
  return (under_library_root(key) && key ~ /\.sh$/ && !is_plugin(key))
}

# True when LINE carries this check's own allow marker.
function is_allow_marker(line) {
  return (line ~ /file-label-check:[ \t]*allow/)
}

# True when an allow marker sits within the three lines above the pending
# block, or on its opener.
function pending_allowed() {
  return (allow_at >= pending_at - 3 && allow_at <= pending_at)
}

# True when TERM is one of the two labels a file doc opens on.
function is_file_label(term) {
  return (term == "MODULE" || term == "FRAGMENT")
}

# Records every library path LINE imports as an edge from this file's
# directory, so the fragment reach is judged once every file has been read.
# RSTART and RLENGTH are copied out as soon as match sets them: any function
# called before the loop advances may run a match of its own and reset them,
# and a loop that then fails to advance never ends.
function record_imports(line, __start, __length, __matched, __target) {
  while (match(line, /\$(SHELLOPS_DIR|PROJ)\/[A-Za-z0-9_.\/-]+\.sh/)) {
    __start = RSTART
    __length = RLENGTH
    __matched = substr(line, __start, __length)
    __target = substr(__matched, index(__matched, "/") + 1)
    line = substr(line, __start + __length)
    if (!under_library_root(__target)) {
      continue
    }
    edges++
    edge_file[edges] = display_name()
    edge_line[edges] = FNR
    edge_dir[edges] = dir_of(key)
    edge_target[edges] = __target
  }
}

# Opens the doc block that starts on this line: the first one met before
# any function is the file doc candidate, settled by its follower, and one
# settled as a definition's doc hands the candidacy to the next; every
# later one may carry any label but a file doc's.
function open_doc() {
  in_doc = 1
  if (!first_doc_seen && functions_seen == 0) {
    first_doc_seen = 1
    pending_first = 1
    pending_at = FNR
    pending_term = term
    return
  }
  first_doc_seen = 1
  if (is_file_label(term)) {
    note(FNR, term " names a file doc; this block is not the file's first, or a function comes before it")
  }
}

# Closes the doc block on this line: the file doc candidate is then settled
# by the line that follows.
function close_doc() {
  in_doc = 0
  if (pending_first) {
    awaiting = 1
  }
}

# Settles the file doc candidate from the line FOLLOWER right after its
# closer (empty at end of file). One followed by a definition, a function,
# a root assignment or an enum declaration, documents that definition and
# is no file doc; any other is the file's, and is judged by what the file
# is.
function settle_first_doc(follower) {
  awaiting = 0
  pending_first = 0
  if (pending_allowed()) {
    return
  }
  if (is_func_def(follower) || follower ~ /^(readonly[ \t]+|export[ \t]+)?[A-Za-z_][A-Za-z0-9_]*=/ || follower ~ /^@enum[ \t]/) {
    first_doc_seen = 0
    if (is_file_label(pending_term)) {
      note(pending_at, pending_term " names a file doc; this block documents the definition below it")
    }
    return
  }
  if (is_plugin(key)) {
    return
  }
  if (!library) {
    note(pending_at, "a doc block at the top of an entrypoint; an entrypoint documents itself in its usage, opened on HELP")
    return
  }
  if (!is_file_label(pending_term)) {
    note(pending_at, "file doc opens on " pending_term "; a library file's opens on MODULE when consumers import it, FRAGMENT when only its module does")
    return
  }
  label[key] = pending_term
}

# Reports every import of a FRAGMENT from a directory other than its own.
function report_fragment_reach(__i, __target) {
  for (__i = 1; __i <= edges; __i++) {
    __target = edge_target[__i]
    if (!(__target in label) || label[__target] != "FRAGMENT") {
      continue
    }
    if (edge_dir[__i] == dir_of(__target)) {
      continue
    }
    printf "%s:%d: %s\n", edge_file[__i], edge_line[__i],
      "imports " __target ", a FRAGMENT of " dir_of(__target) "; only its own module imports a fragment"
  }
}

# Reads one line inside a heredoc: the closer ends it, and a doc block's
# closer hands the block to its follower.
function read_heredoc_line(line) {
  if (!closes_heredoc(line)) {
    return
  }
  in_heredoc = 0
  if (in_doc) {
    close_doc()
  }
}

# Reads one line of code: settles a doc block that just closed against it,
# records what it imports, counts the function it defines, and opens the
# heredoc it starts.
function read_code_line(line) {
  if (is_allow_marker(line)) {
    allow_at = FNR
  }
  if (awaiting && !is_comment(line)) {
    settle_first_doc(line)
  }
  # A path in a comment is prose and not an import.
  if (is_comment(line)) {
    return
  }
  record_imports(line)
  if (is_func_def(line)) {
    functions_seen++
  }
  if (opens_heredoc(line)) {
    in_heredoc = 1
    if (opens_doc_block(line)) {
      open_doc()
    }
  }
}

# Resets to the state a fresh file starts in.
function begin_file() {
  key = file_key(FILENAME)
  library = is_library(key)
  functions_seen = 0
  first_doc_seen = 0
  pending_first = 0
  awaiting = 0
  allow_at = -10
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
    settle_first_doc("")
  }
  report_fragment_reach()
}
