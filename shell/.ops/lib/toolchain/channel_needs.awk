# Prints every tool whose channel names a dependency, paired with the tool
# that dependency is, as a list of {tool, dependency} in the order of the
# tools' names. Loaded after names.awk.
#
# Input: the resolver, {registry, channels}.

function main(line) {
  tree_line(line)
}

# The dependency the channel of a tool names, and no node when its channel
# names none or an empty one.
function dependency_of(tool, __channel, __dependency) {
  __channel = text_or(member(member(member(ROOT, "registry"), tool), "channel"), "")
  __dependency = member(member(member(ROOT, "channels"), __channel), "dependency")

  if (!is_present(__dependency) || written(__dependency) == "str=\"\"") {
    return 0
  }

  return __dependency
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  count = sorted_names(member(ROOT, "registry"), tools)
  pairs = 0
  for (i = 1; i <= count; i++) {
    dependency = dependency_of(tools[i])
    if (dependency != 0) {
      print_open(0, pairs, "map")
      print_str(1, "tool", tools[i])
      print_node(dependency, 1, wrap("dependency"))
      pairs++
    }
  }

  if (pairs == 0) {
    print "0.:list"
  }
}

{ main($0) }
