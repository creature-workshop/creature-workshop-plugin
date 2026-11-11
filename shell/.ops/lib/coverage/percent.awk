# Prints a coverage percent to two decimals from -v covered and -v total. A
# total of zero means there was nothing to cover, which counts as fully
# covered.

BEGIN {
  if (total + 0 == 0) {
    printf "100.00\n"
  } else {
    printf "%.2f\n", covered / total * 100
  }
}
