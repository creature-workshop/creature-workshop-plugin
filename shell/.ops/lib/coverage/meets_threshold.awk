# Exits 0 when -v percent is at or above -v threshold, 1 otherwise. The two are
# compared as numbers, so 90 and 90.00 are equal.

BEGIN {
  if (percent + 0 >= threshold + 0) {
    exit 0
  }
  exit 1
}
