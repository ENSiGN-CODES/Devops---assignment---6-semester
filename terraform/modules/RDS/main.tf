# =============================================================
# MODULE: RDS PostgreSQL
# Source: terraform-aws-modules/rds/aws (Terraform Registry)
# Registry: https://registry.terraform.io/modules/terraform-aws-modules/rds/aws
#
# What this creates:
#   - RDS PostgreSQL instance in private DB subnets
#   - Multi-AZ for high availability (automatic failover)
#   - Security group allowing only EKS nodes to connect
#   - Automated backups and maintenance windows
#   - DB password stored in AWS Secrets Manager (not hardcoded)
# =============================================================

# Security group: only EKS worker nodes can reach RDS on port 5432
resource "aws_security_group" "rds_sg" {
  name        = "${var.db_identifier}-sg"
  description = "Security group for RDS PostgreSQL - allows EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS worker nodes"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.db_identifier}-sg" })
}

# DB password stored in AWS Secrets Manager - never hardcoded
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.db_identifier}-password"
  description             = "Master password for RDS PostgreSQL"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    endpoint = module.db.db_instance_endpoint
    dbname   = var.db_name
    port     = var.db_port
  })
}

# Random secure password - never visible in tfvars or state in plain text
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.6.0"

  identifier = var.db_identifier

  engine               = var.db_engine
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage  # Auto-scaling storage

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = var.db_port

  # Multi-AZ = automatic failover if primary AZ goes down
  multi_az = var.db_multi_az

  # Place RDS in private DB subnets
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Backup configuration
  backup_retention_period = var.db_backup_retention_period
  backup_window           = var.db_backup_window
  maintenance_window      = var.db_maintenance_window

  # Protect against accidental deletion
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot

  # Encryption at rest
  storage_encrypted = true

  # Performance Insights for monitoring
  performance_insights_enabled = true

  # Enhanced monitoring
  monitoring_interval    = 60
  monitoring_role_name   = "${var.db_identifier}-monitoring-role"
  create_monitoring_role = true

  # Enable logging to CloudWatch
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Parameter group
  family = "postgres14"

  tags = var.tags
}
