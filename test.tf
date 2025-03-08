###########################################################################
# Terraform Configuration for GitHub Provider
###########################################################################
terraform {
  required_version = ">= 1.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "github" {
  # Provide a GitHub token with the necessary permissions
  # (e.g., via GITHUB_TOKEN env variable).
  # The owner is the GitHub organization or user who owns the repo.
  token = var.github_token
  owner = var.github_owner
}

###########################################################################
# Create GitHub Repository
###########################################################################
resource "github_repository" "example_repo" {
  name          = "example-repo"
  description   = "Example repository for demonstration"
  visibility    = "private"
  # Set the default branch to develop
  auto_init     = true
  has_issues    = true
  has_wiki      = false
  has_downloads = true
  # GitHub now supports direct default branch creation for brand new repos
  default_branch = "develop"
}

###########################################################################
# Add a Collaborator (softservedata) to the Repository
###########################################################################
resource "github_repository_collaborator" "collaborator" {
  repository = github_repository.example_repo.name
  username   = "softservedata"
  permission = "push"
}

###########################################################################
# Create (or reference) the 'main' branch
# Since 'auto_init' is set, GitHub will have created an initial commit on
# the default branch (develop). We create a reference to 'main' manually
# here. If you already have a 'main' branch, you may need to import it.
###########################################################################
resource "github_branch" "main_branch" {
  repository = github_repository.example_repo.name
  branch     = "main"

  # If you want to base 'main' on 'develop', you can provide the SHA from 'develop'.
  # We fetch the HEAD commit SHA of the default branch for demonstration:
  source_branch = github_repository.example_repo.default_branch
}

###########################################################################
# Protect the 'develop' branch
# Requirements:
#   - a user cannot merge without a pull request
#   - merging into develop requires 2 approvals
###########################################################################
resource "github_branch_protection" "develop_protection" {
  repository = github_repository.example_repo.name
  branch     = "develop"

  require_pull_request_before_merge = true

  required_pull_request_reviews {
    required_approving_review_count = 2
    # Enforce if you want stale approvals dismissed on changes
    dismiss_stale_reviews = true
  }

  # Enforce on admins
  enforce_admins = true
}

###########################################################################
# Protect the 'main' branch
# Requirements:
#   - a user cannot merge without a pull request
#   - merging requires approval from the code owner (softservedata) only
#     i.e., 1 approval, but it must be from code owner
###########################################################################
resource "github_branch_protection" "main_protection" {
  repository = github_repository.example_repo.name
  branch     = "main"

  require_pull_request_before_merge = true

  required_pull_request_reviews {
    required_approving_review_count = 1
    # This forces the code owner to approve the PR
    require_code_owner_reviews = true
    dismiss_stale_reviews      = true
  }

  # Enforce on admins
  enforce_admins = true
}

###########################################################################
# Add CODEOWNERS file for main branch to assign code ownership to softservedata
# This file must reside in the '.github' directory of the repository.
#
# NOTE: Because we want code owners to be assigned to all files in the main
# branch, we simply specify "*" pattern with @softservedata as the owner.
###########################################################################
resource "github_repository_file" "codeowners" {
  repository = github_repository.example_repo.name
  file       = ".github/CODEOWNERS"
  content    = <<-EOT
    * @softservedata
  EOT

  commit_message = "Add CODEOWNERS for main branch"
  branch         = github_branch.main_branch.branch
}

###########################################################################
# Add a Pull Request Template in the .github directory
# Named pull_request_template.md
###########################################################################
resource "github_repository_file" "pull_request_template" {
  repository = github_repository.example_repo.name
  file       = ".github/pull_request_template.md"
  content    = <<-EOT
    ## Pull Request Template

    ### Summary
    Provide a concise description of your changes here.

    ### Issue Reference
    (If this PR addresses an existing issue, link it here with, e.g., #123)

    ### Additional Details
    Any additional details or context.
  EOT

  commit_message = "Add Pull Request Template"
  branch         = github_branch.main_branch.branch
}

###########################################################################
# Add a Deploy Key
# The key can be generated prior to this step. This example is fictional.
# 'read_only' can be set to false if you want write access with the key.
###########################################################################
resource "github_repository_deploy_key" "deploy_key" {
  repository = github_repository.example_repo.name
  title      = "DEPLOY_KEY"
  key        = file("${path.module}/deploy_key.pub")  # Or place the public key inline.
  read_only  = true
}

###########################################################################
# Create a Webhook to notify Discord when a pull request is created
# Provide the actual webhook URL from your Discord server
###########################################################################
resource "github_repository_webhook" "discord_webhook" {
  repository = github_repository.example_repo.name
  name       = "web"
  active     = true
  events     = ["pull_request"]

  configuration {
    url          = "https://discord.com/api/webhooks/1348026892598509729/4pGfZoE7-pJ4sZroeV2pm_1S7aGxJdwVYkbXXJqZGY1_DGupuVzOrtO9p96siEI0le1v"
    content_type = "json"
    insecure_ssl = false
  }
}

