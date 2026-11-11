# Prints the records of the manifest reader as the edges they make between
# manifests. A path dependency is an edge to the manifest under the path,
# taken from the directory of the manifest that depends on it. A
# `workspace = true` dependency is an edge to the path that the nearest
# workspace root above the manifest declares for it, taken from that
# root's directory. A dependency that the root declares without a path, or
# that no root declares, comes from a registry and makes no edge. Loaded
# after testing.awk and edges.awk.
#
# Input: the lines of manifest_deps.awk, a list of
#        "<kind>\t<manifest>\t<name>[\t<path>]", where kind is dep,
#        workspace or root.
#
#   "dep\tengine/cli/Cargo.toml\tparser\t../parser"
#   ->  {from: "engine/cli/Cargo.toml", to: "engine/parser/Cargo.toml"}

function main(line) {
  tree_line(line)
}

# Reads every record into KIND, MANIFEST, NAME and PATH, with HAS_PATH for
# whether it has a path, and notes what each workspace root declares.
function read_records(__line, __fields, __count) {
  RECORDS = 0

  for (__line = NODE_FIRST[ROOT]; __line != 0; __line = NODE_NEXT[__line]) {
    __count = split(text_of(__line), __fields, "\t")
    RECORDS++
    KIND[RECORDS] = __fields[1]
    MANIFEST[RECORDS] = __fields[2]
    NAME[RECORDS] = __fields[3]
    HAS_PATH[RECORDS] = (__count >= 4)
    PATH[RECORDS] = (__count >= 4) ? __fields[4] : ""

    if (KIND[RECORDS] == "root") {
      note_declaration(RECORDS)
    }
  }
}

# Notes what the workspace root of a record declares for a name, the last
# declaration of a name being the one kept. Root n is WORKSPACE[n].
function note_declaration(record) {
  if (!(MANIFEST[record] in IS_WORKSPACE)) {
    IS_WORKSPACE[MANIFEST[record]] = 1
    WORKSPACE[++WORKSPACES] = MANIFEST[record]
  }

  DECLARES_PATH[MANIFEST[record], NAME[record]] = HAS_PATH[record]
  DECLARED_PATH[MANIFEST[record], NAME[record]] = PATH[record]
}

# The directory a manifest is in, and "." for one at the project's root.
function directory_of(manifest) {
  if (index(manifest, "/") == 0) {
    return "."
  }

  sub(/\/[^\/]*$/, "", manifest)
  return manifest
}

# A path without its "." and ".." parts: a/./b/../c is a/c.
function normalized(path, __parts, __count, __i, __kept, __depth, __out) {
  __count = split(path, __parts, "/")
  __depth = 0

  for (__i = 1; __i <= __count; __i++) {
    if (__parts[__i] == "" || __parts[__i] == ".") {
      continue
    }
    if (__parts[__i] == "..") {
      __depth = (__depth > 0) ? __depth - 1 : 0
      continue
    }
    __kept[++__depth] = __parts[__i]
  }

  __out = ""
  for (__i = 1; __i <= __depth; __i++) {
    __out = (__i == 1) ? __kept[1] : __out "/" __kept[__i]
  }

  return __out
}

# The manifest at a path taken from a directory.
function manifest_at(directory, path) {
  return normalized(directory "/" path) "/Cargo.toml"
}

# Whether a directory is the directory of a manifest or one above it.
function encloses(directory, manifest) {
  return directory == "." || index(manifest, directory "/") == 1
}

# Whether the nearest workspace root above the manifest of a record
# declares a path for the record's name. Sets TARGET to the manifest at
# that path.
function workspace_target(record, __i, __directory, __nearest, __length, __found) {
  __found = 0
  __length = -1

  for (__i = 1; __i <= WORKSPACES; __i++) {
    __directory = directory_of(WORKSPACE[__i])
    if (!encloses(__directory, MANIFEST[record]) || !DECLARES_PATH[WORKSPACE[__i], NAME[record]]) {
      continue
    }
    if (depth_of(__directory) > __length) {
      __length = depth_of(__directory)
      __nearest = WORKSPACE[__i]
      __found = 1
    }
  }

  if (__found) {
    TARGET = manifest_at(directory_of(__nearest), DECLARED_PATH[__nearest, NAME[record]])
  }
  return __found
}

# How far a directory is below the project's root, as the length of its
# path: 0 for the root itself.
function depth_of(directory) {
  return (directory == ".") ? 0 : length(directory)
}

# Whether a record makes an edge. Sets TARGET to the manifest the edge
# ends at.
function has_target(record) {
  if (KIND[record] == "dep") {
    TARGET = manifest_at(directory_of(MANIFEST[record]), PATH[record])
    return 1
  }
  if (KIND[record] == "workspace") {
    return workspace_target(record)
  }

  return 0
}

BEGIN {
  ROOT = tree_open()
  WORKSPACES = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  read_records()
  for (record = 1; record <= RECORDS; record++) {
    if (has_target(record)) {
      note_edge(MANIFEST[record], TARGET)
    }
  }
  print_edges()
}

{ main($0) }
