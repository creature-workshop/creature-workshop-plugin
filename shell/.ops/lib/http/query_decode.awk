# Percent-escapes decoded, one line at a time: %XX becomes the byte those
# two hex digits name. The inverse of what encode.awk encodes with, so
# a reader of a recorded URL compares the parameters a request meant rather
# than how they were spelled.
#
#   q=name%20%3D%20%27a%27  ->  q=name = 'a'

# The value of one hex digit, upper or lower case.
function hex_digit(digit) {
  return index("0123456789abcdef", tolower(digit)) - 1
}

# The byte value the two hex digits of ESCAPE name.
function hex_byte(escape) {
  return hex_digit(substr(escape, 1, 1)) * 16 + hex_digit(substr(escape, 2, 1))
}

{
  decoded = ""
  while (match($0, /%[0-9A-Fa-f][0-9A-Fa-f]/)) {
    decoded = decoded substr($0, 1, RSTART - 1) sprintf("%c", hex_byte(substr($0, RSTART + 1, 2)))
    $0 = substr($0, RSTART + RLENGTH)
  }
  print decoded $0
}
