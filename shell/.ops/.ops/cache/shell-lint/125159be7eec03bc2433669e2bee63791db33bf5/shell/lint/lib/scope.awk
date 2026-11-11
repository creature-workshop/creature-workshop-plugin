# The function a line of shell sits in. Loaded ahead of a check that judges
# a name by the function around it:
#
#   awk -f scan.awk -f scope.awk -f <check>.awk
#
# A check calls scope_begin_file() at the top of each file and scope_read(line)
# on each code line, and asks scope_closes(line) before scope_read when it has
# work to do as a function ends. scope_function() is the innermost open
# function as the interpreter knows it: a plugin's inner @<role> is
# <plugin>_<role>. Nothing is open at the module root.

# Forgets every open function: a file starts at its root.
function scope_begin_file() {
  scope_depth = 0
}

# True when LINE defines a function. The shared is_func_def stops at the name
# class it knows, so a plugin's outer @<kind>.<name>() is recognized here too.
function scope_opens(line) {
  return (is_func_def(line) || line ~ /^[ \t]*@[A-Za-z0-9_]+\.[A-Za-z0-9_-]+[ \t]*\(\)/)
}

# True when LINE is the closing brace of the innermost open function: a line
# holding only `}`, indented as the definition was.
function scope_closes(line) {
  if (scope_depth == 0) {
    return 0
  }
  if (line !~ /^[ \t]*}[ \t]*$/) {
    return 0
  }
  return scope_indent(line) == scope_indent_of[scope_depth]
}

# Enters the function LINE defines, or leaves the one LINE closes. A
# definition that closes on its own line, `f() { :; }`, opens nothing.
function scope_read(line) {
  if (scope_opens(line)) {
    scope_enter(line)
    if (line ~ /}[ \t]*$/) {
      scope_depth--
    }
    return
  }
  if (scope_closes(line)) {
    scope_depth--
  }
}

# The innermost open function's name, or nothing at the module root.
function scope_function() {
  return (scope_depth > 0 ? scope_name[scope_depth] : "")
}

# True when the innermost open function is a plugin's role, known by the
# name the interpreter re-homes it to.
function scope_in_role() {
  return (scope_depth > 0 ? scope_role[scope_depth] : 0)
}

# The line the innermost open function was defined on, or 0 at the root.
function scope_opened_at() {
  return (scope_depth > 0 ? scope_opened[scope_depth] : 0)
}

# The prefix the function NAME's variables begin with: __<name>__, with a
# leading __ of the name folded in. A sigil or a dot in a role name becomes
# an underscore, as a variable name allows neither.
#
#     scope_local_prefix("bump__plan_bump")           ->  __plan_bump__
#     scope_local_prefix("__bump__apply_bump")  ->  __bump__apply_bump__
function scope_local_prefix(name) {
  gsub(/[^A-Za-z0-9_]/, "_", name)
  sub(/^_+/, "", name)
  return "__" name "__"
}

# Pushes the function LINE defines.
function scope_enter(line, __enclosing) {
  __enclosing = (scope_depth > 0 ? scope_name[scope_depth] : "")
  scope_depth++
  scope_name[scope_depth] = scope_known_name(scope_defined_name(line), __enclosing)
  scope_role[scope_depth] = (scope_name[scope_depth] != scope_defined_name(line))
  scope_indent_of[scope_depth] = scope_indent(line)
  scope_opened[scope_depth] = FNR
}

# The name LINE defines, without the `function` keyword or the parameter list.
function scope_defined_name(line, __definition) {
  __definition = line
  sub(/^[ \t]*(function[ \t]+)?/, "", __definition)
  match(__definition, /[A-Za-z_@][A-Za-z0-9_@.-]*/)
  return substr(__definition, 1, RLENGTH)
}

# The name a function is known by once loaded: a plugin's inner @<role> is
# re-homed by the interpreter to <plugin>_<role>; every other function keeps
# its own.
#
#     scope_known_name("@select", "@selector.areas")  ->  areas_select
function scope_known_name(name, enclosing) {
  if (enclosing !~ /^@[A-Za-z0-9_]+\./ || name !~ /^@/) {
    return name
  }
  sub(/^@[A-Za-z0-9_]+\./, "", enclosing)
  gsub(/-/, "_", enclosing)
  return enclosing "_" substr(name, 2)
}

# The leading whitespace of LINE, as text, so two indentations compare exactly.
function scope_indent(line) {
  match(line, /^[ \t]*/)
  return substr(line, 1, RLENGTH)
}
