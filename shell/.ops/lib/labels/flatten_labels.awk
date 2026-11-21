# Flattens a merged label tree into a list of label records, each
# {name, color, description}. A name is "category/item", and every item in
# a category has the category's color.
#
#   {"type":{"color":"#447755","items":{"fix":"Bug fix"}}}
#   -> [{"name":"type/fix","color":"#447755","description":"Bug fix"}]

function main(line) {
  tree_line(line)
}

# Prints one record for each item of a category, numbered on from the
# records printed so far.
function print_category(category, __color, __item) {
  __color = member(category, "color")

  for (__item = NODE_FIRST[member(category, "items")]; __item != 0; __item = NODE_NEXT[__item]) {
    print_open(0, RECORDS, "map")
    print_str(1, "name", name_of(category) "/" name_of(__item))
    print_node(__color, 1, wrap("color"))
    print_node(__item, 1, wrap("description"))
    RECORDS++
  }
}

BEGIN {
  ROOT = tree_open()
  RECORDS = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  for (category = NODE_FIRST[ROOT]; category != 0; category = NODE_NEXT[category]) {
    print_category(category)
  }

  if (RECORDS == 0) {
    print "0.:list"
  }
}

{ main($0) }
