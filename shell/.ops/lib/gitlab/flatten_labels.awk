# Reshapes the labels GitLab's REST API lists into the shape Forgejo lists
# them in, so labels__diff_labels reads both the same way: a list of
# {id, name, color, description, is_archived}.
#
# GitLab writes a color as "#rrggbb" and Forgejo writes it without the #,
# so the # is taken off. A label with no description has the empty one.

function main(line) {
  tree_line(line)
}

# The color of a label without its leading #.
function plain_color(label, __color) {
  __color = text_of(member(label, "color"))
  sub(/^#/, "", __color)

  return __color
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  labels = 0
  for (label = NODE_FIRST[ROOT]; label != 0; label = NODE_NEXT[label]) {
    print_open(0, labels, "map")
    print_as(member(label, "id"), 1, "id")
    print_as(member(label, "name"), 1, "name")
    print_str(1, "color", plain_color(label))
    print_or(member(label, "description"), 1, "description", "str=\"\"")
    print "1." wrap("is_archived") ":bool=false"
    labels++
  }

  if (labels == 0) {
    print "0.:list"
  }
}

{ main($0) }
