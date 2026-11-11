# Compares the labels a repository wants with the labels a forge has, and
# prints what has to change: {create, update, archive}.
#
# Input: the desired labels, a list of {name, color, description}, and
#        ahead of it, with --with, the forge's labels, a list of
#        {id, name, color, description, is_archived}.
# Output: create holds each desired label the forge does not have. update
#         holds each desired label whose color or description differs from
#         the forge's, with the forge's id. archive holds {id, name} of
#         each label of the forge that is not archived and not desired.
#
# Two colors are the same when they differ only in a leading # or in the
# case of their letters. A label of the forge with no description has the
# empty description. When the forge has two labels of one name, the last
# is the one compared.

function main(line) {
  tree_line(line)
}

# Notes every label of the forge under its name, the last of a name
# winning.
function note_actual(__label) {
  for (__label = NODE_FIRST[ACTUAL]; __label != 0; __label = NODE_NEXT[__label]) {
    ACTUAL_NAMED[text_of(member(__label, "name"))] = __label
  }
}

# Sorts every desired label into CREATE or UPDATE, or neither, and notes
# its name as desired.
function sort_desired(__label, __name) {
  for (__label = NODE_FIRST[DESIRED]; __label != 0; __label = NODE_NEXT[__label]) {
    __name = text_of(member(__label, "name"))
    IS_DESIRED[__name] = 1

    if (!(__name in ACTUAL_NAMED)) {
      CREATE[++CREATES] = __label
    } else if (drifted(__label, ACTUAL_NAMED[__name])) {
      UPDATE[++UPDATES] = __label
    }
  }
}

# Whether a desired label and the forge's label of the same name differ in
# color or in description.
function drifted(desired, actual) {
  if (plain_color(member(desired, "color")) != plain_color(member(actual, "color"))) {
    return 1
  }

  return !same_description(member(desired, "description"), member(actual, "description"))
}

# A color without its leading # and in lower case, and the empty string
# for no color.
function plain_color(node, __color) {
  __color = text_or(node, "")
  sub(/^#/, "", __color)

  return tolower(__color)
}

# Whether a desired description and the forge's are the same value. The
# forge's reads as the empty str when it is missing or a null.
function same_description(desired, actual) {
  if (!is_present(actual)) {
    return NODE_TYPE[desired] == "str" && text_of(desired) == ""
  }

  return NODE_TYPE[desired] == NODE_TYPE[actual] && text_of(desired) == text_of(actual)
}

# Notes every label of the forge that is to be archived.
function sort_actual(__label) {
  for (__label = NODE_FIRST[ACTUAL]; __label != 0; __label = NODE_NEXT[__label]) {
    if (text_of(member(__label, "is_archived")) != "true" && !(text_of(member(__label, "name")) in IS_DESIRED)) {
      ARCHIVE[++ARCHIVES] = __label
    }
  }
}

# Prints the labels to create, each {name, color, description}.
function print_create(__i) {
  print_open(0, wrap("create"), "list")

  for (__i = 1; __i <= CREATES; __i++) {
    print_open(1, __i - 1, "map")
    print_desired(CREATE[__i])
  }
}

# Prints the labels to update, each {name, color, description, id}.
function print_update(__i, __actual) {
  print_open(0, wrap("update"), "list")

  for (__i = 1; __i <= UPDATES; __i++) {
    __actual = ACTUAL_NAMED[text_of(member(UPDATE[__i], "name"))]
    print_open(1, __i - 1, "map")
    print_desired(UPDATE[__i])
    print_node(member(__actual, "id"), 2, wrap("id"))
  }
}

# Prints the name, the color and the description of a desired label, as
# members at depth 2.
function print_desired(label) {
  print_node(member(label, "name"), 2, wrap("name"))
  print_node(member(label, "color"), 2, wrap("color"))
  print_node(member(label, "description"), 2, wrap("description"))
}

# Prints the labels to archive, each {id, name}.
function print_archive(__i) {
  print_open(0, wrap("archive"), "list")

  for (__i = 1; __i <= ARCHIVES; __i++) {
    print_open(1, __i - 1, "map")
    print_node(member(ARCHIVE[__i], "id"), 2, wrap("id"))
    print_node(member(ARCHIVE[__i], "name"), 2, wrap("name"))
  }
}

BEGIN {
  ACTUAL = tree_ahead()
  DESIRED = tree_open()
  CREATES = 0
  UPDATES = 0
  ARCHIVES = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  note_actual()
  sort_desired()
  sort_actual()
  print_create()
  print_update()
  print_archive()
}

{ main($0) }
