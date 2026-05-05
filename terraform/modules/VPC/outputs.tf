output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_app_subnet_ids" {
  description = "List of private app subnet IDs (for EKS)"
  value       = module.vpc.private_subnets
}

output "private_db_subnet_ids" {
  description = "List of private DB subnet IDs (for RDS/Redis)"
  value       = module.vpc.database_subnets
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = module.vpc.natgw_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "database_subnet_group_name" {
  description = "Name of the RDS subnet group"
  value       = module.vpc.database_subnet_group_name
}
