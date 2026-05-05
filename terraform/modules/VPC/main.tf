# =============================================================
# MODULE: VPC
# Source: terraform-aws-modules/vpc/aws (Terraform Registry)
# Registry: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws
#
# Architecture:
#   - 2 Public subnets  (ALB, NAT Gateway)
#   - 2 Private App subnets (EKS worker nodes)
#   - 2 Private DB subnets  (RDS PostgreSQL, Redis)
#   - NAT Gateway in each AZ for HA egress from private subnets
# =============================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = var.vpc_name
  cidr = var.vpc_cidr

  # Spread across 2 AZs for high availability
  azs = [var.availability_zone_1, var.availability_zone_2]

  # Public subnets: ALB lives here, internet-facing
  public_subnets = [
    var.public_subnet_1_cidr,
    var.public_subnet_2_cidr
  ]

  # Private app subnets: EKS worker nodes (no direct internet access)
  private_subnets = [
    var.private_app_subnet_1_cidr,
    var.private_app_subnet_2_cidr
  ]

  # Private DB subnets: RDS + Redis (most restricted tier)
  database_subnets = [
    var.private_db_subnet_1_cidr,
    var.private_db_subnet_2_cidr
  ]

  # Internet Gateway for public subnets
  create_igw = true

  # NAT Gateway in each AZ - allows private subnet egress
  # One per AZ for high availability (costs more but avoids single point of failure)
  enable_nat_gateway     = true
  single_nat_gateway     = false  # false = one NAT per AZ (HA)
  one_nat_gateway_per_az = true

  # DNS support required for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # DB subnet group - required for RDS
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # Tags for EKS subnet discovery
  # EKS needs these tags to know which subnets to use for load balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }

  tags = var.tags
}

variable "eks_cluster_name" {
  description = "EKS cluster name - needed for subnet tagging"
  type        = string
  default     = "fintech-eks-cluster"
}
