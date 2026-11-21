# Reads markdown on stdin and prints its inline links, one per line as they
# are written, [text](target), in the order they appear. Fenced code is
# skipped, since a link shown as syntax is not one the author placed. The
# link readers come from lines.awk, shared with the programs that hold a
# document's links to a rule.
#
#     See [the form](docs/form.md) and [ADR.1@global](../000001/adr.md).
#       ->  [the form](docs/form.md)
#           [ADR.1@global](../000001/adr.md)

function print_links(line, __rest) {
  __rest = line
  while (has_link(__rest)) {
    print substr(__rest, RSTART, RLENGTH)
    __rest = substr(__rest, RSTART + RLENGTH)
  }
}

is_code_fence($0) { next }
in_fence          { next }
{ print_links($0) }
