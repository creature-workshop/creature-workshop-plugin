# The job-lands-once detector: every rule that matches a merge-request
# pipeline also requires the landing mark, so the job runs once per merge
# request, in the landing run. Prints one
#   <file>:<lineno>: <message>
# line per rule that does not, on the rule's `if`, and nothing when all do;
# the exit status is always 0 (the caller decides severity from the presence
# of output).
#
# A job's `rules` list is read one entry at a time. The entry's `if` opens
# it, its own `when: never` withdraws it, and the next key outside the entry,
# or the end of the file, closes it. Judgement waits for the close, because
# the `when` comes after the `if`. A condition written as a block scalar or
# folded over several lines continues on the content lines after the `if`,
# which are appended to the open entry's condition.
#
# The mark arrives as CI_TEMPLATE_MARK in the environment, because awk -v
# rewrites backslashes and a mark is a regex. The templates that run on every
# push are exempt because the caller does not pass them. Load after scan.awk,
# yaml_scan.awk and documents.awk.

# True when NAME is a GitLab global keyword rather than a job. `workflow:`
# and `default:` carry rules of their own, which this detector leaves alone.
function is_global_keyword(name) {
  return (name == "workflow" || name == "default" || name == "include" || name == "stages" || name == "variables" || name == "spec")
}

# True when the key just read is inside one entry of a job's `rules` list:
# three frames deep, in a sequence entry, under a `rules` key directly under
# a job.
function in_rules_entry() {
  if (yaml_key_depth != 3 || !yaml_frame_seq[3] || yaml_frame_key[2] != "rules") {
    return 0
  }
  return (!yaml_frame_seq[1] && !is_global_keyword(yaml_frame_key[1]))
}

function is_entry_condition() {
  return (yaml_key == "if" && in_rules_entry())
}

function is_entry_when() {
  return (yaml_key == "when" && in_rules_entry())
}

function entry_is_open() {
  return (entry_line > 0)
}

# Opens the entry at the `if` just read: where it is, its job, and its
# condition so far. Content lines up to the next key are still the condition.
function open_entry() {
  entry_file = FILENAME
  entry_line = FNR
  entry_job = yaml_frame_key[1]
  entry_condition = yaml_value
  entry_continues = 1
}

# Appends one more line of a folded condition to the open entry.
function extend_entry_condition() {
  entry_condition = entry_condition " " yaml_trim($0)
}

# Forgets the open entry without judging it: `when: never` means the rule
# never runs, whatever its condition matches.
function withdraw_entry() {
  forget_entry()
}

function forget_entry() {
  entry_file = ""
  entry_line = 0
  entry_job = ""
  entry_condition = ""
  entry_continues = 0
}

# Judges the open entry, if any, and forgets it. The finding names the
# entry's own file, since the file may have ended since it opened.
function close_entry() {
  if (entry_is_open() && entry_runs_on_every_push()) {
    printf "%s:%d: %s\n", entry_file, entry_line, every_push_note(entry_job)
  }
  forget_entry()
}

# True when the open entry's condition matches merge_request_event without
# the mark: its job runs on every push to a merge request.
function entry_runs_on_every_push() {
  return (index(entry_condition, "merge_request_event") > 0 && index(entry_condition, mark) == 0)
}

function every_push_note(job) {
  return "job '" job "' runs on every push: its rule matches merge_request_event without the mark '" mark "'"
}

# Handles one key: an entry's own `when` may withdraw it, any other key
# closes it, and an `if` opens the next.
function check_key() {
  if (!is_job_document()) {
    return
  }
  if (is_entry_when()) {
    if (yaml_value == "never") {
      withdraw_entry()
    }
    return
  }
  close_entry()
  if (is_entry_condition()) {
    open_entry()
  }
}

# A key ends the condition being read, if any.
function read_line(__kind) {
  __kind = yaml_advance($0)
  if (__kind == "content" && entry_continues) {
    extend_entry_condition()
    return
  }
  if (__kind == "key") {
    entry_continues = 0
    check_key()
  }
}

BEGIN {
  mark = ENVIRON["CI_TEMPLATE_MARK"]
  forget_entry()
}

# A new file closes what the last one left open, then starts clean.
FNR == 1 {
  close_entry()
  yaml_reset()
}

{
  read_line()
}

END {
  close_entry()
}
