variable "db_identifier" {
  type = string
}
variable "db_engine" {
  type = string
}
variable "db_engine_version" {
  type = string
}
variable "db_instance_class" {
  type = string
}
variable "db_name" {
  type = string
}
variable "db_username" {
  type = string
}
variable "db_port" {
  type = number
}
variable "db_allocated_storage" {
  type = number
}
variable "db_max_allocated_storage" {
  type = number
}
variable "db_multi_az" {
  type = bool
}
variable "db_deletion_protection" {
  type = bool
}
variable "db_backup_retention_period" {
  type = number
}
variable "db_backup_window" {
  type = string
}
variable "db_maintenance_window" {
  type = string
}
variable "db_skip_final_snapshot" {
  type = bool
}
variable "db_subnet_group_name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "db_subnet_ids" {
  type = list(string)
}
variable "eks_security_group_id" {
  type = string
}
variable "tags" {
  type = map(string)
}
