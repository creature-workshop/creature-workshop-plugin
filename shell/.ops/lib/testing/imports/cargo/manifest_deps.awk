# Prints what each Cargo manifest declares about the crates it depends on,
# one record per line, tab-separated:
#
#   dep        <manifest>  <name>  <path>   a dependency with a path, relative
#                                           to the manifest's directory
#   workspace  <manifest>  <name>           a `workspace = true` dependency
#   root       <manifest>  <name>  <path>   a [workspace.dependencies] entry
#                                           with a path, relative to the root
#
# Dependencies are read under [dependencies], [dev-dependencies],
# [build-dependencies] and their [target.'cfg'.…] forms, written either
# inline (`name = { path = "../x" }`) or as a table ([dependencies.name] with
# `path = "../x"` on a following line). A dependency with neither a path nor
# `workspace = true` comes from a registry and is not recorded.

# The name between a header line's brackets, whitespace trimmed.
function header_name(line, __name) {
  __name = line
  sub(/^[ \t]*\[/, "", __name)
  sub(/\][ \t]*(#.*)?$/, "", __name)
  gsub(/^[ \t]+|[ \t]+$/, "", __name)
  return __name
}

function is_dependency_section(name) {
  return name ~ /^(target\..*\.)?(dev-|build-)?dependencies$/
}

function is_root_section(name) {
  return name == "workspace.dependencies"
}

# The dependency a table header names ([dependencies.serde] -> serde), or
# nothing for a header that is not one.
function dependency_of_table(name, __dep) {
  if (name ~ /^(target\..*\.)?(dev-|build-)?dependencies\..+$/ || name ~ /^workspace\.dependencies\..+$/) {
    __dep = name
    sub(/^.*dependencies\./, "", __dep)
    return unquoted(__dep)
  }
  return ""
}

# The section a table header belongs to ([dependencies.serde] -> dependencies).
function section_of_table(name, __section) {
  __section = name
  sub(/\.[^.]*$/, "", __section)
  return __section
}

# The key a `key = value` line assigns, quotes stripped.
function key_of(line, __key) {
  __key = line
  sub(/[ \t]*=.*$/, "", __key)
  gsub(/^[ \t]+/, "", __key)
  return unquoted(__key)
}

function unquoted(word) {
  gsub(/^"|"$/, "", word)
  return word
}

# The value of a `path = "..."` field on the line, or nothing.
function path_of(line, __path) {
  if (!match(line, /path[ \t]*=[ \t]*"[^"]*"/)) {
    return ""
  }
  __path = substr(line, RSTART, RLENGTH)
  sub(/^path[ \t]*=[ \t]*"/, "", __path)
  sub(/"$/, "", __path)
  return __path
}

function defers_to_workspace(line) {
  return line ~ /workspace[ \t]*=[ \t]*true/
}

# The kind a section's path records carry: what the root declares, or a
# dependency of the manifest itself.
function path_kind(section) {
  return is_root_section(section) ? "root" : "dep"
}

# Record one line inside a [dependencies.name] table.
function record_table_line(section, dep, line, __path) {
  __path = path_of(line)
  if (__path != "") {
    printf "%s\t%s\t%s\t%s\n", path_kind(section_of_table(section)), FILENAME, dep, __path
  } else if (defers_to_workspace(line)) {
    printf "workspace\t%s\t%s\n", FILENAME, dep
  }
}

# Record one `name = ...` line of an inline dependency section.
function record_inline_line(section, line, __name, __path) {
  if (line !~ /^[ \t]*"?[A-Za-z0-9_-]+"?[ \t]*=/) {
    return
  }
  __name = key_of(line)
  __path = path_of(line)
  if (__path != "") {
    printf "%s\t%s\t%s\t%s\n", path_kind(section), FILENAME, __name, __path
  } else if (defers_to_workspace(line)) {
    printf "workspace\t%s\t%s\n", FILENAME, __name
  }
}

FNR == 1 {
  section = ""
  table_dep = ""
}

/^[ \t]*\[/ {
  section = header_name($0)
  table_dep = dependency_of_table(section)
  next
}

table_dep != "" {
  record_table_line(section, table_dep, $0)
  next
}

is_dependency_section(section) || is_root_section(section) {
  record_inline_line(section, $0)
}
