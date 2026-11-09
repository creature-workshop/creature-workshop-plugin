# Reads the report of `git status --porcelain=v2 --branch` on stdin and
# prints the repository's state as one JSON object: the branch, or the
# first seven characters of the commit when HEAD is detached; whether the
# branch has an upstream; how far it is ahead of and behind that upstream;
# and how many paths are staged, modified in the working tree, untracked or
# in conflict. A path changed in both the index and the working tree counts
# once as staged and once as modified.
#
#   # branch.oid 4f2a9c1e...
#   # branch.head main
#   # branch.upstream origin/main
#   # branch.ab +1 -0
#   1 M. N... 100644 100644 100644 abc abc a.txt
#   ? new.txt
#
# prints
#
#   {"branch": "main", "detached": false, "upstream": true, "ahead": 1, "behind": 0,
#    "staged": 1, "modified": 0, "untracked": 1, "conflicted": 0}

function main(line) {
  if (is_header(line)) {
    read_header(line)
    return
  }
  count_entry(line)
}

function is_header(line) {
  return substr(line, 1, 2) == "# "
}

# Keeps a header line's value under its key: `# branch.ab +1 -0` keeps
# "+1 -0" under "branch.ab".
function read_header(line, __rest, __key) {
  __rest = substr(line, 3)
  __key = __rest
  sub(/ .*/, "", __key)
  header[__key] = substr(__rest, length(__key) + 2)
}

# Counts one entry line by the kind its first character names: `?` for an
# untracked path, `u` for a path in conflict, and `1` or `2` for a changed
# or renamed path. Other kinds, such as `!` for an ignored path, count nothing.
function count_entry(line, __kind) {
  __kind = substr(line, 1, 1)
  if (__kind == "?") {
    count_untracked()
  } else if (__kind == "u") {
    count_conflicted()
  } else if (__kind == "1" || __kind == "2") {
    count_change(substr(line, 3, 2))
  }
}

function count_untracked() {
  untracked++
}

function count_conflicted() {
  conflicted++
}

# Counts a changed path by its XY code: X is the index's change and Y the
# working tree's, with `.` for no change.
function count_change(xy) {
  if (substr(xy, 1, 1) != ".") {
    staged++
  }
  if (substr(xy, 2, 1) != ".") {
    modified++
  }
}

function report() {
  printf "{\"branch\": %s, \"detached\": %s, \"upstream\": %s, ", json_string(branch_text()), json_bool(is_detached()), json_bool("branch.upstream" in header)
  printf "\"ahead\": %d, \"behind\": %d, ", ahead_behind(1), ahead_behind(2)
  printf "\"staged\": %d, \"modified\": %d, \"untracked\": %d, \"conflicted\": %d}\n", staged, modified, untracked, conflicted
}

function is_detached() {
  return header["branch.head"] == "(detached)"
}

function branch_text() {
  if (is_detached()) {
    return substr(header["branch.oid"], 1, 7)
  }
  return header["branch.head"]
}

# The commits ahead (which 1) or behind (which 2) the upstream, from the
# `+<ahead> -<behind>` value of branch.ab; 0 when the branch has no upstream.
function ahead_behind(which, __counts) {
  if (!("branch.ab" in header)) {
    return 0
  }
  split(header["branch.ab"], __counts, " ")
  return substr(__counts[which], 2) + 0
}

function json_bool(value) {
  if (value) {
    return "true"
  }
  return "false"
}

# A string as a JSON string. A git branch name holds no backslash and no
# control character, so a double quote is the only character to escape.
function json_string(text, __parts, __count, __i, __out) {
  __count = split(text, __parts, "\"")
  __out = __parts[1]
  for (__i = 2; __i <= __count; __i++) {
    __out = __out "\\\"" __parts[__i]
  }
  return "\"" __out "\""
}

END { report() }

{ main($0) }
