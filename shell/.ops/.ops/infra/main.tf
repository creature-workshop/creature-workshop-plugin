# The project's merge gate, and the pipeline schedules and the variables they
# carry, as Terraform against the GitLab provider: applied by ops infra
# against the state GitLab manages for this project, so a schedule changes in
# the same merge request as the job it runs and nothing is clicked together.
# The provider reads GITLAB_TOKEN from the environment; the backend's address
# and credentials come from ops infra.

terraform {
  required_version = ">= 1.6"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 17.0"
    }
  }

  backend "http" {}
}

provider "gitlab" {
  base_url = "https://gitlab.creature-workshop.com/api/v4"
}
