# Reads, on stdin, the report of `git status --porcelain=v2 --no-renames
# --untracked-files=all --ignored=matching -- <path>` for one file, and
# prints the file's state in git as one word: clean, modified, new,
# deleted, conflict or none.
#
# The variable `exists` says whether the file is in the working tree, as
# true or false. A report that lists nothing means git sees no change, so
# the file is clean when it exists, and git has nothing to say about it
# when it does not.
#
#   1 .M N... 100644 100644 100644 abc abc .ops/config/manifest.yaml
#
# prints
#
#   modified

function main(line) {
  if (line == "" || listed) {
    return
  }
  listed = 1
  state = entry_state(line)
}

# The state one entry line stands for, by the kind its first character
# names.
function entry_state(line, __kind) {
  __kind = substr(line, 1, 1)
  if (__kind == "?") {
    return untracked_state()
  }
  if (__kind == "u") {
    return unmerged_state()
  }
  if (__kind == "!") {
    return ignored_state()
  }
  return changed_state(substr(line, 3, 2))
}

# A file git does not track yet: the commit has no copy of it.
function untracked_state() {
  return "new"
}

# A file a merge left in conflict.
function unmerged_state() {
  return "conflict"
}

# A file git ignores, about which it has nothing to say.
function ignored_state() {
  return "none"
}

# The state of a tracked file from its XY code: X is the index's change
# and Y the working tree's. A deletion on either side reads as deleted,
# before an addition in the index reads as new.
function changed_state(xy) {
  if (index(xy, "D") > 0) {
    return "deleted"
  }
  if (substr(xy, 1, 1) == "A") {
    return "new"
  }
  return "modified"
}

# The state of a file the report does not list.
function unlisted_state() {
  if (exists == "true") {
    return "clean"
  }
  return "none"
}

function report() {
  if (listed) {
    print state
    return
  }
  print unlisted_state()
}

END { report() }

{ main($0) }
