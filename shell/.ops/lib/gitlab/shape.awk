# Printing a member under another name, for the programs of this module
# that reshape what GitLab answers. It holds functions alone. Loaded after
# tree.awk.

# Prints a node at a depth under a name given as plain text.
function print_as(node, depth, name) {
  print_node(node, depth, wrap(name))
}

# Prints a node at a depth under a name. Where the node is missing or a
# null, prints the value given in its place, written as a line writes a
# value after its key: str="" or bool=false.
function print_or(node, depth, name, otherwise) {
  if (is_present(node)) {
    print_node(node, depth, wrap(name))
  } else {
    print depth "." wrap(name) ":" otherwise
  }
}

# The text after the last slash of a text, and the whole text when it has
# no slash.
#
#   gid://gitlab/Ci::Build/123  ->  123
function after_last_slash(text, __parts, __count) {
  __count = split(text, __parts, "/")

  return (__count > 0) ? __parts[__count] : ""
}
