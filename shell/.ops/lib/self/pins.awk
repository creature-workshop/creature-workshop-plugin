# The git trees of a lock, one per line, read by nesting with
# lib/self/lock/lines.awk and no JSON reader: every map under
# dependencies.imports and dependencies.tools.git is one entry, and its
# scalar members are its fields. A lock written before those maps existed
# keeps its trees under dependencies.git, which is read the same way. Each
# line is the entry's fields separated by "|":
#
#   <name>|<commit>|<repository>|<via>|<mount>
#
# A field the entry does not carry is empty. An import pins its commit
# under commit, and a tool of the git channel under version, as every
# channel does. The git channel's lines come first and the imports' last,
# so that when one name is in both, the tool the repository pins itself is
# pinned first and its variable stands. The boot reads the lock this way
# before the structs library has loaded. The input is read to its end.
#
#   awk -f lines.awk -f pins.awk .ops/lock

function is_tree_map(p) {
  return p == "dependencies.imports" || p == "dependencies.tools.git" || p == "dependencies.git"
}

function begin_entry(line) {
  name = key(line)
  entry_path = path() "." name
  commit = ""
  repository = ""
  via = ""
  mount = ""
}

function take_field(line, __k) {
  __k = key(line)
  if (__k == "commit" || __k == "version") {
    commit = value(line)
  } else if (__k == "repository") {
    repository = value(line)
  } else if (__k == "via") {
    via = value(line)
  } else if (__k == "mount") {
    mount = value(line)
  }
}

function keep_entry(p, __line) {
  __line = name "|" commit "|" repository "|" via "|" mount
  if (p == "dependencies.tools.git") {
    tools[++tools_n] = __line
  } else {
    imports[++imports_n] = __line
  }
  name = ""
}

opens_map($0) {
  if (is_tree_map(path())) {
    begin_entry($0)
  }
  enter($0)
  next
}

closes_map($0) {
  leave()
  if (name != "" && is_tree_map(path())) {
    keep_entry(path())
  }
  next
}

is_member($0) && name != "" && path() == entry_path {
  take_field($0)
}

END {
  for (__i = 1; __i <= tools_n; __i++) {
    print tools[__i]
  }
  for (__i = 1; __i <= imports_n; __i++) {
    print imports[__i]
  }
}
