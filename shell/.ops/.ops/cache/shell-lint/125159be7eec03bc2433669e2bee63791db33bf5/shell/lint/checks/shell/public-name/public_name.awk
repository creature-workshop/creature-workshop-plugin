# A public name in a library file begins with that file's module path.
# Loaded with the scanner runtime and the prefix library:
#
#   awk -v root=<repository root> -f scan.awk -f name_prefix.awk -f public_name.awk
#
# The module path is the directories under lib/ or interpreter/, joined by
# __; the import barrel, api.sh, is the module itself, so its stem is never a
# segment. A function
# whose name begins with __ is private and belongs to the private-name
# check; a role, whose name begins with @, is the interpreter's.
# A line carrying `# public-name-check: allow` is left alone. A name inside
# a comment or a heredoc is not read. A call is not a definition, so another
# module's public name written here is left alone.
#
# Output: "<name>:<lineno>: <message>". Vars: -v root=<dir> keys a file
# under the repository root; -v fname=<display name> (default FILENAME).

# The name LINE defines, or nothing when LINE defines nothing: a definition
# ends its line on the opening brace or on the parentheses, so a call inside
# a quoted program, `look();`, is not one. A `function` keyword is dropped;
# the parameter list is not part of the name.
function defined_name(line, __name) {
  if (!is_func_def(line) || line !~ /\(\)[ \t]*(\{.*)?$/) {
    return ""
  }
  __name = line
  sub(/^[ \t]*/, "", __name)
  sub(/^function[ \t]+/, "", __name)
  sub(/[ \t]*\(.*/, "", __name)
  return __name
}

# The enum LINE declares, or nothing when LINE is not an @enum.
function enum_name(line, __name) {
  if (line !~ /^@enum[ \t]+[A-Za-z_][A-Za-z0-9_]*/) {
    return ""
  }
  __name = line
  sub(/^@enum[ \t]+/, "", __name)
  sub(/[^A-Za-z0-9_].*/, "", __name)
  return __name
}

# True when NAME is a private name or a role, neither of which this check
# judges.
function is_private_or_role(name) {
  return (name ~ /^(__|@)/)
}

# True when NAME spells the barrel's stem, the module's own file, as the
# segment after the module path.
function names_barrel(name) {
  return substr(name, length(prefix) + 1) ~ ("^" barrel_stem() "(__|$)")
}

# Reports NAME when this file's module does not own it.
function judge_name(name) {
  if (name == "" || is_private_or_role(name)) {
    return
  }
  if (index(name, prefix) != 1) {
    note(FNR, "public name " name " does not begin with " prefix)
    return
  }
  if (names_barrel(name)) {
    note(FNR, "public name " name " spells " barrel_stem() ", the module's own file, as a segment")
  }
}

# Reports a public definition on LINE that this file's module does not own.
function judge_line(line) {
  if (prefix == "") {
    return
  }
  if (is_comment(line)) {
    return
  }
  if (line ~ /public-name-check:[ \t]*allow/) {
    return
  }
  judge_name(defined_name(line))
  judge_name(enum_name(line))
}

# Resets to the state a fresh file starts in.
function begin_file() {
  in_heredoc = 0
  prefix = public_prefix(library_key(FILENAME))
}

# Reads one line inside a heredoc: the closer ends it.
function read_heredoc(line) {
  if (closes_heredoc(line)) {
    in_heredoc = 0
  }
}

# Reads one line of code.
function read_line(line) {
  judge_line(line)
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
