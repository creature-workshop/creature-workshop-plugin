# Prints the id of the blocks relation that a blocker has over an issue, or
# the empty str when it has none.
#
# Input: the issue record. Argument "blocker": the identifier of the issue
# that blocks it.

function main(line) {
  tree_line(line)
}

# The id of the first blocks relation whose issue is the blocker, and no
# node when there is none.
function relation_id(__relation, __identifier) {
  for (__relation = NODE_FIRST[member(member(ROOT, "inverseRelations"), "nodes")]; __relation != 0; __relation = NODE_NEXT[__relation]) {
    __identifier = member(member(__relation, "issue"), "identifier")
    if (text_of(member(__relation, "type")) == "blocks" && NODE_TYPE[__identifier] == "str" && text_of(__identifier) == arg("blocker")) {
      return member(__relation, "id")
    }
  }

  return 0
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  id = relation_id()
  print "0.:" (is_present(id) ? written(id) : "str=\"\"")
}

{ main($0) }
