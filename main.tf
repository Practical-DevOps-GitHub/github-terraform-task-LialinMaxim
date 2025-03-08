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
# Protect the "develop" branch: require pull requests with at least 2 approving reviews.
resource "github_branch_protection" "develop" {
  repository = var.repository
  branch     = "develop"

  enforce_admins = true

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 2
  }
}

# Protect the "main" branch: require that the owner approves via code owner review.
resource "github_branch_protection" "main" {
  repository = var.repository
  branch     = "main"

  enforce_admins = true

  required_pull_request_reviews {
    dismiss_stale_reviews       = true
    require_code_owner_reviews  = true
  }
}

##############################
# 3b. CODEOWNERS file (assign softservedata as owner for all files on main)
##############################
resource "github_repository_file" "codeowners" {
  repository     = var.repository
  file           = ".github/CODEOWNERS"
  content        = "* @softservedata\n"
  commit_message = "Add CODEOWNERS file"
  branch         = "main"
}

##############################
# 4. Add pull request template in .github directory
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
# 6. Create Discord notifications via webhook
##############################
# (Note: Creating a Discord server isn’t natively supported by Terraform.
# Instead, supply the Discord webhook URL via variable and use it to receive pull request notifications.)
resource "github_repository_webhook" "discord" {
  repository = var.repository
  name       = "Discord"
  active     = true
  events     = ["pull_request"]

  configuration {
    url          = var.discord_webhook_url
    content_type = "json"
    insecure_ssl = false
  }
}

##############################
# 7. Create GitHub Actions secret for PAT
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
  description = "Personal Access Token for GitHub Actions with full control of private repositories and orgs."
  type        = string
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for receiving pull request notifications."
  type        = string
}
