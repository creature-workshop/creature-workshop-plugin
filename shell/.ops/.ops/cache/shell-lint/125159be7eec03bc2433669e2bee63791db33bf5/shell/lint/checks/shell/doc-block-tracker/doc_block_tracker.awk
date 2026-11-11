# Flags a work-tracker marker inside a doc block. A doc block states a contract:
# someone opens it to learn what the unit promises, and a paragraph about work
# that has not happened answers a question they did not ask. The tracker is the
# place for that, and an issue is where the discussion can actually be had.
# Loaded with the scanner runtime and the doc-block library:
#   awk -f scan.awk -f doc_block.awk -f doc_block_tracker.awk
#
# Only doc blocks are policed. The same marker beside a line of code is a note
# to whoever edits that line, which is exactly where it belongs.
#
# Issue ids are deliberately not markers of their own. In a repository whose
# subject is parsing issue references out of prose, most ids in a doc block are
# quoted examples or the stated reason an exemption exists; matching them ran
# nine false positives in ten. An id reached through one of the markers below is
# still flagged, because the marker is what makes it a tracker reference.
#
# Emits "<name>:<lineno>: <message>" anchored to the offending line.
# Vars: -v fname=<display name> (default FILENAME).

# True when TEXT carries one of the conventional all-caps work markers.
function has_tracker_marker(text) {
  return (text ~ /(^|[^A-Za-z])(TODO|FIXME)([^A-Za-z]|$)/)
}

FNR == 1 {
  in_heredoc = 0
  in_doc = 0
}

{
  if (in_heredoc) {
    if (closes_heredoc($0)) {
      in_heredoc = 0
      in_doc = 0
    } else if (in_doc && has_tracker_marker($0)) {
      note(FNR, "work-tracker marker in a doc block; a doc states the contract, so track pending work in the tracker")
    }
    next
  }

  if (opens_heredoc($0)) {
    in_heredoc = 1
    in_doc = opens_doc_block($0)
  }
}
