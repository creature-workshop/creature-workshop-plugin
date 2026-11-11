# Lowers one structural contract to its plain functions: the outer
# @<kind>.<name>() is dropped, each inner @<role>() becomes <name>_<role>(),
# a call to @<role> inside a body becomes a call to <name>_<role>, and every
# other line inside the outer is written as it is, one indent level out. A
# heredoc body passes through untouched. What is read off the file is held to
# the kind: the outer must declare @<kind>.<name>, every role defined must be
# one the kind declares, and every required role must be defined; a failure
# is a diagnostic on stderr naming kind, plugin and role, and exit status 1.
#
# Vars: -v kind=<kind> -v name=<name> -v roles="<role> ..."
# -v required="<role> ..." -v source=<the path the header names>.
# Loaded after shell-scan's scan.awk, which supplies the heredoc tracking.

# Prints the header that marks the lowered file as generated, loud enough
# that nobody edits it: what it was lowered from, and that an edit is lost.
function print_generated_header() {
  print "# GENERATED FILE. DO NOT EDIT."
  printf "# Lowered from %s by kinds__lower. Any edit here is lost at the next\n", source
  print "# ops compile, and CI refuses the bundle while this file differs from what"
  print "# its source lowers to. Edit the source."
}

# Prints a heredoc body LINE as it is, wherever it sits: the text is what
# the shell sees, so it is never dedented or rewritten.
function pass_heredoc_line(line) {
  print line
  if (closes_heredoc(line)) {
    in_heredoc = 0
  }
}

# Reads LINE ahead of the outer: the outer's declaration opens it, and every
# other line is written as it is.
function read_before_outer(line) {
  if (is_outer(line)) {
    require_outer_name(line)
    outer_open = 1
    return
  }
  print line
  note_heredoc(line)
}

# Reads LINE after the outer has closed: written as it is.
function read_after_outer(line) {
  print line
  note_heredoc(line)
}

# Reads LINE inside the outer: a brace at column zero closes it, a role
# definition is held to the kind, and every line is written one indent
# level out with the roles named for the plugin.
function read_inside(line) {
  if (line ~ /^\}/) {
    outer_closed = 1
    return
  }
  if (is_role_def(line)) {
    require_declared(role_of(line))
  }
  print rewrite_roles(dedent(line))
  note_heredoc(line)
}

# Enters a heredoc when LINE opens one, so its body passes through as it is.
function note_heredoc(line) {
  if (opens_heredoc(line)) {
    in_heredoc = 1
  }
}

# True when LINE opens a structural contract, @<kind>.<name>() {.
function is_outer(line) {
  return line ~ /^@[A-Za-z_][A-Za-z0-9_]*\.[^( ]+\(\)[[:space:]]*\{[[:space:]]*$/
}

# Fails when the outer on LINE declares a plugin other than @<kind>.<name>.
function require_outer_name(line, __declared) {
  __declared = line
  sub(/\(\).*$/, "", __declared)
  if (__declared != "@" kind "." name) {
    fail("declares " __declared ", not @" kind "." name)
  }
}

# True when LINE defines an inner role, @<role>() {.
function is_role_def(line) {
  return line ~ /^[[:space:]]*@[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/
}

# The role the definition on LINE names.
function role_of(line, __role) {
  __role = line
  sub(/^[[:space:]]*@/, "", __role)
  sub(/\(\).*$/, "", __role)
  return __role
}

# Fails when ROLE is not one the kind declares; records it otherwise.
function require_declared(role) {
  if (!(role in declared)) {
    fail("defines @" role ", which the kind does not declare")
    return
  }
  defined[role] = 1
}

# Fails once per required role the plugin left undefined.
function require_required(__n, __list, __i) {
  __n = split(required, __list, " ")
  for (__i = 1; __i <= __n; __i++) {
    if (!(__list[__i] in defined)) {
      fail("does not define @" __list[__i])
    }
  }
}

# LINE with the outer's one level of indentation removed.
function dedent(line) {
  sub(/^  /, "", line)
  return line
}

# LINE with every @<role> the kind declares, at a word boundary, rewritten
# to <name>_<role>: the definitions and the calls alike.
function rewrite_roles(line, __i) {
  for (__i = 1; __i <= role_count; __i++) {
    line = rewrite_role(line, role_list[__i])
  }
  return line
}

# LINE with each @ROLE followed by a non-word character, or the end of the
# line, rewritten to <name>_ROLE.
function rewrite_role(line, role, __out, __at, __width) {
  __out = ""
  while (match(line, "@" role "([^A-Za-z0-9_]|$)")) {
    __at = RSTART
    __width = length(role) + 1
    __out = __out substr(line, 1, __at - 1) name "_" role
    line = substr(line, __at + __width)
  }
  return __out line
}

# Reports a diagnostic against the source, naming kind and plugin.
function fail(msg) {
  printf "%s: kind %s, plugin %s: %s\n", source, kind, name, msg > "/dev/stderr"
  failed = 1
}

BEGIN {
  role_count = split(roles, role_list, " ")
  for (__i = 1; __i <= role_count; __i++) {
    declared[role_list[__i]] = 1
  }
  outer_open = 0
  outer_closed = 0
  failed = 0
}

FNR == 1 && /^#!/ {
  print
  print_generated_header()
  next
}

{
  if (in_heredoc) {
    pass_heredoc_line($0)
  } else if (!outer_open) {
    read_before_outer($0)
  } else if (outer_closed) {
    read_after_outer($0)
  } else {
    read_inside($0)
  }
}

END {
  if (!outer_open) {
    fail("no @" kind "." name "() is declared")
  } else if (!outer_closed) {
    fail("@" kind "." name "() is never closed")
  }
  require_required()
  if (failed) {
    exit 1
  }
}
