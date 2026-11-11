# The scheduled pipeline on main, nightly: the jobs that run under the
# schedule source, the trace map above all (.gitlab-ci/jobs/testing--trace.yml)
# and the fuzz exploration beside it. A map is never more than a day old, so
# the review pipelines select against yesterday's main at the worst, well
# inside the seven days the trace selector accepts.

resource "gitlab_pipeline_schedule" "scheduled" {
  project       = var.project
  description   = "shellops: the scheduled pipeline on main"
  ref           = "refs/heads/main"
  cron          = "0 3 * * *"
  cron_timezone = "America/Denver"
  active        = true
}
