# The merge gate on the project itself: a merge request lands only on a
# pipeline that ran and passed at its head, after a rebase onto main. A head
# whose pipeline was skipped is refused rather than counted as a pass, so a
# red pipeline on an earlier commit can never be stepped over by a commit
# that ran nothing. The project was made by hand and is adopted here, never
# created or destroyed by an apply.

import {
  to = gitlab_project.shellops
  id = var.project
}

resource "gitlab_project" "shellops" {
  name = "shellops"

  merge_method                          = "rebase_merge"
  only_allow_merge_if_pipeline_succeeds = true
  allow_merge_on_skipped_pipeline       = false

  lifecycle {
    prevent_destroy = true
  }
}
