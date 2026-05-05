output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.elasticache.replication_group_primary_endpoint_address
  sensitive   = true
}

output "redis_port" {
  description = "Redis port"
  value       = var.redis_port
}

output "redis_security_group_id" {
  description = "Security group ID for Redis"
  value       = aws_security_group.redis_sg.id
}
