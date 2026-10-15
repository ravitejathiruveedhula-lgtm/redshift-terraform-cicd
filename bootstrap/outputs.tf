output "state_bucket" {
  description = "Repository variable TF_STATE_BUCKET."
  value       = aws_s3_bucket.state.bucket
}

output "ci_user_arn" {
  description = "The IAM user GitHub Actions signs in as."
  value       = data.aws_iam_user.ci.arn
}

output "github_cli_commands" {
  description = "Optional: paste these into a terminal with the GitHub CLI (gh). The two secret commands prompt you to paste each key."
  value       = <<-EOT
    gh variable set AWS_REGION --repo ${var.github_repo} --body "${var.aws_region}"
    gh variable set TF_STATE_BUCKET --repo ${var.github_repo} --body "${aws_s3_bucket.state.bucket}"
    gh secret set AWS_ACCESS_KEY_ID --repo ${var.github_repo}
    gh secret set AWS_SECRET_ACCESS_KEY --repo ${var.github_repo}
  EOT
}
