# Prints the path dependencies between the members of a cargo workspace, a
# list of {consumer, dep}: the manifest of the member that depends, and the
# name of the member it depends on.
#
# Input: cargo metadata (--no-deps)

function main(line) {
  tree_line(line)
}

# Notes the packages that are workspace members, and their names.
function note_members(__id, __package) {
  for (__id = NODE_FIRST[member(ROOT, "workspace_members")]; __id != 0; __id = NODE_NEXT[__id]) {
    IS_MEMBER_ID[text_of(__id)] = 1
  }

  for (__package = NODE_FIRST[member(ROOT, "packages")]; __package != 0; __package = NODE_NEXT[__package]) {
    if (text_of(member(__package, "id")) in IS_MEMBER_ID) {
      IS_MEMBER_NAME[text_of(member(__package, "name"))] = 1
    }
  }
}

# Prints the dependencies of one member that have a path and name another
# member.
function print_dependencies(package, __dependency) {
  for (__dependency = NODE_FIRST[member(package, "dependencies")]; __dependency != 0; __dependency = NODE_NEXT[__dependency]) {
    if (is_present(member(__dependency, "path")) && (text_of(member(__dependency, "name")) in IS_MEMBER_NAME)) {
      print_open(0, EDGES, "map")
      print_node(member(package, "manifest_path"), 1, wrap("consumer"))
      print_node(member(__dependency, "name"), 1, wrap("dep"))
      EDGES++
    }
  }
}

BEGIN {
  ROOT = tree_open()
  EDGES = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  note_members()
  for (package = NODE_FIRST[member(ROOT, "packages")]; package != 0; package = NODE_NEXT[package]) {
    if (text_of(member(package, "id")) in IS_MEMBER_ID) {
      print_dependencies(package)
    }
  }

  if (EDGES == 0) {
    print "0.:list"
  }
}

{ main($0) }
