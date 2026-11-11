# Prints a cargo-tarpaulin JSON report as the coverage report that
# lib/coverage/coverage.awk prints. Tarpaulin counts lines, so the metric
# is "lines". Loaded after coverage.awk.
#
# Input: the report, {files: [{path: [<component>, ...], covered,
#        coverable}], covered, coverable}.
# Args:  root, the workspace root, which every file's path is made
#        relative to, and suite, the suite that the run belongs to.

function main(line) {
  tree_line(line)
}

# The path of a file as one text. Tarpaulin gives an absolute path as
# components of which the first is "/", so that one takes no slash after
# it: ["/", "w", "a.rs"] is /w/a.rs.
function joined_path(components, __part, __path, __first) {
  __path = ""
  __first = NODE_FIRST[components]

  for (__part = __first; __part != 0; __part = NODE_NEXT[__part]) {
    if (__part == __first || (NODE_NEXT[__first] == __part && text_of(__first) == "/")) {
      __path = __path text_of(__part)
    } else {
      __path = __path "/" text_of(__part)
    }
  }

  return __path
}

# Notes every file of the report under its path below the workspace root.
function note_files(__file) {
  for (__file = NODE_FIRST[member(ROOT, "files")]; __file != 0; __file = NODE_NEXT[__file]) {
    note_file(relative(arg("root"), joined_path(member(__file, "path"))), member(__file, "covered"), member(__file, "coverable"))
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  note_files()
  print_report("lines", arg("suite"), "tarpaulin", member(ROOT, "covered"), member(ROOT, "coverable"))
}

{ main($0) }
