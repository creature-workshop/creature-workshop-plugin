# GitLab's words for how a pipeline stands, as the words the forge contract
# and the landing queue use. It holds functions alone. Loaded after
# tree.awk.

# The run state the forge contract reports for a pipeline: none for no
# pipeline and for one GitLab skipped, success, failure for one that failed
# or was canceled, and pending for everything still to finish.
#
#   {"status": "canceled"}  ->  failure
function run_state(pipeline, __status) {
  if (!is_present(pipeline)) {
    return "none"
  }

  __status = text_of(member(pipeline, "status"))
  if (__status == "success") {
    return "success"
  }
  if (__status == "skipped") {
    return "none"
  }
  if (__status == "failed" || __status == "canceled") {
    return "failure"
  }

  return "pending"
}

# One of the four words a landing run's status is answered in
# (lib/scheduler/api.sh), for GitLab's own word. Every word for a run that
# has started and not finished reads as running, and a run that never ran
# reads as canceled, one to start again. A word this adaptor has not met is
# refused by name, and so is a run that waits on a person.
#
#   pending  ->  running
function landing_status(status) {
  if (status ~ /^(created|waiting_for_resource|preparing|pending|running|scheduled)$/) {
    return "running"
  }
  if (status == "success" || status == "failed") {
    return status
  }
  if (status ~ /^(canceled|canceling|skipped)$/) {
    return "canceled"
  }

  refuse("a run status the adaptor does not know: " status)
}

# Prints a pipeline as the landing run role answers one, {id, sha, status},
# as members at a depth: the id as a str, and the status as landing_status
# names it.
function print_run(pipeline, depth) {
  print_str(depth, "id", text_of(member(pipeline, "id")))
  print_node(member(pipeline, "sha"), depth, wrap("sha"))
  print_str(depth, "status", landing_status(text_of(member(pipeline, "status"))))
}
