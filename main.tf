################################################################################
# Terraform Configuration for GitHub Provider
################################################################################
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

variable "PAT" {
  type        = string
  description = "GitHub Personal Access Token (PAT)"
  sensitive   = true
}

variable "github_owner" {
  type        = string
  description = "GitHub owner."
}


provider "github" {
  token = var.PAT
  owner = var.github_owner
}

###############################################################################
# Create the GitHub Repository
###############################################################################
resource "github_repository" "my_repo" {
  name        = "my-repo"
  description = "Terraform-managed repository"
  visibility = "private"

  # GitHub will create the repo with 'main' as the initial branch.
  auto_init = true
}

###############################################################################
# Create the 'develop' Branch from 'main' and Set as Default
###############################################################################
resource "github_branch" "develop" {
  repository    = github_repository.my_repo.name
  branch        = "develop"
  source_branch = "main"
}

# Change the default branch to 'develop'
resource "github_branch_default" "default" {
  repository = github_repository.my_repo.name
  branch     = github_branch.develop.branch
}

###############################################################################
# CODEOWNERS File to Assign 'softservedata' as Code Owner on 'main'
###############################################################################
resource "github_repository_file" "codeowners" {
  repository     = github_repository.my_repo.name
  file           = ".github/CODEOWNERS"
  commit_message = "Add CODEOWNERS"
  branch = "main"

  # Assign 'softservedata' as code owner of every file in the repository
  content = <<EOF
* @softservedata
EOF
}

###############################################################################
# Protect the 'develop' Branch
# - Requires pull requests
# - Requires 2 approving reviews
###############################################################################
resource "github_branch_protection" "develop_protection" {
  repository_id = github_repository.my_repo.node_id
  pattern       = github_branch.develop.branch

  # Optionally enforce admin restrictions. Set to true if admins should also
  # be prevented from pushing directly.
  enforce_admins = false

  required_pull_request_reviews {
    # Require 2 approvals on develop
    required_approving_review_count = 2
    dismiss_stale_reviews           = false
    require_code_owner_reviews      = false
  }
}

###############################################################################
# Protect the 'main' Branch
# - Requires pull requests
# - Requires the code owner (softservedata) to approve
###############################################################################
resource "github_branch_protection" "main_protection" {
  repository_id = github_repository.my_repo.node_id
  pattern = "main"

  # Set to true if you want admins also restricted
  enforce_admins = false

  required_pull_request_reviews {
    # 1 approval required, but specifically from a code owner (softservedata)
    required_approving_review_count = 1
    dismiss_stale_reviews           = false
    require_code_owner_reviews      = true
  }
}
