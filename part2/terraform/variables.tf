variable "project" {
  type        = string
  description = "Project prefix used to name AWS resources."
  default     = "de-c4w4a2"
}

variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "private_subnet_a_id" {
  type        = string
  description = "Private subnet ID used by the AWS Glue RDS connection."
}

variable "db_sg_id" {
  type        = string
  description = "Security group ID that permits Glue to reach the RDS instance."
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
  default     = "postgres"
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

variable "data_lake_bucket" {
  type        = string
  description = "S3 data lake bucket name."
}

variable "scripts_bucket" {
  type        = string
  description = "S3 bucket containing AWS Glue scripts."
}

variable "catalog_database" {
  type        = string
  description = "AWS Glue Data Catalog database name."
}

variable "users_table" {
  type        = string
  description = "Glue Catalog users table name."
  default     = "users"
}

variable "sessions_table" {
  type        = string
  description = "Glue Catalog sessions table name."
  default     = "sessions"
}

variable "songs_table" {
  type        = string
  description = "Glue Catalog songs table name."
  default     = "songs"
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
  default     = "dev"
}

variable "redshift_port" {
  type        = number
  description = "Amazon Redshift port."
  default     = 5439
}

variable "api_endpoint" {
  type        = string
  description = "Base URL for the DeFtunes API, including scheme but without /users or /sessions."
}
