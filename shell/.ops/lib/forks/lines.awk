# lines.awk -- what one line of an strace -f trace is, shared by every forks
# program so they cannot disagree on which lines count.
#
# A trace line is "<pid> <syscall>(<args>) = <result>". A clone or clone3 is
# one fork. An execve names the program as its first argument; a failed one
# (= -1, the shell walking PATH) started no program and does not count.

# Whether the line records a fork.
function is_clone(line) {
  return line ~ /^[0-9]+ +clone3?\(/
}

# Whether the line records a program starting: an execve that did not fail.
function is_exec(line) {
  if (line !~ /^[0-9]+ +execve\("/) {
    return 0
  }
  return line !~ /= -1 /
}

# The basename of the program an execve line started.
#
#   1234 execve("/usr/bin/jq", ["jq", "-r", ".a"], ...) = 0  ->  jq
function exec_program(line, __path) {
  __path = line
  sub(/^[0-9]+ +execve\("/, "", __path)
  sub(/".*$/, "", __path)
  sub(/^.*\//, "", __path)
  return __path
}
