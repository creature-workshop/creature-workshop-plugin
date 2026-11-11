# Prints the curl arguments a request's further headers take, as a list:
# -H and one "name: value" for each header, in the order the options name
# them. The list is empty when the options name none, so the caller adds
# nothing.
#
# Input: the request options.
#
#   {"headers":{"x-api-key":"k"}}  ->  ["-H","x-api-key: k"]

function main(line) {
  tree_line(line)
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  flags = 0
  for (header = NODE_FIRST[member(ROOT, "headers")]; header != 0; header = NODE_NEXT[header]) {
    print "0." flags ":str=" wrap("-H")
    print "0." (flags + 1) ":str=" wrap(name_of(header) ": " text_of(header))
    flags += 2
  }

  if (flags == 0) {
    print "0.:list"
  }
}

{ main($0) }
