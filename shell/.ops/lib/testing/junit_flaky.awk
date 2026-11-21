# junit_flaky.awk -- the tests a junit report marks flaky, one per line as
# classname::name, deduplicated across reports on the same stream.
#
# nextest reports a test that failed and then passed on retry as passed, with
# a <flakyFailure> child on its testcase instead of <failure>; a test that
# failed every retry carries <failure> and <rerunFailure> children, and is a
# failure, not a flake. A passing testcase is self-closing and never reaches
# the flaky rule.

function classname_of(line) {
  sub(/.*classname="/, "", line)
  sub(/".*/, "", line)
  return line
}

function name_of(line) {
  sub(/.*<testcase/, "", line)
  sub(/.*[ \t]name="/, "", line)
  sub(/".*/, "", line)
  return line
}

/<testcase / {
  current = classname_of($0) "::" name_of($0)
}

/<flakyFailure[ >]/ {
  if (current != "" && !(current in seen)) {
    seen[current] = 1
    print current
  }
}
