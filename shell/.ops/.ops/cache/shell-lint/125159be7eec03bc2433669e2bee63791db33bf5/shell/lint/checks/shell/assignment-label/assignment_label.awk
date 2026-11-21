# The assignment-label check. Loaded with the scanner runtime and the
# doc-block library:
#
#   awk -v root=<repository root> -f scan.awk -f doc_block.awk -f assignment_label.awk
#
# Finds, in the files given:
#
#   - a doc above a root constant or variable that opens on anything but
#     CONST, PUB_CONST, VAR or PUB_VAR
#   - one of those labels on a block that no root assignment follows
#   - a label that disagrees with the name
#   - a root assignment right below a documented one with no doc of its own
#
# The rules it reads by:
#
#   - An assignment doc is a doc block whose closer is followed by a root
#     assignment (`name=`, `readonly name=`, `export name=`) or an enum
#     declaration (`@enum name ...`). A `#` line between them does not part
#     them; a blank line does. A block labelled as the file's doc is the
#     file-label check's whatever follows it.
#   - CONST is for a name whose last `__` segment is upper case, VAR for any
#     other (ADR 000031).
#   - PUB_ goes in front in a library file when the name has no leading
#     `__`. An entrypoint's names take no prefix (ADR 000039).
#   - Each constant carries its own doc: one right below a documented one,
#     with none, reads as sharing the doc above and is a finding.
#
# The lowering reads the label for the name's kind and visibility (ADR
# 000039), so the label and the name have to agree.
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

# True when KEY is a library file: under a library root (library_root.awk),
# and not a template for an entrypoint.
function is_library(key) {
  return (under_library_root(key) && key !~ /\.template\.sh$/)
}

# True when TERM labels a file doc, which documents the file and not the
# assignment that happens to follow it (the file-label check judges those).
function is_file_label(term) {
  return (term == "MODULE" || term == "FRAGMENT" || term == "HELP")
}

# True when LINE is the one-line doc form: a `#` comment leading with one of
# the four labels (ADR 000040).
function is_typed(line) {
  return (line ~ /^# (CONST|PUB_CONST|VAR|PUB_VAR): /)
}

# True when LINE assigns a name at the root of the file or declares an enum.
# A root assignment starts at column zero, so one inside a function body is
# not mistaken for a module's.
function is_assignment(line) {
  return (line ~ /^(readonly[ \t]+|export[ \t]+)?[A-Za-z_][A-Za-z0-9_]*=/ || line ~ /^@enum[ \t]+[A-Za-z_]/)
}

# The name the assignment LINE binds: `__git__REMOTE` from
# `__git__REMOTE=origin`, `versions__LEVEL` from `@enum versions__LEVEL ...`.
function assigned_name(line, __name) {
  __name = line
  sub(/^(readonly|export|@enum)[ \t]+/, "", __name)
  sub(/[=[ \t].*$/, "", __name)
  return __name
}

# True when NAME is a constant's: its last `__` segment is upper case.
function is_constant_name(name, __last) {
  __last = name
  while (index(__last, "__") > 0) {
    __last = substr(__last, index(__last, "__") + 2)
  }
  return (__last ~ /^[A-Z][A-Z0-9_]*$/)
}

# The label the doc of NAME, assigned on LINE, opens on.
function expected_label(name, line, __kind) {
  __kind = is_constant_name(name) ? "CONST" : "VAR"
  if (!library || name ~ /^__/) {
    return __kind
  }
  return "PUB_" __kind
}

# What NAME is to its callers, for the finding's prose.
function reach_of(name) {
  if (!library) {
    return "an entrypoint's"
  }
  if (name ~ /^__/) {
    return "private to its module"
  }
  return "public"
}

# Judges the doc block that just closed against its follower LINE, the line
# right after its closer (empty at end of file). One followed by a root
# assignment is judged against the name; any other may carry any label but
# an assignment doc's.
function settle_block(follower, __name, __want) {
  awaiting = 0
  if (is_file_label(pending_term)) {
    return
  }
  if (!is_assignment(follower)) {
    if (is_assignment_label(pending_term)) {
      note(pending_at, pending_term " names a variable or constant doc; this block is not followed by a root assignment")
    }
    return
  }
  __name = assigned_name(follower)
  __want = expected_label(__name, follower)
  if (pending_term == __want) {
    return
  }
  if (is_assignment_label(pending_term)) {
    note(pending_at, pending_term " above " __name ", which is " reach_of(__name) "; open on " __want)
    return
  }
  note(pending_at, "doc above " __name " opens on " pending_term "; the name is " reach_of(__name) ", so it opens on " __want)
}

# Judges the root assignment LINE against its neighbour above, DOCUMENTED
# saying whether a doc sits right above LINE itself: one right below a
# documented assignment with no doc of its own reads as sharing the doc above,
# and is a finding. It then counts as documented for the line below it, so
# every member of such a run is reported.
function judge_neighbour(line, documented) {
  if (!documented && last_doc_at == FNR - 1) {
    note(FNR, assigned_name(line) " sits right below a documented assignment with no doc of its own; each constant or variable carries its own")
    documented = 1
  }
  if (documented) {
    last_doc_at = FNR
  }
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

# Reads one line of code. A comment is skipped, a typed one remembered as the
# doc of the line below. Any other line settles the doc block that just
# closed, is judged against its neighbour above when it is a root assignment,
# and opens the heredoc it starts.
function read_code_line(line, __documented) {
  if (is_comment(line)) {
    if (is_typed(line)) {
      typed_pending = 1
    }
    return
  }
  __documented = (typed_pending || (awaiting && !is_file_label(pending_term)))
  typed_pending = 0
  if (awaiting) {
    settle_block(line)
  }
  if (is_assignment(line)) {
    judge_neighbour(line, __documented)
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
  typed_pending = 0
  last_doc_at = -10
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
