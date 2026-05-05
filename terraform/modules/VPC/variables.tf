variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zone_1" {
  description = "First AZ"
  type        = string
}

variable "availability_zone_2" {
  description = "Second AZ"
  type        = string
}

variable "public_subnet_1_cidr" {
  description = "CIDR for first public subnet"
  type        = string
}

variable "public_subnet_2_cidr" {
  description = "CIDR for second public subnet"
  type        = string
}

variable "private_app_subnet_1_cidr" {
  description = "CIDR for first private app subnet (EKS)"
  type        = string
}

variable "private_app_subnet_2_cidr" {
  description = "CIDR for second private app subnet (EKS)"
  type        = string
}

variable "private_db_subnet_1_cidr" {
  description = "CIDR for first private DB subnet (RDS/Redis)"
  type        = string
}

variable "private_db_subnet_2_cidr" {
  description = "CIDR for second private DB subnet (RDS/Redis)"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}
