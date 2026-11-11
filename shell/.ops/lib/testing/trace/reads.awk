# reads.awk -- the facts of a traced command, one per line: read <file>, a
# tracked file it opened, stat'd or executed; probe <file>, a repository path
# it asked for and did not find; exec <program>, a program it started, by
# basename; connect <address>, an internet address it connected to.
#
# Input: the tracked file list, then the strace -f trace twice. -v root is the
# repository's absolute path and -v cwd where the command started; a relative
# path is placed by its process's working directory, chdir by chdir. With
# -v runner=<file> only that test file's runner counts (see runner.awk).
# Loaded after lines.awk, paths.awk and runner.awk.

# The working directory of a process: where it moved to, else where its
# parent was when it started, else where the traced command started.
function cwd_of(pid) {
  if (pid in moved) {
    return moved[pid]
  }
  return cwd_start
}

# A path as the process names it, made absolute against its working
# directory and normalized.
function absolute(path, pid) {
  if (path ~ /^\//) {
    return normalize(path)
  }
  return normalize(cwd_of(pid) "/" path)
}

# The repository-relative form of an absolute path under the root, or
# nothing for a path outside it.
function relative(abs) {
  return relative_to(abs, root)
}

# Prints one fact, once: a second read of the same file adds nothing.
function note(kind, value, __key) {
  __key = kind "\t" value
  if (__key in seen) {
    return
  }
  seen[__key] = 1
  print __key
}

# Whether the current call of a process counts: every process's, or only
# the runner's.
function counted(pid) {
  return runner == "" || runner_at(pid, calls[pid])
}

# Records a file call: the tracked file it read, or the repository path it
# probed for and missed.
function on_file(pid, args, result, __path, __rel) {
  if (!counted(pid)) {
    return
  }
  __path = call_path(args)
  if (__path == "") {
    return
  }
  __rel = relative(absolute(__path, pid))
  if (__rel == "") {
    return
  }
  if (missing(result)) {
    note("probe", __rel)
  } else if (!failed(result) && (__rel in tracked)) {
    note("read", __rel)
  }
}

# Moves the process to the directory a successful chdir named.
function on_chdir(pid, args, result, __path) {
  if (failed(result)) {
    return
  }
  __path = first_string(args)
  if (__path != "") {
    moved[pid] = absolute(__path, pid)
  }
}

# Names the program a successful execve started, and counts its file as
# read when it is a tracked one.
function on_exec(pid, args, result, __path) {
  if (failed(result) || !counted(pid)) {
    return
  }
  __path = first_string(args)
  if (__path != "") {
    note("exec", basename(__path))
  }
  on_file(pid, args, result)
}

# Starts the child where its parent was.
function on_clone(pid, result, __child) {
  __child = clone_child(result)
  if (__child != "") {
    moved[__child] = cwd_of(pid)
  }
}

# Names the internet address a connect reached for, attempted or not: an
# address in the arguments is the reach, whatever the call returned.
function on_connect(pid, args, __addr) {
  if (args !~ /sa_family=AF_INET6?,/ || !counted(pid)) {
    return
  }
  __addr = first_string(args)
  if (__addr != "") {
    note("connect", __addr)
  }
}

# Learns from one whole trace line on the first read, for the runner. The
# first line's process is the one the trace started with.
function learn_line(line, __syscall, __pid) {
  __syscall = line_syscall(line)
  if (__syscall == "") {
    return
  }
  __pid = line_pid(line)
  if (root_pid == "") {
    root_pid = __pid
  }
  learn_call(__pid, ++calls[__pid], __syscall, line_args(line), line_result(line))
}

# Reads one whole trace line on the second read.
function read_line(line, __syscall, __pid) {
  __syscall = line_syscall(line)
  if (__syscall == "") {
    return
  }
  __pid = line_pid(line)
  calls[__pid]++
  on_call(__pid, __syscall, line_args(line), line_result(line))
}

# Starts a read of the trace afresh: no call half-joined, none counted.
function restart_read() {
  split("", pending)
  split("", calls)
}

# Hands one call to the handler its syscall names: a file call unless it
# is a chdir, an exec, a fork or a connect.
function on_call(pid, syscall, args, result) {
  if (syscall == "chdir") {
    on_chdir(pid, args, result)
  } else if (syscall == "execve" || syscall == "execveat") {
    on_exec(pid, args, result)
  } else if (is_clone(syscall)) {
    on_clone(pid, result)
  } else if (syscall == "connect") {
    on_connect(pid, args)
  } else {
    on_file(pid, args, result)
  }
}

BEGIN {
  cwd_start = normalize(cwd)
  root = normalize(root)
  root_pid = ""
  part = 0
}

FNR == 1 {
  part++
  restart_read()
}

# The first input: the tracked list.
part == 1 {
  tracked[$0] = 1
  next
}

# The second: the trace, read to learn which processes are the runner.
part == 2 {
  learn_line(whole_line($0))
  next
}

# The third: the same trace, read for its facts.
{
  read_line(whole_line($0))
}
