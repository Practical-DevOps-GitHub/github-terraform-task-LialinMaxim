terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 5.0.0"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# Retrieve repository information to obtain the node_id (repository_id)
data "github_repository" "repo" {
  full_name = "${var.github_owner}/${var.repository}"
}

##############################
# 1. Add collaborator
##############################
resource "github_repository_collaborator" "softservedata" {
  repository = var.repository
  username   = "softservedata"
  permission = "push"
}

##############################
# 2. Set default branch to "develop"
##############################
resource "github_branch_default" "default" {
  repository = var.repository
  branch     = "develop"
}

##############################
# 3. Branch protection rules
##############################
# Protect the "develop" branch: pull requests are required with at least 2 approving reviews.
resource "github_branch_protection" "develop" {
  repository_id = data.github_repository.repo.node_id
  pattern       = "develop"
  enforce_admins = true

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 2
  }
}

# Protect the "main" branch: pull requests require approval with code owner review.
resource "github_branch_protection" "main" {
  repository_id = data.github_repository.repo.node_id
  pattern       = "main"
  enforce_admins = true

  required_pull_request_reviews {
    dismiss_stale_reviews      = true
    require_code_owner_reviews = true
  }
}

##############################
# 3b. CODEOWNERS file (assign softservedata as the code owner for all files in the "main" branch)
##############################
resource "github_repository_file" "codeowners" {
  repository     = var.repository
  file           = ".github/CODEOWNERS"
  content        = "* @softservedata\n"
  commit_message = "Add CODEOWNERS file"
  branch         = "main"
}

##############################
# 4. Add pull request template in the .github directory
##############################
resource "github_repository_file" "pull_request_template" {
  repository     = var.repository
  file           = ".github/pull_request_template.md"
  content        = <<-EOF
    # Pull Request Template

    ## Description
    Please provide a detailed description of your changes.

    ## Issue
    Link the issue that this pull request addresses.
    EOF
  commit_message = "Add pull request template"
  branch         = "develop"
}

##############################
# 5. Add deploy key named "DEPLOY_KEY"
##############################
resource "github_repository_deploy_key" "deploy_key" {
  repository = var.repository
  title      = "DEPLOY_KEY"
  key        = var.deploy_key
  read_only  = true
}

##############################
# 6. Configure Discord notifications (webhook) for pull requests
##############################
resource "github_repository_webhook" "discord" {
  repository_id = data.github_repository.repo.node_id
  active        = true
  events        = ["pull_request"]

  configuration {
    url          = var.discord_webhook_url
    content_type = "json"
    insecure_ssl = false
  }
}

##############################
# 7. Create GitHub Actions secret for PAT (Personal Access Token)
##############################
resource "github_actions_secret" "pat" {
  repository      = var.repository
  secret_name     = "PAT"
  plaintext_value = var.pat
}

##############################
# Variables
##############################
variable "github_token" {
  description = "GitHub token with permissions to manage repository settings."
  type        = string
}

variable "github_owner" {
  description = "The owner (organization or user) of the repository."
  type        = string
}

variable "repository" {
  description = "The name of the GitHub repository to configure."
  type        = string
}

variable "deploy_key" {
  description = "SSH deploy key to be added to the repository."
  type        = string
}

variable "pat" {
  description = "Personal Access Token for GitHub Actions with full control of private repositories and organizations."
  type        = string
}

variable "discord_webhook_url" {
  description = "The URL of the Discord webhook to receive pull request notifications."
  type        = string
}
