variable "project" {
  type        = string
  description = "Project name"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "catalog_database" {
  type        = string
  description = "AWS Glue Data Catalog database containing the curated tables."
}
