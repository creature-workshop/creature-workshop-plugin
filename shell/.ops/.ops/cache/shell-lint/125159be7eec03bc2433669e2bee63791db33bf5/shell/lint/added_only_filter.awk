# The "<file>\t<line>" key of a finding line.
function finding_key(line, __file, __rest) {
  __file = substr(line, 1, index(line, ":") - 1)
  __rest = substr(line, length(__file) + 2)
  return __file "\t" substr(__rest, 1, index(__rest, ":") - 1)
}

# Reads one check's findings on stdin, "<file>:<line>: <why>" each, and prints
# the ones that sit on a line the staged diff added. `added` holds
# "<file>\t<line>" entries, one per line, under every spelling of the file the
# check might print.
BEGIN {
  entry_count = split(added, entries, "\n")
  for (i = 1; i <= entry_count; i++) {
    if (entries[i] != "") {
      keep[entries[i]] = 1
    }
  }
}

/^[^:]+:[0-9]+:/ {
  if (finding_key($0) in keep) {
    print
  }
}
