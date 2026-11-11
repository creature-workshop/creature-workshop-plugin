# Prints the id of the team's workflow state that has a name, or the empty
# str when the team has none of that name.
#
# Input: the team record. Argument "name": the name of the state.

function main(line) {
  tree_line(line)
}

# The id of the first state of the team with the name asked for, and no
# node when none has it.
function state_id(__state) {
  for (__state = NODE_FIRST[member(member(ROOT, "states"), "nodes")]; __state != 0; __state = NODE_NEXT[__state]) {
    if (NODE_TYPE[member(__state, "name")] == "str" && text_of(member(__state, "name")) == arg("name")) {
      return member(__state, "id")
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

  id = state_id()
  print "0.:" (is_present(id) ? written(id) : "str=\"\"")
}

{ main($0) }
