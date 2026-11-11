# Prints the facts that reads.awk printed as the observation that the
# trace of one test leaves: the tracked files the test read and the ones
# it looked for, the programs it started and the internet addresses it
# connected to, each in byte order with each value once. Loaded after
# testing.awk.
#
# Input: the fact lines, a list of "<kind>\t<value>", where kind is read,
#        probe, exec or connect.
#
#   ["read\tlib/a.sh", "exec\tgit", "read\tlib/a.sh"]
#   ->  {reads: ["lib/a.sh"], probes: [], execs: ["git"], connects: []}

function main(line) {
  tree_line(line)
}

# Prints the values of the facts of one kind, under a name.
function print_values(name, kind, __line, __fields, __values, __count) {
  __count = 0

  for (__line = NODE_FIRST[ROOT]; __line != 0; __line = NODE_NEXT[__line]) {
    if (split(text_of(__line), __fields, "\t") >= 2 && __fields[1] == kind) {
      __values[++__count] = __fields[2]
    }
  }

  print_open(0, wrap(name), "list")
  print_texts(__values, unique_texts(__values, __count), 0)
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print_values("reads", "read")
  print_values("probes", "probe")
  print_values("execs", "exec")
  print_values("connects", "connect")
}

{ main($0) }
