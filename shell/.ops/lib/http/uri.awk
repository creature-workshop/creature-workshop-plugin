# Percent-encoding for the programs of this module. It holds functions
# alone. A program calls load_codes() from BEGIN before it encodes
# anything, and runs under LC_ALL=C, so that awk reads bytes and not
# characters.

# The text as one URL component: every byte outside the unreserved set of
# RFC 3986 as %XX.
#
#   'Over cap'!A1:Y  ->  %27Over%20cap%27%21A1%3AY
function encoded(text, __out, __i, __byte) {
  __out = ""

  for (__i = 1; __i <= length(text); __i++) {
    __byte = substr(text, __i, 1)
    if (__byte ~ /[A-Za-z0-9._~-]/) {
      __out = __out __byte
    } else {
      __out = __out sprintf("%%%02X", CODE[__byte])
    }
  }

  return __out
}

# Fills CODE with the number of every byte, so a byte can be written in hex.
function load_codes(__code) {
  for (__code = 1; __code < 256; __code++) {
    CODE[sprintf("%c", __code)] = __code
  }
}
