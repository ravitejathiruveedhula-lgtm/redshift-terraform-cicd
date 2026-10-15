variable "project" {
  description = "Short name used to prefix every resource."
  type        = string
  default     = "rs-cicd-lab"
}

variable "environment" {
  description = "Environment label, used in names and tags."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy into. Keep it the same as the bootstrap region."
  type        = string
  default     = "ap-southeast-2"
}

variable "github_repo" {
  description = "Repository that deployed the stack. CI sets this automatically."
  type        = string
  default     = "local"
}

variable "database_name" {
  description = "Name of the first database in the namespace."
  type        = string
  default     = "labdb"
}

variable "base_capacity_rpu" {
  description = "Base compute in Redshift Processing Units. 8 is the smallest size where available."
  type        = number
  default     = 8
}

variable "daily_rpu_hour_limit" {
  description = "Cost guardrail: RPU-hours allowed per day before the workgroup is switched off until the next day."
  type        = number
  default     = 4

  validation {
    condition     = var.daily_rpu_hour_limit >= 1
    error_message = "The daily limit must be at least 1 RPU-hour."
  }
}
