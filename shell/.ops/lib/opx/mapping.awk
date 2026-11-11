# mapping.awk -- how a JSON value is laid out as an OPX tree, shared by the
# two translators so what one writes the other reads back.
#
# An object is a composite whose children carry its keys as their roles, and
# an array a composite whose children are all "item". A key is any text at
# all, so one that is no bare role ("test/a.bats", "recorded_at", ""), or
# that spells the role an array keeps for its elements, is written quoted:
#
#   {"runner":"bats","tests":{"test/a.bats":{"reads":["lib/a.sh"]}},"item":1}
#
#   aaaaa 0.value
#   aaaab 1.runner:string."bats"
#   aaaac 1.tests
#   aaaad 2."test/a.bats"
#   aaaae 3.reads
#   aaaaf 4.item:string."lib/a.sh"
#   aaaag 1."item":int.1
#
# An object holds a key once. A number is "int" when it is written as one
# and "number" otherwise, its text kept as written. OPX names no null and
# cannot tell an empty object from an empty array, so the mapping adds three
# leaves: "null.null", "object.empty" and "array.empty".

# The role of every element of an array.
function opx_item_role() {
  return "item"
}

# The role of a document's root when its writer names none.
function opx_value_role() {
  return "value"
}

# Whether an object key is written bare: a bare role that is not the one an
# array keeps for its elements.
function opx_key_is_bare(key) {
  if (key == opx_item_role()) {
    return 0
  }
  return key ~ /^[a-z][a-z0-9-]*$/
}
