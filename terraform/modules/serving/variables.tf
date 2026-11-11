variable "project" {
  type        = string
  description = "Project name."
}

variable "region" {
  type        = string
  description = "AWS region."
}

variable "redshift_role_name" {
  type        = string
  description = "IAM role name for Redshift Spectrum."
}

variable "catalog_database" {
  type        = string
  description = "Glue Data Catalog database name."
}

variable "redshift_host" {
  type        = string
  description = "Redshift endpoint hostname."
}

variable "redshift_user" {
  type        = string
  description = "Redshift username."
}

variable "redshift_password" {
  type        = string
  description = "Redshift password."
  sensitive   = true
}

variable "redshift_database" {
  type        = string
  description = "Redshift database name."
}

variable "redshift_port" {
  type        = number
  description = "Redshift port."
}
