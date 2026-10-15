variable "project" {
  description = "Short name used to prefix every resource."
  type        = string
  default     = "rs-cicd-lab"
}

variable "aws_region" {
  description = "AWS region for the state bucket and the Redshift stack."
  type        = string
  default     = "ap-southeast-2"
}

variable "github_repo" {
  description = "Your GitHub repository as owner/name, exactly as GitHub shows it (case matters)."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repo))
    error_message = "Use the owner/name form, for example raviteja/redshift-terraform-cicd."
  }
}

variable "ci_user_name" {
  description = "Existing IAM user whose access keys GitHub Actions uses (created with the AWS CLI before the bootstrap)."
  type        = string
  default     = "github-actions-ci"
}
