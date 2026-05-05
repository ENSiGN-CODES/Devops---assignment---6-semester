# =============================================================
# MODULE: EKS
# Source: terraform-aws-modules/eks/aws (Terraform Registry)
# Registry: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws
#
# What this creates:
#   - EKS Control Plane (managed by AWS)
#   - Managed Node Group in private app subnets
#   - IAM roles for cluster and nodes
#   - Security groups for cluster communication
# =============================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  # Control plane lives in private subnets
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Allow kubectl access from inside VPC (not public internet)
  cluster_endpoint_public_access  = true   # Set false in full production
  cluster_endpoint_private_access = true

  # Automatically grant cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # EKS Add-ons: core Kubernetes components
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    # EBS CSI driver - needed for persistent volumes (PostgreSQL backups, etc.)
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Managed Node Group - EKS manages the EC2 instances
  eks_managed_node_groups = {
    fintech_nodes = {
      name = var.eks_node_group_name

      # Instance type from tfvars - t3.medium for cost/performance balance
      instance_types = [var.eks_node_instance_type]

      # Auto-scaling configuration
      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      # Nodes go in private subnets - not directly reachable from internet
      subnet_ids = var.private_subnet_ids

      # Use latest Amazon Linux 2 EKS-optimized AMI
      ami_type = "AL2_x86_64"

      # Root volume config
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      labels = {
        role = "application"
      }

      tags = var.tags
    }
  }

  tags = var.tags
}
