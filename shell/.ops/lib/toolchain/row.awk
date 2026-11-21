# Prints one tool's row: its registry entry read field by field, so a
# caller binds every field it reads in one call. A tool the registry does
# not name leaves the fields it would have filled null.
#
# Input: the resolver. Argument "tool": the name of the tool.
# Output: {tool, entry, channel, version, override, postinstall, origin_dir}

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

  entry = member(member(ROOT, "registry"), arg("tool"))
  print_str(0, "tool", arg("tool"))
  print_node(entry, 0, wrap("entry"))
  print_node(member(entry, "channel"), 0, wrap("channel"))
  print_node(member(entry, "version"), 0, wrap("version"))
  print_node(member(entry, "override"), 0, wrap("override"))
  print_node(member(entry, "postinstall"), 0, wrap("postinstall"))
  print_node(member(entry, "origin_dir"), 0, wrap("origin_dir"))
}

{ main($0) }
