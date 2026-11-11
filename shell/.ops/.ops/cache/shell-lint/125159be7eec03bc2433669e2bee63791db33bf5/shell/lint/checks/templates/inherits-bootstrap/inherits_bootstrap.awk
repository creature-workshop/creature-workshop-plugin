# The template-inherits-bootstrap detector: no job defines its own
# before_script, because a job that does loses the base job's. Prints one
#   <file>:<lineno>: <message>
# line per job that does, and nothing when none does; the exit status is
# always 0 (the caller decides severity from the presence of output).
#
# The yaml model in yaml_scan.awk tells a job's own before_script key from
# the same word inside an input name, a script line or a heredoc. The base
# template is exempt because the caller does not pass it. Load after
# scan.awk, yaml_scan.awk and documents.awk.

# True when the key just read is a job's own before_script: a key one level
# inside a named top-level key, which in a job document is a job.
function is_job_before_script() {
  return (yaml_key == "before_script" && yaml_key_is_child_of_root())
}

# True when the key just read is a job written as a flow mapping
# (`job: {before_script: ...}`). The model does not see inside a flow
# mapping, so the value text is searched instead.
function is_flow_job_before_script() {
  if (!yaml_key_is_root()) {
    return 0
  }
  return yaml_flow_declares(yaml_value, "before_script")
}

# The message for one finding. A `default:` block sets before_script for
# every job in the pipeline, including jobs outside the template, so it gets
# its own message.
function before_script_note(owner) {
  if (owner == "default") {
    return "'default:' sets before_script for every job in the pipeline; remove it and extend the base job"
  }
  return "job '" owner "' defines before_script; remove it and extend the base job"
}

function check_line() {
  if (yaml_advance($0) != "key" || !is_job_document()) {
    return
  }
  if (is_job_before_script()) {
    note(FNR, before_script_note(yaml_key_parent))
    return
  }
  if (is_flow_job_before_script()) {
    note(FNR, before_script_note(yaml_key))
  }
}

FNR == 1 {
  yaml_reset()
}

{
  check_line()
}
