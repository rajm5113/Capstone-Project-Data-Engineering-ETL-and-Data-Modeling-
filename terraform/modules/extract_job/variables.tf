variable "project" {
  type        = string
  description = "Project name prefix."
}

variable "region" {
  type        = string
  description = "AWS region."
}

variable "public_subnet_a_id" {
  type        = string
  description = "Subnet ID used by the Glue JDBC connection."
}

variable "db_sg_id" {
  type        = string
  description = "RDS security group ID."
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
  description = "PostgreSQL database name."
}

variable "username" {
  type        = string
  description = "PostgreSQL username."
}

variable "password" {
  type        = string
  description = "PostgreSQL password."
  sensitive   = true
}

variable "api_endpoint" {
  type        = string
  description = "DeFtunes API base URL without the endpoint path."
}

variable "data_lake_bucket" {
  type        = string
  description = "Amazon S3 data lake bucket."
}

variable "scripts_bucket" {
  type        = string
  description = "S3 bucket containing Glue scripts."
}
