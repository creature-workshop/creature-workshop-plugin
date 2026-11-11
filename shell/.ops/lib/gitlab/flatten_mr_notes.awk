# Flattens the notes GitLab's GraphQL API lists for a merge request into a
# shape that parallels the note its REST API answers, so the callers that
# write and read comments need not know which API answered.
#
# Output: a list of {id, body, type, author, created_at, updated_at,
#         system, position, discussion}.
#
# The id is the gid the API returned. The type is the part of the gid that
# names the kind of note, DiscussionNote for a reply in a thread, and a
# null for the base kind, which the gid writes "Note" and REST stores as a
# null. The position is the line of the diff a note is anchored to, and a
# null for a note on the conversation, which tells the two kinds apart.
#
# The discussion is the thread a note is in: its gid, which a reply on the
# thread is addressed to, and the thread's first note, whose id against the
# note's own says whether the note opened the thread. It is a null when the
# API sent none.

function main(line) {
  tree_line(line)
}

# What the kind of a note writes after a key: the part of its gid before
# the last, as a str, and a null for "Note" or a gid with fewer than two
# parts.
function note_type(id, __parts, __count) {
  __count = split(text_of(id), __parts, "/")
  if (__count < 2 || __parts[__count - 1] == "Note") {
    return "null"
  }

  return "str=" wrap(__parts[__count - 1])
}

# Prints the thread a note is in, at depth 1, or a null.
function print_discussion(discussion, __first) {
  if (!is_present(discussion)) {
    print "1." wrap("discussion") ":null"
    return
  }

  print_open(1, wrap("discussion"), "map")
  print_as(member(discussion, "id"), 2, "id")

  __first = child(member(member(discussion, "notes"), "nodes"), 0)
  if (!is_present(__first)) {
    print "2." wrap("first_note") ":null"
    return
  }
  print_open(2, wrap("first_note"), "map")
  print_as(member(__first, "id"), 3, "id")
  print_as(member(__first, "body"), 3, "body")
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  notes = 0
  for (note = NODE_FIRST[ROOT]; note != 0; note = NODE_NEXT[note]) {
    print_open(0, notes, "map")
    print_as(member(note, "id"), 1, "id")
    print_as(member(note, "body"), 1, "body")
    print "1." wrap("type") ":" note_type(member(note, "id"))
    print_as(member(note, "author"), 1, "author")
    print_as(member(note, "createdAt"), 1, "created_at")
    print_as(member(note, "updatedAt"), 1, "updated_at")
    print_as(member(note, "system"), 1, "system")
    print_as(member(note, "position"), 1, "position")
    print_discussion(member(note, "discussion"))
    notes++
  }

  if (notes == 0) {
    print "0.:list"
  }
}

{ main($0) }
