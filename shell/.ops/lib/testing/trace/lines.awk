# lines.awk -- what one line of an strace -f trace is, shared by every trace
# program so they cannot disagree on which lines count or how a line is read.
#
# A trace line is "<pid> <syscall>(<args>) = <result>". A call another
# process interrupted is split in two, "<pid> <syscall>(<partial> <unfinished
# ...>" and "<pid> <... <syscall> resumed><rest>) = <result>", and whole_line
# joins the two back into one by pid before a program reads it, since the
# pid names the one call a process can have in flight.

# The pid a line belongs to: its first field.
function line_pid(line) {
  return line + 0
}

# Whether the line is the first half of an interrupted call.
function is_unfinished(line) {
  return line ~ / <unfinished \.\.\.>$/
}

# Whether the line is the second half of an interrupted call.
function is_resumed(line) {
  return line ~ /^[0-9]+ +<\.\.\. [a-z0-9_]+ resumed>/
}

# The first half of an interrupted call with its marker removed, so the
# second half can be joined onto it.
function unfinished_head(line) {
  sub(/ <unfinished \.\.\.>$/, "", line)
  return line
}

# The second half of an interrupted call with its pid and marker removed:
# what follows "resumed>", joined onto the first half as it was cut.
function resumed_tail(line) {
  sub(/^[0-9]+ +<\.\.\. [a-z0-9_]+ resumed>/, "", line)
  return line
}

# The whole call a trace line completes: the line itself for a call written
# in one piece, the two halves joined for the second half of an interrupted
# call, and nothing for the first half, which waits for its second. Keeps
# the first halves in pending, by pid.
function whole_line(line, __pid) {
  if (is_unfinished(line)) {
    pending[line_pid(line)] = unfinished_head(line)
    return ""
  }
  if (is_resumed(line)) {
    __pid = line_pid(line)
    line = pending[__pid] resumed_tail(line)
    delete pending[__pid]
  }
  return line
}

# The syscall a line records, or nothing for a line that is not a call.
function line_syscall(line, __rest) {
  if (line !~ /^[0-9]+ +[a-z0-9_]+\(/) {
    return ""
  }
  __rest = line
  sub(/^[0-9]+ +/, "", __rest)
  sub(/\(.*$/, "", __rest)
  return __rest
}

# The text between the call's opening parenthesis and its result. The
# result follows the last ") = " on the line, since a result's own text can
# hold a parenthesis ("-1 ENOENT (No such file or directory)") and an
# argument can hold " = ".
function line_args(line, __rest, __head) {
  __rest = line
  sub(/^[0-9]+ +[a-z0-9_]+\(/, "", __rest)
  if (match(__rest, /^.*\) += /) == 0) {
    return __rest
  }
  __head = substr(__rest, 1, RLENGTH)
  sub(/\) += $/, "", __head)
  return __head
}

# The result of a call, as strace spells it after the last " = ": "3", "0",
# or "-1 ENOENT (No such file or directory)". Nothing when the line has none.
function line_result(line) {
  if (match(line, /^.*\) += /) == 0) {
    return ""
  }
  return substr(line, RLENGTH + 1)
}

# Whether a result says the call failed.
function failed(result) {
  return result ~ /^-1 /
}

# Whether a result says the call failed because the path does not exist.
function missing(result) {
  return result ~ /^-1 ENOENT/
}

# The first quoted string in s, unquoted, or nothing when s has none. A
# backslash escapes the character after it, as strace writes one.
function first_string(s, __at, __len) {
  if (match(s, /"([^"\\]|\\.)*"/) == 0) {
    return ""
  }
  return substr(s, RSTART + 1, RLENGTH - 2)
}

# Whether the call's path is relative to the calling process's working
# directory: a plain path argument, or an *at call on AT_FDCWD. A relative
# path on any other directory descriptor is relative to a directory the
# trace does not name, and is not resolved.
function path_is_cwd_relative(args) {
  return args ~ /^"/ || args ~ /^AT_FDCWD, "/
}

# The path argument of a file call: the first quoted string in its
# arguments. Nothing when the call names no path the trace can place.
function call_path(args, __path) {
  __path = first_string(args)
  if (__path == "") {
    return ""
  }
  if (__path ~ /^\//) {
    return __path
  }
  if (path_is_cwd_relative(args)) {
    return __path
  }
  return ""
}

# Whether the syscall starts a new process or thread.
function is_clone(syscall) {
  return syscall ~ /^(clone|clone3|fork|vfork)$/
}

# The child a successful clone returned, or nothing.
function clone_child(result) {
  if (result ~ /^[0-9]+$/) {
    return result + 0
  }
  return ""
}

# Everything after the last slash.
function basename(path) {
  sub(/^.*\//, "", path)
  return path
}
