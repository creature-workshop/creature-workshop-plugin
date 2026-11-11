# Detector for the structs-lint scanners (loaded via `awk -f` alongside
# scan_file.awk / scan_diff.awk). Returns true when a comment-stripped source
# line invokes the raw structured-data backend (jq/opx) in command position --
# at the start of a line/pipeline/subshell rather than as a substring like @jq.
function lint_is_violation(line) {
  return line ~ /(^|[;&|(]|\$\()[[:space:]]*(jq|opx)[[:space:]]/
}
