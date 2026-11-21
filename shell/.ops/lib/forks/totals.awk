# The fork and program-start totals of a trace, as one struct object:
#
#   {"forks":2506,"starts":684}
is_clone($0) { clones++ }
is_exec($0) { execs++ }
END {
  printf "{\"forks\":%d,\"starts\":%d}\n", clones + 0, execs + 0
}
