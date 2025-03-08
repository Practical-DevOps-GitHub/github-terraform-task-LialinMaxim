terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "github" {
  token = var.github_token       # GitHub PAT (set manually)
  owner = var.github_owner       # GitHub organization or username
}

variable "github_token" {
  description = "GitHub Personal Access Token with required permissions"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or username"
  type        = string
}

variable "repository_name" {
  description = "Name of the GitHub repository"
  type        = string
}

variable "deploy_key" {
  description = "SSH public key for the deploy key"
  type        = string
}

variable "DISCORD_WEB_HOOK" {
  description = "Discord webhook URL for pull request notifications"
  type        = string
}

# Create or reference the GitHub repository with 'develop' as the default branch
resource "github_repository" "repo" {
  name           = var.repository_name
  default_branch = "develop"
}

# Add collaborator "softservedata" with push permissions
resource "github_repository_collaborator" "collaborator" {
  repository = github_repository.repo.name
  username   = "softservedata"
  permission = "push"
}

# Protect the 'main' branch with code owner review requirement
resource "github_branch_protection" "main_protection" {
  repository_id = github_repository.repo.node_id
  pattern       = "main"

  required_pull_request_reviews {
    require_code_owner_reviews      = true
    required_approving_review_count = 1
  }

  enforce_admins = false
}

# Protect the 'develop' branch requiring two approvals
resource "github_branch_protection" "develop_protection" {
  repository_id = github_repository.repo.node_id
  pattern       = "develop"

  required_pull_request_reviews {
    required_approving_review_count = 2
  }

  enforce_admins = false
}

# Add CODEOWNERS file to the main branch to assign softservedata as code owner
resource "github_repository_file" "codeowners" {
  repository     = github_repository.repo.name
  file           = ".github/CODEOWNERS"
  content        = "* @softservedata"
  commit_message = "Add CODEOWNERS file"
  branch         = "main"
}

# Add a pull request template to the .github directory on the develop branch
resource "github_repository_file" "pr_template" {
  repository     = github_repository.repo.name
  file           = ".github/pull_request_template.md"
  content        = <<EOF
# Pull Request Template

## Description
Please describe the changes proposed in this pull request and reference any relevant issues.

## Checklist
- [ ] Code follows style guidelines
- [ ] Tests have been added/updated
- [ ] Documentation has been updated
EOF
  commit_message = "Add pull request template"
  branch         = "develop"
}

# Add a deploy key to the repository (deploy key value must be provided via variable)
resource "github_repository_deploy_key" "deploy_key" {
  repository = github_repository.repo.name
  title      = "DEPLOY_KEY"
  key        = var.deploy_key
  read_only  = true
}

# Create a webhook to send Discord notifications when a pull request is created
resource "github_repository_webhook" "discord_webhook" {
  repository = github_repository.repo.name

  configuration {
    url = var.DISCORD_WEB_HOOK  # Discord webhook URL from variable
    content_type = "json"
  }

  events = ["pull_request"]
  active = true
}
