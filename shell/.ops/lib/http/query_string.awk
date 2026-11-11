# Prints a query, an object of parameters, as the query string a URL
# carries: one key=value pair for each field, the value percent-encoded,
# the pairs joined with &. An array value repeats its key once for each
# element, the way a server reads a parameter given several times. A
# number or a boolean is encoded by its text. Loaded after uri.awk.
#
#   {"q":"name = 'a'","fields":"id,name"}  ->  q=name%20%3D%20%27a%27&fields=id%2Cname
#   {"ranges":["A1","B2"]}                  ->  ranges=A1&ranges=B2

function main(line) {
  tree_line(line)
}

# Adds the pair or pairs one field yields: one for each element of an
# array, and one for any other value.
function add_field(field, __element) {
  if (NODE_TYPE[field] != "list") {
    add_pair(name_of(field), field)
    return
  }

  for (__element = NODE_FIRST[field]; __element != 0; __element = NODE_NEXT[__element]) {
    add_pair(name_of(field), __element)
  }
}

# Adds one key=value pair to the query string.
function add_pair(key, value) {
  QUERY = QUERY (PAIRS > 0 ? "&" : "") key "=" encoded(text_of(value))
  PAIRS++
}

BEGIN {
  load_codes()
  ROOT = tree_open()
  QUERY = ""
  PAIRS = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  for (field = NODE_FIRST[ROOT]; field != 0; field = NODE_NEXT[field]) {
    add_field(field)
  }
  print QUERY
}

{ main($0) }
