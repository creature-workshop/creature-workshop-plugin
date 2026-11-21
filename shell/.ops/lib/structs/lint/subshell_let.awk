# Detector for the structs-lint scanners (loaded via `awk -f` alongside
# scan.awk / boundary_scan.awk). Returns true when a comment-stripped source
# line calls @let or @unlet where its bindings would die with a subshell:
# inside a command substitution, or on the right of a pipe.
#
# Line-local by design: a `$(` opened on an earlier line is not seen, so the
# check catches the common shapes and never a false one.
function lint_is_violation(line) {
  if (line ~ /\$\([^)]*@(un)?let([[:space:]]|$)/) {
    return 1
  }
  return line ~ /\|[[:space:]]*@(un)?let([[:space:]]|$)/
}
