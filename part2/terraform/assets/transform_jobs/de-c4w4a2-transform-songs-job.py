import sys
from datetime import datetime

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.conf import SparkConf
from pyspark.context import SparkContext
from pyspark.sql import functions as F

args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "catalog_database",
        "ingest_date",
        "source_bucket_path",
        "target_bucket_path",
        "songs_table",
    ],
)

conf = SparkConf()
conf.set(
    "spark.sql.extensions",
    "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
)
conf.set("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog")
conf.set(
    "spark.sql.catalog.glue_catalog.warehouse",
    f"s3://{args['target_bucket_path']}/transform_zone",
)
conf.set(
    "spark.sql.catalog.glue_catalog.catalog-impl",
    "org.apache.iceberg.aws.glue.GlueCatalog",
)
conf.set(
    "spark.sql.catalog.glue_catalog.io-impl",
    "org.apache.iceberg.aws.s3.S3FileIO",
)

sc = SparkContext(conf=conf)
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

ingest_date = datetime.strptime(args["ingest_date"], "%Y-%m-%d")
partition_date = ingest_date.strftime("%Y_%m_%d")
source_path = (
    f"s3://{args['source_bucket_path']}/landing_zone/db_songs/"
    f"ingest_on={partition_date}/"
)

songs_frame = glue_context.create_dynamic_frame.from_options(
    format_options={
        "quoteChar": '"',
        "withHeader": True,
        "separator": ",",
        "optimizePerformance": False,
    },
    connection_type="s3",
    format="csv",
    connection_options={"paths": [source_path], "recurse": True},
    transformation_ctx="landing_node",
)

songs_df = songs_frame.toDF()
for column_name in ("duration", "artist_familiarity", "artist_hotttnesss"):
    songs_df = songs_df.withColumn(column_name, F.col(column_name).cast("float"))
for column_name in ("year", "track_7digitalid", "shs_perf", "shs_work"):
    songs_df = songs_df.withColumn(column_name, F.col(column_name).cast("int"))

songs_df = (
    songs_df.withColumn(
        "ingest_on",
        F.to_date(F.lit(args["ingest_date"]), "yyyy-MM-dd"),
    )
    .withColumn("source_from", F.lit("postgres_rds"))
)

catalog_database = args["catalog_database"]
songs_table = args["songs_table"]
target = f"glue_catalog.{catalog_database}.{songs_table}"
existing_tables = {
    table.name for table in spark.catalog.listTables(catalog_database)
}

if songs_table in existing_tables:
    # Overwrite only this logical date partition on retries/re-runs.
    songs_df.writeTo(target).overwritePartitions()
else:
    (
        songs_df.writeTo(target)
        .tableProperty("format-version", "2")
        .partitionedBy("ingest_on")
        .createOrReplace()
    )

job.commit()
