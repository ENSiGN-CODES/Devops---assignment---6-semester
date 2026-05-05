output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded CA certificate for cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group ID for EKS control plane"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider - used for IAM roles for service accounts"
  value       = module.eks.oidc_provider_arn
}
