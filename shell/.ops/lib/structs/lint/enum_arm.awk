# Detector for the structs-lint scanners: a case arm that is one word a printf
# or echo in the same file prints, a bare literal or a constant the file
# assigns by hand, is an enum written by hand. A constant @enum bound is
# assigned nowhere, so a declared enum passes; true and false are the boolean
# detector's. The printing function may come after the case, so arms are
# remembered per file and settled at its end, each reported here rather than
# through lint_is_violation, as boundary_scan.awk allows.
function lint_is_violation(line) {
  if (FNR == 1) {
    settle_arms()
    reset_arms()
  }
  current_name = display_name()
  if (prints_word(line)) {
    printed[printed_word(line)] = 1
  }
  if (assigns_constant(line)) {
    assigned["$" assigned_name(line)] = 1
  }
  if (is_bare_arm(line)) {
    remember_arm(line)
  }
  return 0
}

# True when LINE prints one word in command position and it is not a boolean.
function prints_word(line) {
  if (line !~ /(^|[;&|(){]|[[:space:]](then|else|do))[[:space:]]*(printf|echo)[[:space:]]+(-n[[:space:]]+)?(['"]%s(\\n)?['"][[:space:]]+)?['"]?(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|[a-z][a-z0-9_-]*)(\\n)?['"]?([[:space:]]|[;&|)]|$)/) {
    return 0
  }
  return (printed_word(line) !~ /^(true|false)$/)
}

# The word LINE prints, past the command, its -n and its format.
function printed_word(line, __rest) {
  __rest = line
  sub(/^.*(printf|echo)[[:space:]]+/, "", __rest)
  sub(/^-n[[:space:]]+/, "", __rest)
  sub(/^['"]%s(\\n)?['"][[:space:]]+/, "", __rest)
  return word_at(__rest)
}

# The word at the start of TEXT, quotes stripped: a literal as written, a
# variable as $NAME.
function word_at(text, __rest) {
  __rest = text
  sub(/^['"]/, "", __rest)
  if (__rest ~ /^\$/) {
    sub(/^\$\{?/, "", __rest)
    match(__rest, /^[A-Za-z_][A-Za-z0-9_]*/)
    return "$" substr(__rest, 1, RLENGTH)
  }
  match(__rest, /^[a-z][a-z0-9_-]*/)
  return substr(__rest, 1, RLENGTH)
}

# True when LINE assigns a variable at the start of the line.
function assigns_constant(line) {
  return line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/
}

# The variable the assignment LINE writes.
function assigned_name(line, __rest) {
  __rest = line
  sub(/^[[:space:]]*/, "", __rest)
  match(__rest, /^[A-Za-z_][A-Za-z0-9_]*/)
  return substr(__rest, 1, RLENGTH)
}

# True when WORD names an enum written by hand: a printed literal, or a
# printed constant the file also assigns.
function is_hand_enum(word) {
  if (!(word in printed)) {
    return 0
  }
  if (word ~ /^\$/) {
    return (word in assigned)
  }
  return 1
}

# True when LINE is a case arm whose whole pattern is one word, a literal or
# a variable, quoted or not.
function is_bare_arm(line) {
  return line ~ /^[[:space:]]*["']?(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|[a-z][a-z0-9_-]*)["']?\)([[:space:]]|$)/
}

# The word the bare arm LINE matches.
function arm_word_of(line, __rest) {
  __rest = line
  sub(/^[[:space:]]*/, "", __rest)
  return word_at(__rest)
}

# Keeps the arm on LINE for settling, with whether a marker allowed it.
function remember_arm(line) {
  arm_count++
  arm_line[arm_count] = FNR
  arm_text[arm_count] = $0
  arm_word[arm_count] = arm_word_of(line)
  arm_allowed[arm_count] = (FNR <= allow_until)
}

# Reports every remembered arm that names a hand enum and is neither allowed
# nor outside the added-line filter.
function settle_arms(__i) {
  for (__i = 1; __i <= arm_count; __i++) {
    if (is_hand_enum(arm_word[__i]) && !arm_allowed[__i] && in_scope(arm_line[__i])) {
      printf "%s:%d:%s\n", current_name, arm_line[__i], arm_text[__i]
    }
  }
}

# Forgets the previous file's words, assignments and arms.
function reset_arms() {
  arm_count = 0
  split("", printed)
  split("", assigned)
  split("", arm_line)
  split("", arm_text)
  split("", arm_word)
  split("", arm_allowed)
}

END {
  settle_arms()
}
