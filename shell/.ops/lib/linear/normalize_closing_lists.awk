# Rewrites bulleted closing lists into the inline form, so one regex handles
# both spellings:
#
#     Closes:            becomes    Closes OPS-1
#     - OPS-1                       Closes OPS-2
#     - OPS-2
#
# grep is line-oriented and cannot express the list form. Normalizing here keeps
# the alternative from becoming a second matcher with its own idea of what a
# reference looks like -- and means a bulleted "Fixes:" or "Implements:" works
# for free, since the verb set below is the one the matcher already accepts.
#
# Requires -v verb=<extended regex alternation of the closing verbs>, passed in
# from lib/linear/refs.sh so that the verb set is defined exactly once.

# An opener is a line holding nothing but a closing verb and a colon. Anchored
# at both ends, which is what separates "Closes:" from prose that merely ends in
# a colon ("...what the parser closes:") -- the latter has text before the verb.
function opens_a_list(line) {
  return tolower(line) ~ "^[[:space:]]*" verb "[[:space:]]*:[[:space:]]*$"
}

function is_bullet(line) {
  return line ~ /^[[:space:]]*[-*+][[:space:]]+/
}

function is_blank(line) {
  return line ~ /^[[:space:]]*$/
}

# Only the bullet's leading token, so "- OPS-1 (supersedes OPS-2)" declares
# OPS-1 alone. A bullet not starting with a reference yields a verb with no
# reference after it, which the matcher then ignores.
function bullet_reference(line, __item, __token) {
  __item = line
  sub(/^[[:space:]]*[-*+][[:space:]]+/, "", __item)
  split(__item, __token, /[[:space:]]/)
  return __token[1]
}

opens_a_list($0) { inlist = 1; next }

# A blank line between the opener and the list is normal markdown.
inlist && is_blank($0) { next }

inlist && is_bullet($0) {
  print "Closes " bullet_reference($0)
  next
}

# Any other line ends the list and is printed as itself.
inlist { inlist = 0 }
{ print }
