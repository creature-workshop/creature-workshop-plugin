# Names in byte order, for the programs of this module that walk a map in
# the order of its keys. It holds functions alone. Loaded after tree.awk.

# Puts texts in byte order in place, by insertion.
function sort_texts(texts, count, __i, __place, __text) {
  for (__i = 2; __i <= count; __i++) {
    __text = texts[__i]
    __place = __i
    while (__place > 1 && (texts[__place - 1] "") > (__text "")) {
      texts[__place] = texts[__place - 1]
      __place--
    }
    texts[__place] = __text
  }
}

# Fills names with the names of the members of a map in byte order, and
# returns how many there are.
function sorted_names(map, names, __member, __count) {
  __count = 0

  for (__member = NODE_FIRST[map]; __member != 0; __member = NODE_NEXT[__member]) {
    __count++
    names[__count] = name_of(__member)
  }
  sort_texts(names, __count)

  return __count
}
