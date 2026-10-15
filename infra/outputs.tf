output "workgroup_name" {
  description = "Redshift Serverless workgroup name, used by the Data API."
  value       = aws_redshiftserverless_workgroup.this.workgroup_name
}

output "database_name" {
  description = "Database created in the namespace."
  value       = aws_redshiftserverless_namespace.this.db_name
}

output "admin_secret_arn" {
  description = "Secrets Manager ARN that holds the generated admin credentials."
  value       = aws_redshiftserverless_namespace.this.admin_password_secret_arn
}

output "endpoint_address" {
  description = "Private endpoint address of the workgroup."
  value       = aws_redshiftserverless_workgroup.this.endpoint[0].address
}
