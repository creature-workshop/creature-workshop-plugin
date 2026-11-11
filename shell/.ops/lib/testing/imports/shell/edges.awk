# Prints the load lines the scanner printed as the edges they make between
# files under the project. A target resolves when it is written under a
# declared root ("$SHELLOPS_DIR/lib/git/api.sh", with or without braces),
# or is a plain path, which is taken as a path under the project. A target
# built from any other variable cannot be read without running the file,
# and is left out, as is a file's load of itself. Loaded after testing.awk
# and edges.awk.
#
# Input: the scanner's lines, a list of "<file>\t<target>", and ahead of
#        it, with --with, the roots, {<variable name>: <directory>}.
# Args:  proj, the project's directory.
#
#   "lib/git/api.sh\t$SHELLOPS_DIR/lib/structs/api.sh", with SHELLOPS_DIR
#   the project's directory
#   ->  {from: "lib/git/api.sh", to: "lib/structs/api.sh"}

function main(line) {
  tree_line(line)
}

# Notes the edge of every line whose target resolves to another file.
function note_loads(__line, __fields, __from) {
  for (__line = NODE_FIRST[ROOT]; __line != 0; __line = NODE_NEXT[__line]) {
    split(text_of(__line), __fields, "\t")
    __from = __fields[1]
    if (resolves(__fields[2]) && RESOLVED != __from) {
      note_edge(__from, RESOLVED)
    }
  }
}

# Whether a target names a file that can be read from the text alone. Sets
# RESOLVED to the file's path, under the project when it is inside it.
function resolves(target) {
  if (is_under_root(target)) {
    RESOLVED = under_project(ROOT_DIR "/" ROOT_REST)
    return 1
  }
  if (index(target, "$") > 0) {
    return 0
  }

  RESOLVED = without_prefix(target, "./")
  return 1
}

# Whether a target is written under one of the roots, as $NAME/ or as
# ${NAME}/. Sets ROOT_DIR to the directory of the first such root and
# ROOT_REST to the target after the root.
function is_under_root(target, __root, __prefix) {
  for (__root = NODE_FIRST[ROOTS]; __root != 0; __root = NODE_NEXT[__root]) {
    __prefix = "$" name_of(__root) "/"
    if (index(target, __prefix) != 1) {
      __prefix = "${" name_of(__root) "}/"
    }
    if (index(target, __prefix) == 1) {
      ROOT_DIR = text_of(__root)
      ROOT_REST = substr(target, length(__prefix) + 1)
      return 1
    }
  }

  return 0
}

# A path under the project when it is inside the project's directory, and
# the path unchanged when it is not.
function under_project(path) {
  return without_prefix(path, arg("proj") "/")
}

# A text without a prefix it starts with, and the text unchanged when it
# does not start with it.
function without_prefix(text, prefix) {
  return (index(text, prefix) == 1) ? substr(text, length(prefix) + 1) : text
}

BEGIN {
  ROOTS = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  note_loads()
  print_edges()
}

{ main($0) }
