output "db_endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = module.db.db_instance_endpoint
  sensitive   = true
}

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = module.db.db_instance_identifier
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret storing DB credentials"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds_sg.id
}
