variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "eks_cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
}

variable "eks_node_min_size" {
  description = "Minimum node count"
  type        = number
}

variable "eks_node_max_size" {
  description = "Maximum node count (auto-scaling ceiling)"
  type        = number
}

variable "eks_node_desired_size" {
  description = "Desired node count"
  type        = number
}

variable "eks_node_group_name" {
  description = "Name of the managed node group"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from VPC module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}
