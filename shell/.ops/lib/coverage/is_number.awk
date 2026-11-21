# Exits 0 when -v value is a number a threshold can be: digits with an optional
# fraction. 1 otherwise, including for an empty value.

BEGIN {
  if (value ~ /^[0-9]+(\.[0-9]+)?$/) {
    exit 0
  }
  exit 1
}
