# The edges of the import graph as every provider prints them: a list of
# {from, to}, in the byte order of from and then of to, with each edge
# once. Two providers that load this cannot order or print an edge
# differently. It holds functions alone. Loaded after testing.awk.

# Adds an edge to the edges that print_edges prints.
function note_edge(from, to) {
  EDGES++
  EDGE[EDGES] = from "\001" to
}

# Prints the edges noted so far as a list of {from, to}, and the empty
# list when there are none.
function print_edges(__count, __i, __ends) {
  __count = unique_texts(EDGE, EDGES)
  if (__count == 0) {
    print "0.:list"
    return
  }

  for (__i = 1; __i <= __count; __i++) {
    split(EDGE[__i], __ends, "\001")
    print_open(0, __i - 1, "map")
    print_str(1, "from", __ends[1])
    print_str(1, "to", __ends[2])
  }
}
