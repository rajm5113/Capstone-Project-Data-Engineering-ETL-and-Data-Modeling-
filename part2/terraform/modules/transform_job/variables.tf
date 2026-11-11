variable "project" {
  type        = string
  description = "Project resource-name prefix."
}

variable "region" {
  type        = string
  description = "AWS region."
}

variable "glue_role_arn" {
  type        = string
  description = "IAM role ARN used by Glue jobs."
}

variable "scripts_bucket" {
  type        = string
  description = "S3 bucket containing Glue scripts."
}

variable "data_lake_bucket" {
  type        = string
  description = "S3 data lake bucket."
}

variable "catalog_database" {
  type        = string
  description = "Glue Data Catalog database."
}

variable "users_table" {
  type        = string
  description = "Users table name."
}

variable "sessions_table" {
  type        = string
  description = "Sessions table name."
}

variable "songs_table" {
  type        = string
  description = "Songs table name."
}
