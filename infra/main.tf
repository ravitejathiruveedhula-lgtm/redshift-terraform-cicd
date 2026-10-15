locals {
  name = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Network: reuse the default VPC. Redshift Serverless needs subnets in at
# least three Availability Zones, and the default VPC has one per AZ.
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

resource "aws_security_group" "redshift" {
  name        = "${local.name}-redshift"
  description = "Redshift Serverless workgroup. No inbound rules - SQL runs through the Redshift Data API."
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.redshift.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# Redshift Serverless: the namespace holds storage, users and databases; the
# workgroup is the compute. You pay for compute only while queries run.
# ---------------------------------------------------------------------------
resource "aws_redshiftserverless_namespace" "this" {
  namespace_name        = "${local.name}-ns"
  db_name               = var.database_name
  admin_username        = "labadmin"
  manage_admin_password = true # Redshift generates the password and keeps it in Secrets Manager
}

resource "aws_redshiftserverless_workgroup" "this" {
  namespace_name      = aws_redshiftserverless_namespace.this.namespace_name
  workgroup_name      = "${local.name}-wg"
  base_capacity       = var.base_capacity_rpu
  publicly_accessible = false
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.redshift.id]

  lifecycle {
    precondition {
      condition     = length(data.aws_subnets.default.ids) >= 3
      error_message = "Redshift Serverless needs default subnets in at least three Availability Zones. Check the default VPC in this region."
    }
  }
}

# Cost guardrail: if a day's usage passes the limit, the workgroup is switched
# off until the next day instead of running up a bill.
resource "aws_redshiftserverless_usage_limit" "daily_compute" {
  resource_arn  = aws_redshiftserverless_workgroup.this.arn
  usage_type    = "serverless-compute"
  amount        = var.daily_rpu_hour_limit
  period        = "daily"
  breach_action = "deactivate"
}
