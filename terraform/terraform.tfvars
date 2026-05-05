#----------------------General------------------------#
aws_region        = "ap-south-1"          # Primary region (Mumbai - closest to India)
secondary_region  = "ap-southeast-1"      # Secondary region for failover (Singapore)
project_name      = "fintech-app"
environment       = "prod"

#----------------------VPC---------------------------#
vpc_cidr                    = "10.0.0.0/16"
vpc_name                    = "fintech-vpc"
public_subnet_1_cidr        = "10.0.1.0/24"
public_subnet_2_cidr        = "10.0.2.0/24"
private_app_subnet_1_cidr   = "10.0.3.0/24"
private_app_subnet_2_cidr   = "10.0.4.0/24"
private_db_subnet_1_cidr    = "10.0.5.0/24"
private_db_subnet_2_cidr    = "10.0.6.0/24"
availability_zone_1         = "ap-south-1a"
availability_zone_2         = "ap-south-1b"

#----------------------EKS---------------------------#
eks_cluster_name         = "fintech-eks-cluster"
eks_cluster_version      = "1.27"
eks_node_instance_type   = "t3.medium"
eks_node_min_size        = 2
eks_node_max_size        = 6
eks_node_desired_size    = 3
eks_node_group_name      = "fintech-node-group"

#----------------------RDS---------------------------#
db_identifier          = "fintech-postgres"
db_engine              = "postgres"
db_engine_version      = "14"
db_instance_class      = "db.t3.medium"
db_name                = "fintechdb"
db_username            = "fintechadmin"
db_port                = 5432
db_allocated_storage   = 20
db_max_allocated_storage = 100
db_multi_az            = true
db_deletion_protection = true
db_backup_retention_period = 7
db_backup_window       = "03:00-04:00"
db_maintenance_window  = "Mon:04:00-Mon:05:00"
db_skip_final_snapshot = false
db_subnet_group_name   = "fintech-db-subnet-group"

#----------------------Redis/ElastiCache--------------#
redis_cluster_id         = "fintech-redis"
redis_node_type          = "cache.t3.micro"
redis_engine_version     = "7.1"
redis_num_cache_nodes    = 2
redis_port               = 6379
redis_maintenance_window = "sun:05:00-sun:06:00"
redis_snapshot_retention = 7
redis_family             = "redis7"

#----------------------ALB---------------------------#
alb_name             = "fintech-alb"
alb_internal         = false
target_group_name    = "fintech-tg"
target_group_port    = 80
target_group_protocol = "HTTP"
health_check_path    = "/health"

#----------------------Tags--------------------------#
tags = {
  Project     = "fintech-app"
  Environment = "prod"
  ManagedBy   = "Terraform"
  Owner       = "DevOps-Team"
}
