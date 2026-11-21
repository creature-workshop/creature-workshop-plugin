# Prints the answer lines of one block of a transcript. Blocks are
# numbered from 1 by their "## " headers, and -v wanted= names the one to
# print: the lines after its header, up to the next header.
#
#   awk -v wanted=2 -f answer.awk transcript  ->  the second call's answer

# Counts a header, and prints the lines of the block wanted.
function main() {
  if ($0 ~ /^## /) {
    block++
    return
  }

  if (block == wanted) {
    print
  }
}

{ main() }
