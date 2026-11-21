# The rules a .gitattributes holds, one per output line as the pattern, a
# tab, and the attributes joined by one space. A blank line or a comment is
# no rule. The pattern is the line's first word, so a pattern quoted to hold
# a space is not read.

function attributes_of_line(__i, __joined) {
  __joined = ""
  for (__i = 2; __i <= NF; __i++) {
    if (__i > 2) {
      __joined = __joined " "
    }
    __joined = __joined $__i
  }
  return __joined
}

/^[[:space:]]*(#|$)/ { next }
{ print $1 "\t" attributes_of_line() }
