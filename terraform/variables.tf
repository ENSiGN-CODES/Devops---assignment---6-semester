#----------------------General------------------------#
variable "aws_region" {
  description = "Primary AWS region"
  type        = string
}

variable "secondary_region" {
  description = "Secondary AWS region for disaster recovery / failover"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment: dev, staging, or prod"
  type        = string
}

#----------------------VPC---------------------------#
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "public_subnet_1_cidr" {
  description = "CIDR for first public subnet (AZ1)"
  type        = string
}

variable "public_subnet_2_cidr" {
  description = "CIDR for second public subnet (AZ2)"
  type        = string
}

variable "private_app_subnet_1_cidr" {
  description = "CIDR for first private app subnet (AZ1) - EKS nodes"
  type        = string
}

variable "private_app_subnet_2_cidr" {
  description = "CIDR for second private app subnet (AZ2) - EKS nodes"
  type        = string
}

variable "private_db_subnet_1_cidr" {
  description = "CIDR for first private DB subnet (AZ1) - RDS/Redis"
  type        = string
}

variable "private_db_subnet_2_cidr" {
  description = "CIDR for second private DB subnet (AZ2) - RDS/Redis"
  type        = string
}

variable "availability_zone_1" {
  description = "First availability zone"
  type        = string
}

variable "availability_zone_2" {
  description = "Second availability zone"
  type        = string
}

#----------------------EKS---------------------------#
variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS nodes (for auto-scaling)"
  type        = number
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
}

variable "eks_node_group_name" {
  description = "Name of the EKS managed node group"
  type        = string
}

#----------------------RDS---------------------------#
variable "db_identifier" {
  description = "Unique identifier for the RDS instance"
  type        = string
}

variable "db_engine" {
  description = "Database engine (postgres)"
  type        = string
}

variable "db_engine_version" {
  description = "PostgreSQL version"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
}

variable "db_username" {
  description = "Master DB username"
  type        = string
}

variable "db_port" {
  description = "Port for PostgreSQL"
  type        = number
}

variable "db_allocated_storage" {
  description = "Initial storage in GB"
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Max storage for auto-scaling in GB"
  type        = number
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
}

variable "db_deletion_protection" {
  description = "Prevent accidental deletion of DB"
  type        = bool
}

variable "db_backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
}

variable "db_backup_window" {
  description = "Preferred backup window"
  type        = string
}

variable "db_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  type        = string
}

#----------------------Redis---------------------------#
variable "redis_cluster_id" {
  description = "ID for the ElastiCache Redis cluster"
  type        = string
}

variable "redis_node_type" {
  description = "Node type for ElastiCache Redis"
  type        = string
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
}

variable "redis_num_cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
}

variable "redis_port" {
  description = "Redis port"
  type        = number
}

variable "redis_maintenance_window" {
  description = "Redis maintenance window"
  type        = string
}

variable "redis_snapshot_retention" {
  description = "Days to retain Redis snapshots"
  type        = number
}

variable "redis_family" {
  description = "Redis parameter group family"
  type        = string
}

#----------------------ALB---------------------------#
variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "alb_internal" {
  description = "True = internal ALB, False = internet-facing"
  type        = bool
}

variable "target_group_name" {
  description = "Name of the ALB target group"
  type        = string
}

variable "target_group_port" {
  description = "Port for target group"
  type        = number
}

variable "target_group_protocol" {
  description = "Protocol for target group"
  type        = string
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
}

#----------------------Tags---------------------------#
variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
}
