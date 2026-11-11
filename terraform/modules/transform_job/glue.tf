
# ============================================================
# 1. AWS GLUE CATALOG DATABASE
# ============================================================

resource "aws_glue_catalog_database" "transform_db" {
  name        = var.catalog_database
  description = "Glue Catalog database for transformations"
}


# ============================================================
# 2. JSON TRANSFORMATION GLUE JOB
# ============================================================

resource "aws_glue_job" "json_transformation_job" {
  name         = "${var.project}-json-transform-job"
  role_arn     = var.glue_role_arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket}/de-c4w4a1-transform-json-job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-job-insights"     = "true"
    "--job-language"            = "python"

    # Glue Catalog database
    "--catalog_database"        = aws_glue_catalog_database.transform_db.name

    # Source paths
    "--users_source_path"       = "s3://${var.data_lake_bucket}/landing_zone/api/users/"
    "--sessions_source_path"    = "s3://${var.data_lake_bucket}/landing_zone/api/sessions/"

    # Target bucket
    "--target_bucket_path"      = "${var.data_lake_bucket}"

    # Table names
    "--users_table"             = var.users_table
    "--sessions_table"          = var.sessions_table

    # Apache Iceberg configuration
    "--datalake-formats"        = "iceberg"
    "--enable-glue-datacatalog" = "true"
  }

  timeout = 5

  number_of_workers = 2
  worker_type       = "G.1X"
}


# ============================================================
# 3. SONGS TRANSFORMATION GLUE JOB
# ============================================================

resource "aws_glue_job" "songs_transformation_job" {
  name         = "${var.project}-songs-transform-job"
  role_arn     = var.glue_role_arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket}/de-c4w4a1-transform-songs-job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-job-insights"     = "true"
    "--job-language"            = "python"

    # Glue Catalog database
    "--catalog_database"        = aws_glue_catalog_database.transform_db.name

    # Source and target buckets
    "--source_bucket_path"      = "${var.data_lake_bucket}"
    "--target_bucket_path"      = "${var.data_lake_bucket}"

    # Songs table
    "--songs_table"             = var.songs_table

    # Apache Iceberg configuration
    "--datalake-formats"        = "iceberg"
    "--enable-glue-datacatalog" = "true"
  }

  timeout = 5

  number_of_workers = 2
  worker_type       = "G.1X"
}
