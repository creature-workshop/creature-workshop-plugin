# A name in a library file spells the file's stem as a segment of its own.
# Loaded with the scanner runtime and the prefix libraries:
#
#   awk -v root=<repository root> -f scan.awk -f library_root.awk -f name_prefix.awk -f file_segment.awk
#
# A file inside a module adds a segment: config.sh under lint defines
# lint__config__load, and that function's variables begin with
# __lint__config__load__. A name that follows the module path with the stem
# and one underscore, lint__config_load or __lint__config_load__file, spells
# the stem as a word of the next segment instead, and this check reports
# it. A public name, a private name and a variable are judged alike,
# wherever a line uses them, except a variable that carries the name of a
# function the file defines, __<function>__<name>: the naming rule gives a
# function's variables its name, so the function's line is where the
# finding is, and a function kept under the mark keeps its variables too.
# A dash in the stem reads as an underscore.
#
# A file with no stem to judge is left alone: the barrel api.sh, a plugin
# (.op.sh), a file that sits in a library root itself, whose stem is the
# module path, and any file name_prefix.awk gives no module path. A line
# carrying `# file-segment-check: allow` is left alone. A name inside a
# comment or a heredoc is not read.
#
# Output: "<name>:<lineno>: <message>". Vars: -v root=<dir> keys a file
# under the repository root; -v fname=<display name> (default FILENAME).

# The stem of KEY, the segment its names spell after the module path, or
# nothing when KEY has no stem to judge.
function file_stem(key, __rest, __base) {
  if (module_prefix(key) == "" || key ~ /\.op\.sh$/) {
    return ""
  }
  __rest = without_library_root(key)
  if (__rest !~ /\//) {
    return ""
  }
  __base = __rest
  sub(/^.*\//, "", __base)
  if (__base == barrel_stem() ".sh") {
    return ""
  }
  sub(/\.sh$/, "", __base)
  gsub(/-/, "_", __base)
  return __base
}

# What follows the module path in NAME: a public name begins with the path,
# a private one with __ and then the path. Nothing when NAME is not the
# module's.
function after_module_path(name) {
  if (index(name, prefix) == 1) {
    return substr(name, length(prefix) + 1)
  }
  if (index(name, "__" prefix) == 1) {
    return substr(name, length(prefix) + 3)
  }
  return ""
}

# True when NAME follows the module path with the stem and one underscore.
function misspells_stem(name) {
  return (after_module_path(name) ~ ("^" stem "_[^_]"))
}

# True when NAME is a variable of a function the file has defined so far:
# it begins with __, the function's name and __.
function carries_function_name(name, __function) {
  for (__function in functions) {
    if (index(name, "__" __function "__") == 1) {
      return 1
    }
  }
  return 0
}

# Records the function LINE defines, when it defines one, so the names
# that carry it are judged through it.
function record_function(line, __name) {
  if (!is_func_def(line)) {
    return
  }
  __name = line
  sub(/^[ \t]*function[ \t]+/, "", __name)
  sub(/[ \t]*\(.*$/, "", __name)
  functions[__name] = 1
}

# Reports NAME when it spells the stem with one underscore, unless it is a
# variable of a function the file defines, which is judged through its
# function.
function judge_name(name) {
  if (carries_function_name(name)) {
    return
  }
  if (misspells_stem(name)) {
    note(FNR, "name " name " spells " stem ", its file, with one underscore; the file is a segment, so the name begins " prefix stem "__")
  }
}

# True when LINE carries the marker that exempts it.
function is_allowed(line) {
  return line ~ /file-segment-check:[ \t]*allow/
}

# Reports every name on LINE that spells the stem with one underscore.
function judge_line(line, __rest, __name) {
  if (stem == "" || is_comment(line) || is_allowed(line)) {
    return
  }
  __rest = line
  while (match(__rest, /(^|[^A-Za-z0-9_])[A-Za-z_][A-Za-z0-9_]*/)) {
    __name = substr(__rest, RSTART, RLENGTH)
    if (__name !~ /^[A-Za-z_]/) {
      __name = substr(__name, 2)
    }
    judge_name(__name)
    __rest = substr(__rest, RSTART + RLENGTH)
  }
}

# Resets to the state a fresh file starts in.
function begin_file(__key) {
  in_heredoc = 0
  split("", functions)
  __key = library_key(FILENAME)
  prefix = public_prefix(__key)
  stem = file_stem(__key)
}

# Reads one line inside a heredoc: the closer ends it.
function read_heredoc(line) {
  if (closes_heredoc(line)) {
    in_heredoc = 0
  }
}

# Reads one line of code: judged, then its function recorded, so the
# function's own line is judged and the lines of its body know it.
function read_line(line) {
  judge_line(line)
  record_function(line)
  if (opens_heredoc(line)) {
    in_heredoc = 1
  }
}

FNR == 1 {
  begin_file()
}

{
  if (in_heredoc) {
    read_heredoc($0)
  } else {
    read_line($0)
  }
}
