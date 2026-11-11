# runner.awk -- which processes of an strace -f trace are a test file's
# runner. The runner is a process the traced command started that went on to
# start a program with the file among its arguments, from that start on, and
# every process it started after. The traced command's own calls, and those
# of whatever it ran before handing the file on, are not the runner's.
#
# A process is placed by its call count, the calls it made before this one,
# which a whole trace read twice gives the same on both reads. strace can
# write a child's first calls before the clone that started it returns, so
# which process started which is learned over the whole trace before any
# call is judged. Loaded after lines.awk.

# Whether an execve's arguments name <file> as one whole argument, not the
# program's path and not part of a longer string.
function names_argument(args, file, __needle, __rest, __at, __before, __after) {
  __needle = "\"" file "\""
  __rest = args
  while ((__at = index(__rest, __needle)) > 0) {
    __before = substr(__rest, 1, __at - 1)
    __after = substr(__rest, __at + length(__needle), 1)
    if (__before ~ /(\[|, )$/ && (__after == "," || __after == "]")) {
      return 1
    }
    __rest = substr(__rest, __at + length(__needle))
  }
  return 0
}

# Learns, from one call of the first read, where a runner starts and which
# process started which. <call> is the call's count in its process.
function learn_call(pid, call, syscall, args, result) {
  if (syscall == "execve" || syscall == "execveat") {
    learn_start(pid, call, args, result)
  } else if (is_clone(syscall)) {
    learn_clone(pid, call, result)
  }
}

# Records the process a successful clone started, and at which call.
function learn_clone(pid, call, result, __child) {
  __child = clone_child(result)
  if (__child != "") {
    runner_parent[__child] = pid
    runner_born[__child] = call
  }
}

# Records the call a process became the runner at: its first successful
# start of a program naming the file, unless it is the traced command.
function learn_start(pid, call, args, result) {
  if (runner == "" || failed(result) || pid == root_pid || (pid in runner_start)) {
    return
  }
  if (names_argument(args, runner)) {
    runner_start[pid] = call
  }
}

# Whether a process was started by the runner, and so is the runner for
# every call it makes.
function runner_inherited(pid) {
  if (!(pid in runner_inherits)) {
    runner_inherits[pid] = (pid in runner_parent) && runner_at(runner_parent[pid], runner_born[pid])
  }
  return runner_inherits[pid]
}

# Whether a process's <call> is the runner's.
function runner_at(pid, call) {
  if (runner_inherited(pid)) {
    return 1
  }
  return (pid in runner_start) && call >= runner_start[pid]
}
