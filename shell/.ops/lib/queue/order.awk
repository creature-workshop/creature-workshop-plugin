# Ordering the entries of a queue by numbers, for the programs of the
# disciplines, fifo.awk and priority.awk. It holds functions alone. A
# discipline defines rank_entry(i, entry), which fills RANK[i, 1..KEYS]
# with the numbers entry i is ordered by, the first number first. Loaded
# after tree.awk.
#
#   ENTRIES        how many entries the queue has
#   ENTRY[i]       the node of entry i, in the order the queue was given
#   KEYS           how many numbers each entry is ordered by
#   RANK[i, k]     number k of entry i; a lower number orders first
#   ORDERED[n]     the entry at place n, after sort_entries()

# Reads the entries of the queue under root, and asks the discipline for
# the numbers each is ordered by.
function read_entries(root, __entry) {
  ENTRIES = 0

  for (__entry = NODE_FIRST[root]; __entry != 0; __entry = NODE_NEXT[__entry]) {
    ENTRIES++
    ENTRY[ENTRIES] = __entry
    rank_entry(ENTRIES, __entry)
  }
}

# The number a node holds, and 0 where it is missing, a null or false.
function number_or_zero(node) {
  return is_present(node) ? NODE_VALUE[node] + 0 : 0
}

# Whether entry a orders before entry b by its numbers. Two entries whose
# numbers are all the same keep the order the queue was given in.
function orders_before(a, b, __k) {
  for (__k = 1; __k <= KEYS; __k++) {
    if (RANK[a, __k] != RANK[b, __k]) {
      return RANK[a, __k] < RANK[b, __k]
    }
  }

  return a < b
}

# Puts the entries in order in ORDERED[1..ENTRIES], by insertion: each
# entry moves up past the ones it orders before.
function sort_entries(__i, __place) {
  for (__i = 1; __i <= ENTRIES; __i++) {
    __place = __i
    while (__place > 1 && orders_before(__i, ORDERED[__place - 1])) {
      ORDERED[__place] = ORDERED[__place - 1]
      __place--
    }
    ORDERED[__place] = __i
  }
}

# Prints the entries in order as a list, or the empty list.
function print_ordered(__place) {
  for (__place = 1; __place <= ENTRIES; __place++) {
    print_node(ENTRY[ORDERED[__place]], 0, __place - 1)
  }

  if (ENTRIES == 0) {
    print "0.:list"
  }
}
