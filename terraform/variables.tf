variable "project" {
  type        = string
  description = "Project name prefix used for AWS resource names."
}

variable "region" {
  type        = string
  description = "AWS region."
}

variable "vpc_id" {
  type        = string
  description = "VPC containing the DeFtunes source database."
}

variable "public_subnet_a_id" {
  type        = string
  description = "Subnet used by the Glue JDBC connection in the lab environment."
}

variable "db_sg_id" {
  type        = string
  description = "Security group associated with the RDS database."
}

variable "source_host" {
  type        = string
  description = "PostgreSQL RDS endpoint hostname."
}

variable "source_port" {
  type        = number
  description = "PostgreSQL RDS port."
  default     = 5432
}

variable "source_database" {
  type        = string
  description = "Source PostgreSQL database name."
}

variable "source_username" {
  type        = string
  description = "Source PostgreSQL username."
}

variable "source_password" {
  type        = string
  description = "Source PostgreSQL password."
  sensitive   = true
}

variable "api_endpoint" {
  type        = string
  description = "DeFtunes API base URL including http:// or https://, without /users or /sessions."
}

variable "data_lake_bucket" {
  type        = string
  description = "Amazon S3 data lake bucket name."
}

variable "scripts_bucket" {
  type        = string
  description = "Amazon S3 bucket containing AWS Glue scripts."
}

variable "catalog_database" {
  type        = string
  description = "AWS Glue Data Catalog database name."
}

variable "users_table" {
  type        = string
  description = "Glue Catalog table name for users."
}

variable "sessions_table" {
  type        = string
  description = "Glue Catalog table name for sessions."
}

variable "songs_table" {
  type        = string
  description = "Glue Catalog table name for songs."
}

variable "redshift_role_name" {
  type        = string
  description = "IAM role name granted to Redshift Spectrum."
}

variable "redshift_host" {
  type        = string
  description = "Amazon Redshift cluster endpoint hostname."
}

variable "redshift_user" {
  type        = string
  description = "Amazon Redshift username."
}

variable "redshift_password" {
  type        = string
  description = "Amazon Redshift password."
  sensitive   = true
}

variable "redshift_database" {
  type        = string
  description = "Amazon Redshift database name."
}

variable "redshift_port" {
  type        = number
  description = "Amazon Redshift port."
}
