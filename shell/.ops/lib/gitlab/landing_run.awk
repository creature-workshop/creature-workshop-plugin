# Prints the landing run among a merge request's pipelines: the newest
# merge-request pipeline created while the merge request carried the
# landing mark, as {id, sha, status}, or a null when there is none. Loaded
# after runs.awk.
#
# A pipeline created while the mark was on is a landing run whoever created
# it (ADR.2@scheduler), because GitLab copies a merge request's labels when
# a pipeline is created and the rules read them there. So the history of
# the mark says which pipeline is the run. One created before the mark went
# on, or after it came off, ran the governance checks alone.
#
# Input:  {pipelines: [{id, sha, status, source, created_at}],
#          events: [{action, created_at, label: {name}}], label}
#
#   {"pipelines":[{"id":7035,"sha":"24d3b90f","status":"running",
#                  "source":"merge_request_event","created_at":"2026-09-25T00:29:30Z"}],
#    "events":[{"action":"add","created_at":"2026-09-25T00:16:31Z",
#               "label":{"name":"scheduler/next-merge"}}],
#    "label":"scheduler/next-merge"}
#     ->  {"id":"7035","sha":"24d3b90f","status":"running"}

function main(line) {
  tree_line(line)
}

# Reads the history of the mark: MARKED_AT, when it last went on, with
# MARKED 1 when it ever did, and UNMARKED_AT, when it came off after that,
# with UNMARKED 1 when it has. Times are ISO 8601 in UTC and order as text.
function read_marks(__event) {
  MARKED = 0
  UNMARKED = 0

  for (__event = NODE_FIRST[member(ROOT, "events")]; __event != 0; __event = NODE_NEXT[__event]) {
    note_mark_on(__event)
  }
  for (__event = NODE_FIRST[member(ROOT, "events")]; __event != 0; __event = NODE_NEXT[__event]) {
    note_mark_off(__event)
  }
}

# Whether an event is about the mark and has the action given and a time.
function is_mark_event(event, action) {
  return text_or(member(member(event, "label"), "name"), "") == text_of(member(ROOT, "label")) \
    && text_of(member(event, "action")) == action \
    && is_present(member(event, "created_at"))
}

# Keeps the latest time the mark went on.
function note_mark_on(event, __at) {
  if (!is_mark_event(event, "add")) {
    return
  }

  __at = text_of(member(event, "created_at"))
  if (!MARKED || (__at "") > (MARKED_AT "")) {
    MARKED_AT = __at
    MARKED = 1
  }
}

# Keeps the earliest time the mark came off after it last went on.
function note_mark_off(event, __at) {
  if (!MARKED || !is_mark_event(event, "remove")) {
    return
  }

  __at = text_of(member(event, "created_at"))
  if ((__at "") > (MARKED_AT "") && (!UNMARKED || (__at "") < (UNMARKED_AT ""))) {
    UNMARKED_AT = __at
    UNMARKED = 1
  }
}

# Whether a pipeline is a merge-request pipeline created while the mark was
# on.
function in_window(pipeline, __at) {
  if (text_of(member(pipeline, "source")) != "merge_request_event" || !is_present(member(pipeline, "created_at"))) {
    return 0
  }

  __at = text_of(member(pipeline, "created_at"))
  return (__at "") >= (MARKED_AT "") && (!UNMARKED || (__at "") < (UNMARKED_AT ""))
}

# The pipeline in the window that was created last, and of several created
# at the same time the one GitLab lists last. 0 when none is in the window.
function newest_marked(__pipeline, __newest) {
  __newest = 0

  for (__pipeline = NODE_FIRST[member(ROOT, "pipelines")]; __pipeline != 0; __pipeline = NODE_NEXT[__pipeline]) {
    if (in_window(__pipeline) && (__newest == 0 || (text_of(member(__pipeline, "created_at")) "") >= (text_of(member(__newest, "created_at")) ""))) {
      __newest = __pipeline
    }
  }

  return __newest
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  read_marks()
  run = MARKED ? newest_marked() : 0
  if (run == 0) {
    print "0.:null"
  } else {
    print_run(run, 0)
  }
}

{ main($0) }
