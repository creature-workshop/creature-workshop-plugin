# Detector for the structs-lint scanners. Rejects a comment-stripped line that
# holds a value to the literal true or false in a test -- `[ "$x" = true ]`,
# `[ "$(f)" != true ]`, `test "$x" = false` -- where @is_true and @is_false
# ask the question. Spelling the literal in the test hard-codes the backend's
# representation of a boolean into the caller; the verbs keep it behind the
# API, and only the struct spelling passes them.
function lint_is_violation(line) {
  return tests_boolean_literal(line)
}

# True when LINE compares something to the bare or quoted word true or false
# with = or != inside a test: `[` or `test`, single or double bracket.
function tests_boolean_literal(line) {
  return line ~ /(^|[[:space:]])(\[\[?|test)[[:space:]].*[[:space:]](=|==|!=)[[:space:]]+["']?(true|false)["']?([[:space:]]|\]|$)/
}
