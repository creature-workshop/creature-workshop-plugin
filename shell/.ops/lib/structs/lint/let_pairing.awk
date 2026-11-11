# Detector for the structs-lint scanners (loaded via `awk -f` alongside
# scan.awk / boundary_scan.awk). Inside one function body every @let needs an
# @unlet before the closing brace naming the same prefix and the same keys,
# every @unlet needs the @let it releases, and the prefix begins with the
# function's own local prefix. A plugin's inner @<role> is known by the name
# the interpreter re-homes it to, <plugin>_<role>. A @let outside any function is not read, and neither is
# an early return.
#
# Findings settle when a function closes, so the detector reports them itself
# through boundary_scan's report_finding, anchored to the @let or @unlet each
# one concerns, and always answers false.
function lint_is_violation(line) {
  if (FNR == 1) {
    forget_functions()
  }
  if (opens_function(line)) {
    enter_function(line)
    if (closes_on_its_own_line(line)) {
      leave_function()
    }
  } else if (closes_innermost_function(line)) {
    leave_function()
  } else if (depth > 0) {
    remember_binding(line)
  }
  return 0
}

# True when LINE defines a function. The shared is_func_def stops at the
# name class it knows, so a plugin's outer @<kind>.<name>() is recognized
# here as well; the inner roles it holds are named after it.
function opens_function(line) {
  return (is_func_def(line) || line ~ /^[[:space:]]*@[A-Za-z0-9_]+\.[A-Za-z0-9_-]+[[:space:]]*\(\)/)
}

# Leaves every open function: a new file starts outside all of them.
function forget_functions() {
  depth = 0
}

# Pushes the function LINE defines, with no @let or @unlet read yet.
function enter_function(line, __enclosing) {
  __enclosing = (depth > 0 ? function_name[depth] : "")
  depth++
  function_name[depth] = known_name(defined_name(line), __enclosing)
  function_indent[depth] = indentation(line)
  let_count[depth] = 0
  unlet_count[depth] = 0
}

# The name of the function LINE defines.
function defined_name(line, __definition) {
  __definition = line
  sub(/^[[:space:]]*(function[[:space:]]+)?/, "", __definition)
  match(__definition, /[A-Za-z_@][A-Za-z0-9_@.-]*/)
  return substr(__definition, 1, RLENGTH)
}

# The name a function is known by once loaded. A plugin's inner @<role> is
# re-homed by the interpreter to <plugin>_<role>, so that is the name its
# locals carry; every other function is known by its own.
#
#     known_name("@upload_artifact", "@forge.gitlab") -> gitlab_upload_artifact
function known_name(name, enclosing) {
  if (enclosing !~ /^@[A-Za-z0-9_]+\./ || name !~ /^@/) {
    return name
  }
  return plugin_name(enclosing) "_" substr(name, 2)
}

# The plugin half of an outer @<kind>.<name> definition.
function plugin_name(enclosing) {
  sub(/^@[A-Za-z0-9_]+\./, "", enclosing)
  return enclosing
}

# True when the definition on LINE also closes its body: `f() { :; }`.
function closes_on_its_own_line(line) {
  return line ~ /}[[:space:]]*$/
}

# True when LINE is the closing brace of the innermost open function: a line
# holding only `}`, indented as the definition was.
function closes_innermost_function(line) {
  if (depth == 0) {
    return 0
  }
  if (line !~ /^[[:space:]]*}[[:space:]]*$/) {
    return 0
  }
  return indentation(line) == function_indent[depth]
}

# The leading whitespace of LINE, as text, so two indentations compare exactly.
function indentation(line) {
  match(line, /^[[:space:]]*/)
  return substr(line, 1, RLENGTH)
}

# The local prefix the function NAME binds under: __<name>__, or <name>__
# when the name already starts with __. A sigil or a dot in a role name
# becomes an underscore, as a variable name allows neither.
#
#     local_prefix("hygiene_review")        ->  __hygiene_review__
#     local_prefix("__structs_lint__audit") ->  __structs_lint__audit__
function local_prefix(name) {
  gsub(/[^A-Za-z0-9_]/, "_", name)
  sub(/^_+/, "", name)
  return "__" name "__"
}

# Records the @let or @unlet on LINE, if it holds one, for the innermost
# function.
function remember_binding(line) {
  if (line ~ /^[[:space:]]*@let[[:space:]]/) {
    remember_let(line)
  } else if (line ~ /^[[:space:]]*@unlet([[:space:]]|$)/) {
    remember_unlet(line)
  }
}

# Records the @let on LINE, and reports it at once when its prefix is not
# the innermost function's own.
function remember_let(line, __arguments, __prefix) {
  __arguments = arguments_after_struct(line)
  __prefix = first_word(__arguments)
  let_count[depth]++
  let_line[depth, let_count[depth]] = FNR
  let_text[depth, let_count[depth]] = $0
  let_prefix[depth, let_count[depth]] = __prefix
  let_keys[depth, let_count[depth]] = words_after_first(__arguments)
  if (!prefix_belongs_to(__prefix, function_name[depth])) {
    report_foreign_prefix(__prefix)
  }
}

# True when PREFIX is one the function NAME may bind under: its own local
# prefix, or that prefix carrying a suffix, which is how one function tells
# the bindings of two structs apart.
function prefix_belongs_to(prefix, name, __own) {
  __own = local_prefix(name)
  return substr(prefix, 1, length(__own)) == __own
}

# Reports the @let just read: it binds under PREFIX where the innermost
# function's own prefix belongs.
function report_foreign_prefix(prefix) {
  report_finding(FNR, $0 " -- the prefix of " function_name[depth] " begins " local_prefix(function_name[depth]))
}

# Records the @unlet on LINE, not yet paired with any @let.
function remember_unlet(line, __arguments) {
  __arguments = line
  sub(/^[[:space:]]*@unlet[[:space:]]*/, "", __arguments)
  unlet_count[depth]++
  unlet_line[depth, unlet_count[depth]] = FNR
  unlet_text[depth, unlet_count[depth]] = $0
  unlet_prefix[depth, unlet_count[depth]] = first_word(__arguments)
  unlet_keys[depth, unlet_count[depth]] = words_after_first(__arguments)
  unlet_paired[depth, unlet_count[depth]] = 0
}

# The text of a @let LINE after its struct argument: the prefix and the keys.
# The struct argument is one double-quoted, single-quoted or bare word.
function arguments_after_struct(line, __arguments) {
  __arguments = line
  sub(/^[[:space:]]*@let[[:space:]]+/, "", __arguments)
  if (__arguments ~ /^"/) {
    sub(/^"([^"\\]|\\.)*"[[:space:]]*/, "", __arguments)
  } else if (__arguments ~ /^'/) {
    sub(/^'[^']*'[[:space:]]*/, "", __arguments)
  } else {
    sub(/^[^[:space:]]+[[:space:]]*/, "", __arguments)
  }
  return __arguments
}

# The first whitespace-delimited word of TEXT.
function first_word(text) {
  match(text, /^[^[:space:]]+/)
  return substr(text, 1, RLENGTH)
}

# The words of TEXT after its first, as one space-separated string, cut at
# the end of the simple command: a `;`, `&&`, `||`, `|` or `&`.
function words_after_first(text, __words) {
  __words = text
  sub(/^[^[:space:]]+[[:space:]]*/, "", __words)
  sub(/[[:space:]]*(;|&&|\|\||\||&).*$/, "", __words)
  gsub(/[[:space:]]+/, " ", __words)
  sub(/[[:space:]]+$/, "", __words)
  return __words
}

# True when the space-separated key lists BOUND and RELEASED name the same
# set of keys, in any order.
function same_keys(bound, released, __bound_set, __released_set) {
  if (key_set(bound, __bound_set) != key_set(released, __released_set)) {
    return 0
  }
  return every_key_present(__bound_set, __released_set)
}

# Fills SET with one entry per key of the space-separated LIST and returns
# how many keys the list held.
function key_set(list, set, __keys, __count, __index) {
  __count = split(list, __keys, " ")
  for (__index = 1; __index <= __count; __index++) {
    set[__keys[__index]] = 1
  }
  return __count
}

# True when every key of WANTED is also in FOUND.
function every_key_present(wanted, found, __key) {
  for (__key in wanted) {
    if (!(__key in found)) {
      return 0
    }
  }
  return 1
}

# Pops the innermost function, reporting what it left unpaired.
function leave_function() {
  report_unpaired_lets()
  report_stray_unlets()
  depth--
}

# Reports each @let of the innermost function that no @unlet releases
# exactly.
function report_unpaired_lets(__index) {
  for (__index = 1; __index <= let_count[depth]; __index++) {
    report_let_unless_paired(__index)
  }
}

# Reports the @let at POSITION in the innermost function unless an @unlet with
# its prefix releases its keys exactly; a partner with other keys is named.
function report_let_unless_paired(position, __partner) {
  __partner = partner_of(position)
  if (__partner == 0) {
    report_missing_unlet(position)
    return
  }
  unlet_paired[depth, __partner] = 1
  if (!same_keys(let_keys[depth, position], unlet_keys[depth, __partner])) {
    report_mismatched_unlet(position, __partner)
  }
}

# The @unlet that releases the @let at POSITION: the one under its prefix
# releasing exactly its keys, so two runs under one prefix pair by what they
# name rather than by the order they appear in. Falls back to the first
# unpaired @unlet under the prefix, whose keys the caller then reports as
# the wrong ones, and 0 when the prefix has none left.
function partner_of(position, __unlet) {
  __unlet = released_by_keys(let_prefix[depth, position], let_keys[depth, position])
  if (__unlet > 0) {
    return __unlet
  }
  return first_under_prefix(let_prefix[depth, position])
}

# The position of the first unpaired @unlet under PREFIX releasing exactly
# KEYS, or 0 when none does.
function released_by_keys(prefix, keys, __index) {
  for (__index = 1; __index <= unlet_count[depth]; __index++) {
    if (!unlet_paired[depth, __index] && unlet_prefix[depth, __index] == prefix && same_keys(keys, unlet_keys[depth, __index])) {
      return __index
    }
  }
  return 0
}

# The position of the first unpaired @unlet under PREFIX, whatever it
# releases, or 0 when there is none.
function first_under_prefix(prefix, __index) {
  for (__index = 1; __index <= unlet_count[depth]; __index++) {
    if (!unlet_paired[depth, __index] && unlet_prefix[depth, __index] == prefix) {
      return __index
    }
  }
  return 0
}

# Reports the @let at POSITION as having no @unlet, spelling the line to add.
function report_missing_unlet(position) {
  report_finding(let_line[depth, position], let_text[depth, position] " -- no @unlet before the closing brace; add: @unlet " let_prefix[depth, position] " " let_keys[depth, position])
}

# Reports the @let at POSITION as released by its PARTNER with other keys.
function report_mismatched_unlet(position, partner) {
  report_finding(let_line[depth, position], let_text[depth, position] " -- the @unlet at line " unlet_line[depth, partner] " releases " unlet_keys[depth, partner] ", not " let_keys[depth, position])
}

# Reports each @unlet of the innermost function that no @let paired with.
function report_stray_unlets(__index) {
  for (__index = 1; __index <= unlet_count[depth]; __index++) {
    if (!unlet_paired[depth, __index]) {
      report_finding(unlet_line[depth, __index], unlet_text[depth, __index] " -- releases what no @let in " function_name[depth] " bound")
    }
  }
}
