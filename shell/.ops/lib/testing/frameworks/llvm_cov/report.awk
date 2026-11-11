# Prints a cargo-llvm-cov JSON export as the coverage report that
# lib/coverage/coverage.awk prints. The counts are the export's region
# counts, so the metric is "regions". Loaded after coverage.awk.
#
# Input: the export, {data: [{files: [{filename, summary: {regions:
#        {count, covered}}}], totals: {regions: {count, covered}}}]}.
# Args:  root, the workspace root, which every file's path is made
#        relative to, and suite, the suite that the run belongs to.

function main(line) {
  tree_line(line)
}

# Notes every file of the export under its path below the workspace root.
function note_files(export, __file, __regions) {
  for (__file = NODE_FIRST[member(export, "files")]; __file != 0; __file = NODE_NEXT[__file]) {
    __regions = member(member(__file, "summary"), "regions")
    note_file(relative(arg("root"), text_of(member(__file, "filename"))), member(__regions, "covered"), member(__regions, "count"))
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  export = NODE_FIRST[member(ROOT, "data")]
  totals = member(member(export, "totals"), "regions")
  note_files(export)
  print_report("regions", arg("suite"), "llvm_cov", member(totals, "covered"), member(totals, "count"))
}

{ main($0) }
