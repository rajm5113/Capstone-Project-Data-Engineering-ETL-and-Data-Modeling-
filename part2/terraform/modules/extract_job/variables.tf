variable "project" {
  type        = string
  description = "Project resource-name prefix."
}

variable "region" {
  type        = string
  description = "AWS region."
}

variable "private_subnet_a_id" {
  type        = string
  description = "Private subnet ID used for the Glue-to-RDS connection."
}

variable "db_sg_id" {
  type        = string
  description = "Security group ID for RDS connectivity."
}

variable "host" {
  type        = string
  description = "PostgreSQL RDS hostname."
}

variable "port" {
  type        = number
  description = "PostgreSQL port."
  default     = 5432
}

variable "database" {
  type        = string
  description = "Source database name."
}

variable "username" {
  type        = string
  description = "Source database username."
}

variable "password" {
  type        = string
  description = "Source database password."
  sensitive   = true
}

variable "data_lake_bucket" {
  type        = string
  description = "S3 data lake bucket."
}

variable "scripts_bucket" {
  type        = string
  description = "S3 bucket containing Glue scripts."
}

variable "api_endpoint" {
  type        = string
  description = "Base URL of the DeFtunes API."
}
