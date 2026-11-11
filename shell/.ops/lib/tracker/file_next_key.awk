# Prints the key the next ticket of the document takes, as a str: the
# prefix, a dash, and one past the highest number a key of that prefix
# has.
#
# Input: the document. Argument "prefix".
#
#   {"tickets":[{"key":"PLAN-3"},{"key":"OTHER-9"}]}, prefix PLAN  ->  "PLAN-4"

function main(line) {
  tree_line(line)
}

# The number a key of the prefix ends in, and 0 for a key that ends in
# anything else.
function number_of(key, __parts, __count) {
  __count = split(key, __parts, "-")
  if (__parts[__count] ~ /^-?[0-9]+(\.[0-9]+)?$/) {
    return __parts[__count] + 0
  }

  return 0
}

# The highest number among the keys of the prefix, and 0 when no key has
# the prefix.
function highest(__ticket, __key, __highest) {
  __highest = 0

  for (__ticket = NODE_FIRST[member(ROOT, "tickets")]; __ticket != 0; __ticket = NODE_NEXT[__ticket]) {
    __key = text_of(member(__ticket, "key"))
    if (index(__key, arg("prefix") "-") == 1 && number_of(__key) > __highest) {
      __highest = number_of(__key)
    }
  }

  return __highest
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print "0.:str=" wrap(arg("prefix") "-" (highest() + 1))
}

{ main($0) }
