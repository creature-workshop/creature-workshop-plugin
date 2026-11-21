# Detector for the structs-lint scanners. Rejects a comment-stripped line that
# prints a bare true or false -- `printf 'true\n'`, `echo false`, `printf
# '%s\n' true` -- where @true and @false belong. When the line opens an if or
# else branch body, the finding is anchored to the `if` line (violation_line /
# violation_text, read by boundary_scan.awk) and reported once per if: a
# predicate spelled by hand, where @succeeds <condition> belongs.
#
# Between lines the detector keeps `prev`, the last non-blank line, and the
# `if` nesting: `depth`, with each open if's head in head_line[depth] /
# head_text[depth]; flagged_head is the last if reported.
function lint_is_violation(line, __hit) {
  if (FNR == 1) {
    reset_state()
  }
  __hit = 0
  if (spells_boolean(line)) {
    __hit = (in_branch_body(line) ? anchor_to_head(line) : 1)
  }
  remember_line(line)
  return __hit
}

# True when LINE prints a bare true or false in command position -- at the
# start of a line, pipeline, subshell, case arm or branch: printf or echo,
# with or without -n, a '%s' or '%s\n' format, quotes, or a trailing \n.
function spells_boolean(line) {
  return line ~ /(^|[;&|(){]|[[:space:]](then|else|do))[[:space:]]*(printf|echo)[[:space:]]+(-n[[:space:]]+)?(['"]%s(\\n)?['"][[:space:]]+)?['"]?(true|false)(\\n)?['"]?([[:space:]]|[;&|)]|$)/
}

# LINE without leading and trailing whitespace.
function trimmed(line) {
  sub(/^[[:space:]]+/, "", line)
  sub(/[[:space:]]+$/, "", line)
  return line
}

# True when LINE opens a branch body: it ends in `then`, or is `else` alone.
function opens_branch(line, __t) {
  __t = trimmed(line)
  return (__t ~ /(^|[;[:space:]])then$/ || __t == "else")
}

# True when LINE is a branch head: it starts with if, elif, then or else.
function heads_branch(line) {
  return line ~ /^[[:space:]]*(if|elif|then|else)([[:space:]]|$)/
}

# True when LINE starts with `if`, opening a new if of its own.
function heads_if(line) {
  return line ~ /^[[:space:]]*if[[:space:]]/
}

# True when LINE sits where a branch body starts: on a branch head, or right
# after a line that opened one.
function in_branch_body(line) {
  return (heads_branch(line) || opens_branch(prev))
}

# The `if` openers on LINE minus its `fi` closers: +1 for a head, -1 for a
# close, 0 for a line that does both or neither.
function if_delta(line, __n) {
  __n = 0
  if (line ~ /(^|[;&|(]|[[:space:]](then|else|do))[[:space:]]*if[[:space:]]/) {
    __n++
  }
  if (line ~ /(^|[;&|(]|[[:space:]])fi([[:space:]]*[;&|)]|[[:space:]]*$)/) {
    __n--
  }
  return __n
}

# Forgets the previous file's lines and nesting.
function reset_state() {
  prev = ""
  depth = 0
  flagged_head = 0
}

# Advances prev and the if nesting past LINE. A blank line leaves prev alone,
# so a body separated from its `then` by one still reads as a body.
function remember_line(line, __delta) {
  __delta = if_delta(line)
  if (__delta > 0) {
    depth++
    head_line[depth] = FNR
    head_text[depth] = line
  } else if (__delta < 0 && depth > 0) {
    depth--
  }
  if (trimmed(line) != "") {
    prev = line
  }
}

# Anchors the finding at the `if` the body on LINE belongs to: LINE itself
# when it opens the if, else the innermost open one. Returns 0 when that if
# has already been reported, so its else branch does not report it again.
function anchor_to_head(line, __line, __text) {
  if (heads_if(line) || depth == 0) {
    __line = FNR
    __text = line
  } else {
    __line = head_line[depth]
    __text = head_text[depth]
  }
  if (flagged_head == __line) {
    return 0
  }
  flagged_head = __line
  violation_line = __line
  violation_text = __text
  return 1
}
