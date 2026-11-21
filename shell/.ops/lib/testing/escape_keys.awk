# Prints the join keys a list of failing JUnit classnames reads as, under
# one escape-key strategy, in byte order and each once. Loaded after
# testing.awk.
#
# Input: the classnames, a list. Argument "key": "file-path", under which
# a classname is the test file itself, or "package", under which a
# classname is a cargo package with an optional ::binary after it and the
# package is the key.
#
#   ["cli::ops_cli", "errors"] under "package"  ->  ["cli", "errors"]

function main(line) {
  tree_line(line)
}

# The package of a package::binary classname.
function package_of(classname, __at) {
  __at = index(classname, "::")

  return (__at == 0) ? classname : substr(classname, 1, __at - 1)
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  count = 0
  for (classname = NODE_FIRST[ROOT]; classname != 0; classname = NODE_NEXT[classname]) {
    keys[++count] = (arg("key") == "package") ? package_of(text_of(classname)) : text_of(classname)
  }

  count = unique_texts(keys, count)
  if (count == 0) {
    print "0.:list"
  }
  print_texts(keys, count, -1)
}

{ main($0) }
