# Detector for the structs-lint scanners. Rejects a comment-stripped line that
# asks `-z` or `-n` of a value a command printed, where @defined is the
# question. A structs answer is one such value: @get prints the string null
# for a missing key, and -z / -n read null as present. Any other command
# substitution is too, because the word null can arrive from a function that
# called the API.
#
# A value was printed when it is a `$(...)` substitution written into the
# test itself, or a variable the current function last assigned from one.
# Tracking is per function, reset at each definition (is_func_def, from the
# scan.awk runtime) and at the top of a file; a later assignment from anything
# else releases the variable.
function lint_is_violation(line, __hit) {
  if (FNR == 1 || is_func_def(line)) {
    forget_structs_values()
  }
  __hit = (tests_printed_substitution(line) || tests_tracked_value(line))
  remember_assignment(line)
  return __hit
}

# Empties the set of variables holding a structs value.
function forget_structs_values() {
  split("", structs_values)
}

# True when LINE tests -z or -n directly on a `$(...)` substitution.
function tests_printed_substitution(line) {
  return line ~ /-[zn][[:space:]]+"?\$\(/
}

# True when LINE tests -z or -n on a variable the current function assigned
# from a command substitution.
function tests_tracked_value(line, __rest, __name) {
  __rest = line
  while (match(__rest, /-[zn][[:space:]]+"?\$\{?[A-Za-z_][A-Za-z0-9_]*/)) {
    __name = substr(__rest, RSTART, RLENGTH)
    sub(/^-[zn][[:space:]]+"?\$\{?/, "", __name)
    if (__name in structs_values) {
      return 1
    }
    __rest = substr(__rest, RSTART + RLENGTH)
  }
  return 0
}

# Records what LINE assigns: a variable set from a `$(...)` substitution
# joins the tracked set; one set from anything else leaves it.
function remember_assignment(line, __name) {
  if (!match(line, /^[[:space:]]*((local|export|readonly)[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/)) {
    return
  }
  __name = substr(line, RSTART, RLENGTH)
  sub(/^[[:space:]]*((local|export|readonly)[[:space:]]+)?/, "", __name)
  sub(/=$/, "", __name)
  if (line ~ /=["']?\$\(/) {
    structs_values[__name] = 1
  } else {
    delete structs_values[__name]
  }
}
