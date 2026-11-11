# A private name in a library file is fully qualified: a function or a
# constant begins with the module path, and a variable assigned in a
# function begins with the module path, then the function's own name.
# Loaded with the scanner runtime and the prefix, scope and words libraries:
#
#   awk -v root=<repository root> -f scan.awk -f name_prefix.awk -f scope.awk -f words.awk -f private_name.awk
#
# The module path is the directories under lib/ or interpreter/, joined by
# __. A file sitting in one of those two roots takes its path from its own
# name; the import barrel, api.sh, is the module itself, so its stem is never
# a segment. A function's own name is what is left once its leading __ and
# the module's spelling, formal or informal, are dropped: the variables of
# bump__plan, __bump__plan and bump__plan_bump alike begin with __bump__plan__, so
# a name is mangled once, ahead of the module path it will carry. A plugin's
# inner @<role> keeps __<plugin>_<role>__, the prefix the interpreter
# re-homes it to. A variable read in a function may be any of the module's.
# A child module may spell a private name of a module it sits inside, as a
# child module reaches its parent's items, when one segment follows that
# module's path.
# A @let line is the let-pairing check's, and the names it binds are the
# function's to read and to give a default. A line carrying `# private-name-check: allow` is left alone. A name
# inside a comment or a heredoc is not read.
#
# Output: "<name>:<lineno>: <message>". Vars: -v root=<dir> keys a file
# under the repository root; -v fname=<display name> (default FILENAME).

# True when LINE carries the marker that exempts it.
function is_allowed(line) {
  return line ~ /private-name-check:[ \t]*allow/
}

# True when LINE is a @let or @unlet, whose prefix the let-pairing check reads.
function is_binding(line) {
  return line ~ /^[ \t]*@(let|unlet)([ \t]|$)/
}

# Records the names a @let on LINE binds, <prefix><key> for each key after
# the prefix, so a read of one is the function's.
function remember_let(line, __words, __count, __index, __prefix) {
  if (line !~ /^[ \t]*@let[ \t]/) {
    return
  }
  __count = split(line, __words, /[ \t]+/)
  for (__index = 1; __index <= __count; __index++) {
    if (__words[__index] ~ /^__[A-Za-z0-9_]*__$/) {
      __prefix = __words[__index]
      break
    }
  }
  if (__prefix == "") {
    return
  }
  for (__index++; __index <= __count; __index++) {
    let_bound[__prefix __words[__index]] = 1
  }
}

# True when NAME spells the barrel's stem as the segment after the module
# path.
function names_barrel(name) {
  return substr(name, length(prefix) + 1) ~ ("^" barrel_stem() "(__|$)")
}

# True when NAME is a private name of a module this one sits inside: an
# ancestor's path and then one segment, which a child may spell the way a
# child module reaches its parent's items.
function belongs_to_ancestor(name, __ancestor, __rest) {
  __ancestor = prefix
  while (sub(/[A-Za-z0-9]+(_[A-Za-z0-9]+)*__$/, "", __ancestor) && __ancestor != "__") {
    if (index(name, __ancestor) == 1) {
      __rest = substr(name, length(__ancestor) + 1)
      if (__rest !~ /__/) {
        return 1
      }
    }
  }
  return 0
}

# True when NAME begins with the path of a module this one sits inside, so a
# child reads its parent's constants and out-parameters.
function read_from_ancestor(name, __ancestor) {
  __ancestor = prefix
  while (sub(/[A-Za-z0-9]+(_[A-Za-z0-9]+)*__$/, "", __ancestor) && __ancestor != "__") {
    if (index(name, __ancestor) == 1) {
      return 1
    }
  }
  return 0
}

# Reports the function or constant NAME unless the module, or a module it
# sits inside, owns it.
function judge_function(name) {
  if (index(name, prefix) != 1) {
    if (!belongs_to_ancestor(name)) {
      note(FNR, "private name " name " does not begin with " prefix)
    }
    return
  }
  if (names_barrel(name)) {
    note(FNR, "private name " name " spells " barrel_stem() ", the module's own file, as a segment")
  }
}

# True when NAME is the module's own state, a variable more than one
# function writes: it begins with the module path and its last segment is
# upper case, the spelling a constant takes.
function is_module_state(name) {
  return (index(name, prefix) == 1 && name ~ /__[A-Z][A-Z0-9_]*$/ && name !~ /__[A-Z][A-Z0-9_]*__[a-z]/)
}

# The prefix a variable assigned in the innermost function begins with: the
# role's own for a plugin role, the fully qualified one otherwise.
function own_prefix(fn) {
  if (scope_in_role()) {
    return scope_local_prefix(fn)
  }
  return variable_prefix(fn, prefix)
}

# Reports the variable NAME assigned in the function FN unless it begins with
# the function's prefix. At the root a variable is the module's constant.
function judge_assignment(name, fn, __own) {
  if (fn == "") {
    judge_function(name)
    return
  }
  __own = own_prefix(fn)
  if (index(name, __own) == 1 || is_module_state(name) || (name in let_bound)) {
    return
  }
  if (foreign_variable[scope_depth] == "") {
    foreign_variable[scope_depth] = name
  }
  assigned_here[name] = 1
  note(FNR, "variable " name " is assigned in " fn ", whose variables begin with " __own)
}

# Reports the variable NAME read in the function FN unless the module, the
# role or a @let owns it. A variable already reported where it was assigned
# is not reported again at each read.
function judge_read(name, fn) {
  if (index(name, prefix) == 1 || (name in assigned_here) || (name in let_bound)) {
    return
  }
  if (read_from_ancestor(name)) {
    return
  }
  if (fn != "" && scope_in_role() && index(name, scope_local_prefix(fn)) == 1) {
    return
  }
  if (fn == "") {
    note(FNR, "private name " name " does not begin with " prefix)
    return
  }
  note(FNR, "private name " name " is read in " fn " and is not the module's")
}

# Judges one NAME by how the line uses it: read, assigned, or named as a
# function.
function judge_name(name, before, after, __fn) {
  __fn = scope_function()
  if (words_read(before)) {
    judge_read(name, __fn)
  } else if (words_assigned(before, after)) {
    judge_assignment(name, __fn)
  } else {
    judge_function(name)
  }
}

# Reports every private name on LINE that its owner does not own.
function judge_line(line, __rest, __match, __name, __before, __end) {
  if (prefix == "" || is_comment(line) || is_allowed(line)) {
    return
  }
  if (is_binding(line)) {
    remember_let(line)
    return
  }
  __rest = line
  while (match(__rest, /(^|[^A-Za-z0-9_])__[A-Za-z][A-Za-z0-9_]*/)) {
    __match = substr(__rest, RSTART, RLENGTH)
    __end = RSTART + RLENGTH
    if (__match ~ /^_/) {
      __name = __match
      __before = ""
    } else {
      __name = substr(__match, 2)
      __before = substr(__rest, 1, RSTART)
    }
    if (!words_foreign(__before, substr(__rest, __end, 1))) {
      judge_name(__name, __before, substr(__rest, __end, 2))
    }
    __rest = substr(__rest, __end)
  }
}

# Reports, at the definition, a function whose variables were assigned under
# another prefix, so a renamed function carries its variables with it.
function close_function(__fn) {
  __fn = scope_function()
  if (foreign_variable[scope_depth] == "") {
    return
  }
  note(scope_opened_at(), "the variables of " __fn " begin with " own_prefix(__fn) "; " foreign_variable[scope_depth] " does not")
}

# Resets to the state a fresh file starts in.
function begin_file() {
  in_heredoc = 0
  split("", assigned_here)
  split("", let_bound)
  scope_begin_file()
  prefix = module_prefix(library_key(FILENAME))
}

# Reads one line inside a heredoc: the closer ends it.
function read_heredoc(line) {
  if (closes_heredoc(line)) {
    in_heredoc = 0
  }
}

# Reads one line of code: a closing function is judged as a whole before the
# scope moves, and a line is judged inside the function it sits in.
function read_line(line) {
  if (scope_closes(line)) {
    close_function()
  }
  scope_read(line)
  if (scope_opens(line)) {
    foreign_variable[scope_depth] = ""
    split("", assigned_here)
    split("", let_bound)
  }
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
