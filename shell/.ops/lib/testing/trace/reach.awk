# Prints the suites whose tests were seen reaching outside their process
# tree while the config does not mark the suite out_of_tree. A test
# reaches outside when it connected to an address that is not loopback, or
# started a program that reaches another host or a container. The suites
# are in the byte order of their names, and so are the tests of each.
# Loaded after testing.awk.
#
# Input: the trace map (schema/testing-trace.schema.json), and ahead of
#        it, with --with, the effective suites, {<suite>: {reach}}.
#
#   [{"suite": "unit", "tests": [{"test": "test/a.bats",
#     "connects": ["93.184.216.34"], "execs": ["curl"]}]}]

function main(line) {
  tree_line(line)
}

# Whether a program is one whose start says the test reaches another host
# or a container, where the trace cannot follow.
function is_reaching_program(program) {
  return program == "curl" || program == "docker" || program == "kubectl" \
    || program == "podman" || program == "ssh"
}

# Whether an address is loopback: IPv4 127.0.0.0/8 or IPv6 ::1.
function is_loopback(address) {
  return index(address, "127.") == 1 || address == "::1"
}

# Whether a test reached outside its process tree.
function reached_out(test, __value) {
  for (__value = NODE_FIRST[member(test, "connects")]; __value != 0; __value = NODE_NEXT[__value]) {
    if (!is_loopback(text_of(__value))) {
      return 1
    }
  }
  for (__value = NODE_FIRST[member(test, "execs")]; __value != 0; __value = NODE_NEXT[__value]) {
    if (is_reaching_program(text_of(__value))) {
      return 1
    }
  }

  return 0
}

# Fills names with the tests of a suite that reached out, in byte order.
# Returns how many there are.
function reaching_tests(suite, names, __test, __count) {
  __count = 0

  for (__test = NODE_FIRST[member(suite, "tests")]; __test != 0; __test = NODE_NEXT[__test]) {
    if (reached_out(__test)) {
      names[++__count] = name_of(__test)
    }
  }

  sort_texts(names, __count)
  return __count
}

# Prints one test's reach as element n of its suite's tests: the addresses
# outside loopback that it connected to and the reaching programs it
# started.
function print_reach(test, n, __value, __kept) {
  print_open(2, n, "map")
  print_str(3, "test", name_of(test))

  print_open(3, wrap("connects"), "list")
  __kept = 0
  for (__value = NODE_FIRST[member(test, "connects")]; __value != 0; __value = NODE_NEXT[__value]) {
    if (!is_loopback(text_of(__value))) {
      print_node(__value, 4, __kept++)
    }
  }

  print_open(3, wrap("execs"), "list")
  __kept = 0
  for (__value = NODE_FIRST[member(test, "execs")]; __value != 0; __value = NODE_NEXT[__value]) {
    if (is_reaching_program(text_of(__value))) {
      print_node(__value, 4, __kept++)
    }
  }
}

# Prints a suite and its tests that reached out as element n of the list,
# and nothing for a suite with no such test. Returns whether it printed.
function print_suite(suite, n, __names, __count, __i) {
  __count = reaching_tests(suite, __names)
  if (__count == 0) {
    return 0
  }

  print_open(0, n, "map")
  print_str(1, "suite", name_of(suite))
  print_open(1, wrap("tests"), "list")
  for (__i = 1; __i <= __count; __i++) {
    print_reach(member(member(suite, "tests"), __names[__i]), __i - 1)
  }

  return 1
}

BEGIN {
  SUITES = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  count = 0
  for (suite = NODE_FIRST[member(ROOT, "suites")]; suite != 0; suite = NODE_NEXT[suite]) {
    if (text_of(member(member(SUITES, name_of(suite)), "reach")) != "out_of_tree") {
      names[++count] = name_of(suite)
    }
  }
  sort_texts(names, count)

  printed = 0
  for (i = 1; i <= count; i++) {
    printed += print_suite(member(member(ROOT, "suites"), names[i]), printed)
  }
  if (printed == 0) {
    print "0.:list"
  }
}

{ main($0) }
