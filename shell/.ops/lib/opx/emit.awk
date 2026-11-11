# emit.awk -- writing the lines of an OPX document, shared by every awk
# program that writes OPX so no two of them spell a node differently.
#
# An id is five characters drawn at random from the 64 the format allows and
# never handed out twice by one program. The draw starts from two things the
# caller gives: -v seed=<number>, which an owner keeps for its whole
# compilation, and -v unit=<name>, which names this document within it. One
# seed and one unit always draw the same ids, so a document compiled again
# keeps them, and two units of one seed draw different ones, so ids do not
# repeat across a compilation. The draw is this file's own arithmetic, not
# awk's rand, which no two awks agree on. With no seed it starts from the
# clock.
#
#   opx_emit_composite(1, "suite")          ->  xK_mQ 1.suite
#   opx_emit_leaf(2, "name", "string", "a") ->  Lp3qR 2.name:string."a"

# The code of an ASCII character, and 128 for any other.
function opx_ord(c, __i) {
  if (!OPX_ORD_READY) {
    for (__i = 1; __i < 128; __i++) {
      OPX_ORD[sprintf("%c", __i)] = __i
    }
    OPX_ORD_READY = 1
  }
  return (c in OPX_ORD) ? OPX_ORD[c] : 128
}

# A number folded together with the characters of text, under the draw's
# modulus, so every text moves the number somewhere of its own.
function opx_mix(number, text, __i) {
  for (__i = 1; __i <= length(text); __i++) {
    number = (number * 31 + opx_ord(substr(text, __i, 1))) % 2147483647
  }
  return number
}

# Starts the draw, once, from the seed and the unit, or from the clock.
function opx_seed_ids() {
  if (OPX_STATE != "") {
    return
  }
  if (seed == "") {
    srand()
    seed = srand()
  }
  OPX_STATE = (opx_mix(seed % 2147483647, unit) % 2147483646) + 1
}

# The next number of the draw, from 0 up to but not 1. Lehmer's generator,
# whose products stay exact in awk's numbers.
function opx_draw() {
  OPX_STATE = (OPX_STATE * 48271) % 2147483647
  return (OPX_STATE - 1) / 2147483646
}

# Five characters drawn at random from the id alphabet.
function opx_draw_id(__alphabet, __id, __i) {
  __alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
  __id = ""
  for (__i = 1; __i <= 5; __i++) {
    __id = __id substr(__alphabet, int(opx_draw() * 64) + 1, 1)
  }
  return __id
}

# An id this program has not handed out before.
function opx_next_id(__id) {
  opx_seed_ids()
  __id = opx_draw_id()
  while (__id in OPX_IDS) {
    __id = opx_draw_id()
  }
  OPX_IDS[__id] = 1
  return __id
}

# One character of a string value as OPX writes it.
function opx_escape_char(c) {
  if (c == "\"") {
    return "\\\""
  }
  if (c == "\\") {
    return "\\\\"
  }
  if (c == "\n") {
    return "\\n"
  }
  if (c == "\t") {
    return "\\t"
  }
  if (c == "\r") {
    return "\\r"
  }
  return c
}

# Text as a quoted, escaped string value.
function opx_quote(s, __out, __i) {
  __out = ""
  for (__i = 1; __i <= length(s); __i++) {
    __out = __out opx_escape_char(substr(s, __i, 1))
  }
  return "\"" __out "\""
}

# Prints a composite node.
function opx_emit_composite(depth, role) {
  printf "%s %d.%s\n", opx_next_id(), depth, role
}

# Prints a leaf node. A string's value is quoted here; any other type's is
# printed as given.
function opx_emit_leaf(depth, role, type, value) {
  if (type == "string") {
    value = opx_quote(value)
  }
  printf "%s %d.%s:%s.%s\n", opx_next_id(), depth, role, type, value
}
