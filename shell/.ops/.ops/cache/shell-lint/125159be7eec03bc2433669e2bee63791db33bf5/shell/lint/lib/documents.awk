# The documents of a CI component template: the first holds the `spec:`
# block, the ones after it hold the jobs. Load after yaml_scan.awk and before
# a detector: `awk -f scan.awk -f yaml_scan.awk -f documents.awk -f <detector>.awk`.

function is_spec_document() {
  return (yaml_doc == 1)
}

function is_job_document() {
  return (yaml_doc > 1)
}
