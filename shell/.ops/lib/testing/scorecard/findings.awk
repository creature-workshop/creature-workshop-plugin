# Prints the findings behind a scorecard's gap counts as lines of a
# markdown list: one line for each finding, in the order of the report,
# and nothing for a kind of finding that has none. The trace gaps are
# listed with the file that the most tests read first. Prints nothing for
# a clean mapping. Loaded after testing.awk.
#
# Input: the scorecard, of a repository that has a testing config.
#
#   - unmapped files: `stray.sh` (1)
#   - orphan tests (`unit`): `spec/lexer_spec.sh`

function main(line) {
  tree_line(line)
}

# A text as inline code.
function code(text) {
  return "`" text "`"
}

# The texts under a node as inline code, with a comma between them.
function codes(list, __item, __out) {
  __out = ""
  for (__item = NODE_FIRST[list]; __item != 0; __item = NODE_NEXT[__item]) {
    __out = __out (__out == "" ? "" : ", ") code(text_of(__item))
  }

  return __out
}

# Prints the unmapped files as one line, by the first part of their
# paths, and nothing when there are none.
function print_unmapped(top_level, __part, __out) {
  __out = ""
  for (__part = NODE_FIRST[top_level]; __part != 0; __part = NODE_NEXT[__part]) {
    __out = __out (__out == "" ? "" : ", ") code(name_of(__part)) " (" text_of(__part) ")"
  }

  if (__out != "") {
    print "- unmapped files: " __out
  }
}

# Prints a line for each area path that does not exist.
function print_missing(paths, __finding) {
  for (__finding = NODE_FIRST[paths]; __finding != 0; __finding = NODE_NEXT[__finding]) {
    print "- missing area path: " code(text_of(member(__finding, "area"))) ": " code(text_of(member(__finding, "path")))
  }
}

# Prints a line for each test entry that names nothing.
function print_dead(entries, __finding) {
  for (__finding = NODE_FIRST[entries]; __finding != 0; __finding = NODE_NEXT[__finding]) {
    print "- dead test entry: " code(text_of(member(__finding, "area"))) "/" code(text_of(member(__finding, "suite"))) ": " code(text_of(member(__finding, "entry")))
  }
}

# Prints a line for each suite that has orphan tests.
function print_orphans(orphans, __suite) {
  for (__suite = NODE_FIRST[orphans]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    print "- orphan tests (" code(name_of(__suite)) "): " codes(__suite)
  }
}

# Prints the untested areas as one line, and nothing when there are none.
function print_untested(areas) {
  if (NODE_COUNT[areas] > 0) {
    print "- untested areas: " codes(areas)
  }
}

# Prints a line for each undeclared directory, with the declaration that
# would claim it: the grouping area's name, a dot, and the directory's own
# name.
function print_undeclared(directories, __finding, __area, __path) {
  for (__finding = NODE_FIRST[directories]; __finding != 0; __finding = NODE_NEXT[__finding]) {
    __area = text_of(member(__finding, "area"))
    __path = text_of(member(__finding, "path"))
    print "- undeclared directory (advisory): " code(__path) " falls to " code(__area) "; declare " code(__area "." base_name(__path)) " with source " code(__path)
  }
}

# Prints a line for each trace gap: the file, the area it belongs to, and
# how many tests read it that a change to it would not select. The file
# that the most tests read is first, and files that as many tests read
# are in the byte order of their paths.
function print_trace_gaps(gaps, __gap, __ordered, __count, __i) {
  __count = 0
  for (__gap = NODE_FIRST[gaps]; __gap != 0; __gap = NODE_NEXT[__gap]) {
    insert_gap(__ordered, __count++, __gap)
  }

  for (__i = 1; __i <= __count; __i++) {
    __gap = __ordered[__i]
    print "- trace gap (advisory): " code(text_of(member(__gap, "file"))) " falls to " code(text_of(member(__gap, "area"))) "; " NODE_COUNT[member(__gap, "tests")] " test(s) read it that a change there would not select"
  }
}

# Puts a trace gap among the gaps ordered so far, after every one that is
# not after it.
function insert_gap(ordered, count, gap, __at) {
  for (__at = count; __at >= 1 && gap_is_after(ordered[__at], gap); __at--) {
    ordered[__at + 1] = ordered[__at]
  }
  ordered[__at + 1] = gap
}

# Whether one trace gap is listed after another: fewer tests read its
# file, or as many did and its file is later in byte order.
function gap_is_after(gap, other, __tests, __other_tests) {
  __tests = NODE_COUNT[member(gap, "tests")]
  __other_tests = NODE_COUNT[member(other, "tests")]
  if (__tests != __other_tests) {
    return __tests < __other_tests
  }

  return (text_of(member(gap, "file")) "") > (text_of(member(other, "file")) "")
}

# Prints a line for each suite seen reaching out of tree without being
# marked: the suite, how many of its tests reached out, and what they
# reached, in byte order with each once.
function print_reach_gaps(gaps, __gap, __test, __value, __reached, __count, __i, __out) {
  for (__gap = NODE_FIRST[gaps]; __gap != 0; __gap = NODE_NEXT[__gap]) {
    __count = 0
    for (__test = NODE_FIRST[member(__gap, "tests")]; __test != 0; __test = NODE_NEXT[__test]) {
      for (__value = NODE_FIRST[member(__test, "connects")]; __value != 0; __value = NODE_NEXT[__value]) {
        __reached[++__count] = text_of(__value)
      }
      for (__value = NODE_FIRST[member(__test, "execs")]; __value != 0; __value = NODE_NEXT[__value]) {
        __reached[++__count] = text_of(__value)
      }
    }

    __count = unique_texts(__reached, __count)
    __out = ""
    for (__i = 1; __i <= __count; __i++) {
      __out = __out (__i == 1 ? "" : ", ") code(__reached[__i])
    }
    print "- reaching out of tree (advisory): suite " code(text_of(member(__gap, "suite"))) " is not marked " code("out_of_tree") "; " NODE_COUNT[member(__gap, "tests")] " test(s) reached an address or a program the trace cannot follow (" __out ")"
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  gaps = member(ROOT, "gaps")
  print_unmapped(member(member(gaps, "unmapped"), "top_level"))
  print_missing(member(gaps, "missing_paths"))
  print_dead(member(gaps, "dead_tests"))
  print_orphans(member(gaps, "orphans"))
  print_untested(member(gaps, "untested_areas"))
  print_undeclared(member(gaps, "undeclared_dirs"))
  print_trace_gaps(member(gaps, "trace_gaps"))
  print_reach_gaps(member(gaps, "reach_gaps"))
}

{ main($0) }
