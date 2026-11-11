# Prints a scorecard as the report that a person reads, as lines of text:
# the areas, the gaps, the rollout and the verdict. Loaded after
# testing.awk.
#
# Input: the scorecard, of a repository that has a testing config.
# Args:  ratio, saved and streak: the selection ratio, the time saved and
#        the clean streak of the rollout, as the report shows them, each
#        empty when no run is recorded. They arrive as text because the
#        metrics module words them, and every report of them must show
#        the same words.

function main(line) {
  tree_line(line)
}

# The value of a node as a report shows it, and the word null for no
# node.
function shown(node) {
  return (node == 0) ? "null" : text_of(node)
}

# The members of a map as "name=value", with a space between them.
function pairs(map, __member, __out) {
  __out = ""
  for (__member = NODE_FIRST[map]; __member != 0; __member = NODE_NEXT[__member]) {
    __out = __out (__out == "" ? "" : " ") name_of(__member) "=" text_of(__member)
  }

  return __out
}

# The texts under a node, with a space between them.
function spaced(list, __item, __out) {
  __out = ""
  for (__item = NODE_FIRST[list]; __item != 0; __item = NODE_NEXT[__item]) {
    __out = __out (__out == "" ? "" : " ") text_of(__item)
  }

  return __out
}

# Prints the line of one area's row: its name, how many tests it has for
# each suite, how many of them its importers brought, and what marks it.
function print_area(row, __tests, __line) {
  __tests = member(row, "tests")
  __line = "  " shown(member(row, "name")) "  tests: " (NODE_COUNT[__tests] == 0 ? "none" : pairs(__tests))

  if (text_or(member(row, "importer_tests"), 0) + 0 > 0) {
    __line = __line " (" text_of(member(row, "importer_tests")) " from importers)"
  }
  if (is_truthy(member(row, "full_suite"))) {
    __line = __line " [full_suite]"
  }

  print __line area_mark(row)
}

# The mark of an area that is inert or untested, and the empty string for
# any other. An area is untested when it has no test, does not run the
# full suite, and has a source path.
function area_mark(row) {
  if (is_truthy(member(row, "inert"))) {
    return " [inert]"
  }
  if (text_or(member(row, "total"), 0) + 0 == 0 && !is_truthy(member(row, "full_suite")) && NODE_COUNT[member(row, "paths")] > 0) {
    return " [untested]"
  }

  return ""
}

# Prints the lines of the gaps, one kind after another. The undeclared
# directories, the trace gaps and the reach gaps are advisory: the verdict
# does not read them, and their lines say so.
function print_gaps(gaps, __unmapped, __finding, __suite) {
  __unmapped = member(gaps, "unmapped")
  if (NODE_COUNT[member(__unmapped, "files")] > 0) {
    print "  unmapped files (" NODE_COUNT[member(__unmapped, "files")] "): " pairs(member(__unmapped, "top_level"))
  }

  for (__finding = NODE_FIRST[member(gaps, "missing_paths")]; __finding != 0; __finding = NODE_NEXT[__finding]) {
    print "  missing area path: " shown(member(__finding, "area")) ": " shown(member(__finding, "path"))
  }
  for (__finding = NODE_FIRST[member(gaps, "dead_tests")]; __finding != 0; __finding = NODE_NEXT[__finding]) {
    print "  dead test entry: " shown(member(__finding, "area")) "/" shown(member(__finding, "suite")) ": " shown(member(__finding, "entry"))
  }
  for (__suite = NODE_FIRST[member(gaps, "orphans")]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    print "  orphan tests (" name_of(__suite) ", " NODE_COUNT[__suite] "): " spaced(__suite)
  }
  if (NODE_COUNT[member(gaps, "untested_areas")] > 0) {
    print "  untested areas (" NODE_COUNT[member(gaps, "untested_areas")] "): " spaced(member(gaps, "untested_areas"))
  }

  print_advisory(gaps)
}

# Prints the lines of the advisory gaps.
function print_advisory(gaps, __finding) {
  for (__finding = NODE_FIRST[member(gaps, "undeclared_dirs")]; __finding != 0; __finding = NODE_NEXT[__finding]) {
    print "  undeclared directory (advisory): " shown(member(__finding, "path")) " falls to " shown(member(__finding, "area"))
  }
  for (__finding = NODE_FIRST[member(gaps, "trace_gaps")]; __finding != 0; __finding = NODE_NEXT[__finding]) {
    print "  trace gap (advisory): " shown(member(__finding, "file")) " falls to " shown(member(__finding, "area")) ", read by " NODE_COUNT[member(__finding, "tests")] " test(s) a change there would not select"
  }
  for (__finding = NODE_FIRST[member(gaps, "reach_gaps")]; __finding != 0; __finding = NODE_NEXT[__finding]) {
    print "  reaching out of tree (advisory): suite " shown(member(__finding, "suite")) " is not marked out_of_tree, and " NODE_COUNT[member(__finding, "tests")] " test(s) reached an address or a program the trace cannot follow"
  }
}

# Prints the lines of the rollout, and the blank line before the verdict.
function print_rollout(rollout) {
  if (NODE_COUNT[rollout] == 0) {
    print "rollout: no runs recorded yet"
    print ""
    return
  }

  print "rollout (" shown(member(rollout, "runs")) " runs: " shown(member(rollout, "selected_runs")) " selected, " shown(member(rollout, "full_suite_runs")) " full suite):"
  print "  selection ratio: " arg("ratio")
  print "  time saved: " arg("saved")
  print "  flaky tests (passed on retry): " text_or(member(rollout, "flaky_tests"), 0)
  print "  confidence: " arg("streak")
  print "  narrowed & inert runs without a verdict: " text_or(member(rollout, "unverdicted_runs"), 0)
  print ""
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  summary = member(ROOT, "summary")

  print "testing scorecard"
  print ""
  print "areas (" shown(member(summary, "areas")) "):"
  for (row = NODE_FIRST[member(ROOT, "areas")]; row != 0; row = NODE_NEXT[row]) {
    print_area(row)
  }
  print ""
  print "gaps:"
  print_gaps(member(ROOT, "gaps"))
  print ""
  print_rollout(member(ROOT, "rollout"))
  print "ready: " (written(member(summary, "ready")) == "bool=true" ? "yes" : "no")
}

{ main($0) }
