################################################################################
# Terraform Configuration for GitHub Provider
################################################################################
terraform {
  required_version = ">= 1.0"

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

################################################################################
# Create GitHub Repository
################################################################################
resource "github_repository" "example_repo" {
  name           = "example-repo"
  description    = "Example repository for demonstration"
  visibility     = "private"
  auto_init      = true
  default_branch = "develop"
}

################################################################################
# Add a Collaborator (softservedata) to the Repository
################################################################################
resource "github_repository_collaborator" "collaborator" {
  repository = github_repository.example_repo.name
  username   = "softservedata"
  permission = "push"
}

################################################################################
# Create (or reference) the 'main' branch
################################################################################
resource "github_branch" "main_branch" {
  repository    = github_repository.example_repo.name
  branch        = "main"
  source_branch = github_repository.example_repo.default_branch
}

################################################################################
# Protect the 'develop' branch
################################################################################
resource "github_branch_protection" "develop_protection" {
  repository = github_repository.example_repo.name
  branch     = "develop"

  require_pull_request_before_merge = true

  required_pull_request_reviews {
    required_approving_review_count = 2
    dismiss_stale_reviews           = true
  }

  enforce_admins = true
}

################################################################################
# Protect the 'main' branch
################################################################################
resource "github_branch_protection" "main_protection" {
  repository = github_repository.example_repo.name
  branch     = "main"

  require_pull_request_before_merge = true

  required_pull_request_reviews {
    required_approving_review_count = 1
    require_code_owner_reviews      = true
    dismiss_stale_reviews           = true
  }

  enforce_admins = true
}

################################################################################
# Add CODEOWNERS in the .github directory on main branch
################################################################################
resource "github_repository_file" "codeowners" {
  repository = github_repository.example_repo.name
  file       = ".github/CODEOWNERS"
  content    = <<-EOT
    * @softservedata
  EOT

  commit_message = "Add CODEOWNERS for main branch"
  branch         = github_branch.main_branch.branch
}

################################################################################
# Add a Pull Request Template in .github directory
################################################################################
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

################################################################################
# Add a Deploy Key
################################################################################
resource "github_repository_deploy_key" "deploy_key" {
  repository = github_repository.example_repo.name
  title      = "DEPLOY_KEY"
  key = file("${path.module}/deploy_key.pub")
  read_only  = true
}

################################################################################
# Create a Webhook to notify Discord on pull_request
################################################################################
resource "github_repository_webhook" "discord_webhook" {
  repository = github_repository.example_repo.name
  name       = "web"
  active     = true
  events = ["pull_request"]

  configuration {
    url          = "https://discord.com/api/webhooks/1348026892598509729/4pGfZoE7-pJ4sZroeV2pm_1S7aGxJdwVYkbXXJqZGY1_DGupuVzOrtO9p96siEI0le1v"
    content_type = "json"
    insecure_ssl = false
  }
}
