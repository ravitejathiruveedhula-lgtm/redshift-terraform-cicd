data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  state_bucket = "${var.project}-tfstate-${local.account_id}-${var.aws_region}"
}

# ---------------------------------------------------------------------------
# Remote state bucket. Locking uses an S3 lock file (use_lockfile), so no
# DynamoDB table is needed - DynamoDB locking is deprecated in Terraform.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# CI identity. This account's organization policy (SCP) blocks creating an
# OIDC provider, so GitHub Actions signs in with the access keys of a
# dedicated IAM user instead. The keys live only in GitHub encrypted secrets,
# and this user gets just what the pipeline needs - never AdministratorAccess.
# ---------------------------------------------------------------------------
data "aws_iam_user" "ci" {
  user_name = var.ci_user_name
}

# Read-only access lets terraform plan and the drift check see the live stack.
resource "aws_iam_user_policy_attachment" "ci_readonly" {
  user       = data.aws_iam_user.ci.user_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "state_access" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadWriteStateAndLockFile"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
}

resource "aws_iam_user_policy" "ci_state" {
  name   = "terraform-state"
  user   = data.aws_iam_user.ci.user_name
  policy = data.aws_iam_policy_document.state_access.json
}

# Write access, limited to what the Redshift stack and the SQL deploy use.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "RedshiftServerlessAndDataApi"
    actions   = ["redshift-serverless:*", "redshift-data:*"]
    resources = ["*"]
  }

  statement {
    sid       = "NetworkForWorkgroup"
    resources = ["*"]

    actions = [
      "ec2:Describe*",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:ModifySecurityGroupRules",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:CreateVpcEndpoint",
      "ec2:ModifyVpcEndpoint",
      "ec2:DeleteVpcEndpoints",
    ]
  }

  statement {
    sid       = "RedshiftManagedAdminSecret"
    resources = ["arn:aws:secretsmanager:*:${local.account_id}:secret:redshift!*"]

    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:RotateSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:UpdateSecret",
    ]
  }

  statement {
    sid       = "GeneratePasswords"
    actions   = ["secretsmanager:GetRandomPassword"]
    resources = ["*"]
  }

  statement {
    sid       = "RedshiftServiceLinkedRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["redshift.amazonaws.com", "redshift-serverless.amazonaws.com"]
    }
  }
}

resource "aws_iam_user_policy" "ci_deploy" {
  name   = "redshift-lab-deploy"
  user   = data.aws_iam_user.ci.user_name
  policy = data.aws_iam_policy_document.deploy.json
}
