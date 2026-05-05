# =============================================================
# ROOT MAIN.TF
# This file wires all modules together.
# ALL values come from terraform.tfvars - nothing is hardcoded.
# =============================================================

# ------- VPC MODULE -------
module "vpc" {
  source = "./modules/vpc"

  vpc_name                  = var.vpc_name
  vpc_cidr                  = var.vpc_cidr
  availability_zone_1       = var.availability_zone_1
  availability_zone_2       = var.availability_zone_2
  public_subnet_1_cidr      = var.public_subnet_1_cidr
  public_subnet_2_cidr      = var.public_subnet_2_cidr
  private_app_subnet_1_cidr = var.private_app_subnet_1_cidr
  private_app_subnet_2_cidr = var.private_app_subnet_2_cidr
  private_db_subnet_1_cidr  = var.private_db_subnet_1_cidr
  private_db_subnet_2_cidr  = var.private_db_subnet_2_cidr
  tags                      = var.tags
}

# ------- EKS MODULE -------
module "eks" {
  source = "./modules/eks"

  # Depends on VPC - EKS nodes go in private app subnets
  eks_cluster_name       = var.eks_cluster_name
  eks_cluster_version    = var.eks_cluster_version
  eks_node_instance_type = var.eks_node_instance_type
  eks_node_min_size      = var.eks_node_min_size
  eks_node_max_size      = var.eks_node_max_size
  eks_node_desired_size  = var.eks_node_desired_size
  eks_node_group_name    = var.eks_node_group_name
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_app_subnet_ids
  tags                   = var.tags
}

# ------- RDS MODULE -------
module "rds" {
  source = "./modules/rds"

  # Depends on VPC - RDS goes in private DB subnets
  db_identifier              = var.db_identifier
  db_engine                  = var.db_engine
  db_engine_version          = var.db_engine_version
  db_instance_class          = var.db_instance_class
  db_name                    = var.db_name
  db_username                = var.db_username
  db_port                    = var.db_port
  db_allocated_storage       = var.db_allocated_storage
  db_max_allocated_storage   = var.db_max_allocated_storage
  db_multi_az                = var.db_multi_az
  db_deletion_protection     = var.db_deletion_protection
  db_backup_retention_period = var.db_backup_retention_period
  db_backup_window           = var.db_backup_window
  db_maintenance_window      = var.db_maintenance_window
  db_skip_final_snapshot     = var.db_skip_final_snapshot
  db_subnet_group_name       = var.db_subnet_group_name
  vpc_id                     = module.vpc.vpc_id
  db_subnet_ids              = module.vpc.private_db_subnet_ids
  eks_security_group_id      = module.eks.node_security_group_id
  tags                       = var.tags
}

# ------- REDIS MODULE -------
module "redis" {
  source = "./modules/redis"

  # Depends on VPC - Redis goes in private DB subnets
  redis_cluster_id         = var.redis_cluster_id
  redis_node_type          = var.redis_node_type
  redis_engine_version     = var.redis_engine_version
  redis_num_cache_nodes    = var.redis_num_cache_nodes
  redis_port               = var.redis_port
  redis_maintenance_window = var.redis_maintenance_window
  redis_snapshot_retention = var.redis_snapshot_retention
  redis_family             = var.redis_family
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_db_subnet_ids
  eks_security_group_id    = module.eks.node_security_group_id
  tags                     = var.tags
}
