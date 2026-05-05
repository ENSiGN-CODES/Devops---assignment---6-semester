# =============================================================
# MODULE: Redis (ElastiCache)
# Source: terraform-aws-modules/elasticache/aws (Terraform Registry)
# Registry: https://registry.terraform.io/modules/terraform-aws-modules/elasticache/aws
#
# What this creates:
#   - ElastiCache Redis cluster in private DB subnets
#   - Security group allowing only EKS nodes to connect
#   - Automatic failover enabled for HA
#   - Encryption in transit and at rest
# =============================================================

resource "aws_security_group" "redis_sg" {
  name        = "${var.redis_cluster_id}-sg"
  description = "Security group for ElastiCache Redis - EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from EKS worker nodes"
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.redis_cluster_id}-sg" })
}

module "elasticache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "1.2.2"

  cluster_id = var.redis_cluster_id

  # Use replication group for HA (not single cluster)
  create_cluster           = false
  create_replication_group = true

  engine_version = var.redis_engine_version
  node_type      = var.redis_node_type

  # 2 nodes: 1 primary + 1 replica for automatic failover
  num_cache_clusters         = var.redis_num_cache_nodes
  automatic_failover_enabled = true

  maintenance_window      = var.redis_maintenance_window
  snapshot_retention_limit = var.redis_snapshot_retention

  # Encryption
  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = true

  # Place in private DB subnets
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  security_group_rules = {
    ingress_eks = {
      description              = "EKS nodes access to Redis"
      type                     = "ingress"
      from_port                = var.redis_port
      to_port                  = var.redis_port
      protocol                 = "tcp"
      source_security_group_id = var.eks_security_group_id
    }
  }

  # Parameter Group
  create_parameter_group = true
  parameter_group_family = var.redis_family

  tags = var.tags
}
