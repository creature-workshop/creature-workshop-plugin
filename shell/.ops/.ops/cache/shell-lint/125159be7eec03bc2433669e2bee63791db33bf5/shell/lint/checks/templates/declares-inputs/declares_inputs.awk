# The template-declares-inputs detector: every template starts with a
# spec.inputs block. Prints one
#   <file>:1: <message>
# line per template without one, and nothing when all have it; the exit
# status is always 0 (the caller decides severity from the presence of
# output).
#
# Whether a file has the block is known only once the whole file is read, so
# each file is judged when the next one begins, and the last at the end. Load
# after scan.awk, yaml_scan.awk and documents.awk.

# True when the key just read is `inputs` directly under a top-level `spec`.
function declares_inputs_block() {
  return (yaml_key == "inputs" && yaml_key_is_child_of_root() && yaml_key_parent == "spec")
}

# True when the key just read is a top-level `spec` written as a flow mapping
# (`spec: {inputs: ...}`).
function declares_inputs_inline() {
  if (!yaml_key_is_root() || yaml_key != "spec") {
    return 0
  }
  return yaml_flow_declares(yaml_value, "inputs")
}

function read_line(__kind) {
  __kind = yaml_advance($0)
  if (__kind != "key" || !is_spec_document()) {
    return
  }
  if (declares_inputs_block() || declares_inputs_inline()) {
    declared = 1
  }
}

# Reports the file just finished when it has no block. The finding is on
# line 1, since a missing block has no line of its own.
function judge_file(name) {
  if (!declared) {
    printf "%s:1: no spec.inputs block; every template starts with one\n", name
  }
}

function begin_file() {
  yaml_reset()
  declared = 0
  current = FILENAME
}

FNR == 1 {
  if (NR > 1) {
    judge_file(current)
  }
  begin_file()
}

{
  read_line()
}

END {
  if (current != "") {
    judge_file(current)
  }
}
