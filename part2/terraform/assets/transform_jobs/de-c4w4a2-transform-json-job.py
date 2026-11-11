import sys
from datetime import datetime

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.conf import SparkConf
from pyspark.context import SparkContext
from pyspark.sql.functions import col, explode, lit, to_date, to_timestamp

args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "catalog_database",
        "ingest_date",
        "users_source_path",
        "sessions_source_path",
        "target_bucket_path",
        "users_table",
        "sessions_table",
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
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")

ingest_date_str = args["ingest_date"]
ingest_date = datetime.strptime(ingest_date_str, "%Y-%m-%d")
partition_date = ingest_date.strftime("%Y_%m_%d")

users_path = (
    f"{args['users_source_path'].rstrip('/')}/ingest_on={partition_date}"
)
sessions_path = (
    f"{args['sessions_source_path'].rstrip('/')}/ingest_on={partition_date}"
)

users_df = spark.read.json(users_path)
sessions_df = spark.read.json(sessions_path)

users_df = users_df.withColumn(
    "ingest_on", to_date(lit(ingest_date_str), "yyyy-MM-dd")
)
users_df = (
    users_df.withColumn("latitude", col("user_location")[0])
    .withColumn("longitude", col("user_location")[1])
    .withColumn("place_name", col("user_location")[2])
    .withColumn("country_code", col("user_location")[3])
    .withColumn("timezone", col("user_location")[4])
    .drop("user_location")
)

processing_timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
users_df = users_df.withColumn(
    "processing_timestamp", lit(processing_timestamp)
)

sessions_df = sessions_df.withColumn(
    "ingest_on", to_date(lit(ingest_date_str), "yyyy-MM-dd")
).withColumn(
    "processing_timestamp", lit(processing_timestamp)
).withColumn(
    "session_ts", to_timestamp(col("session_start_time"))
)

sessions_df = sessions_df.withColumn(
    "session_item", explode("session_items")
).select(
    col("user_id"),
    col("session_id"),
    col("session_item.song_id").alias("song_id"),
    col("session_item.song_name").alias("song_name"),
    col("session_item.artist_id").alias("artist_id"),
    col("session_item.artist_name").alias("artist_name"),
    col("session_item.price").alias("price"),
    col("session_item.currency").alias("currency"),
    col("session_item.liked").alias("liked"),
    col("session_item.liked_since").alias("liked_since"),
    col("user_agent"),
    col("session_ts").alias("session_start_time"),
    col("ingest_on"),
    col("processing_timestamp"),
)

catalog_database = args["catalog_database"]
users_table = args["users_table"]
sessions_table = args["sessions_table"]

existing_tables = {
    table.name for table in spark.catalog.listTables(catalog_database)
}

def write_iceberg_table(dataframe, table_name):
    target = f"glue_catalog.{catalog_database}.{table_name}"
    writer = (
        dataframe.writeTo(target)
        .tableProperty("format-version", "2")
        .partitionedBy("ingest_on")
    )
    if table_name in existing_tables:
        writer.append()
    else:
        writer.createOrReplace()

write_iceberg_table(users_df, users_table)
write_iceberg_table(sessions_df, sessions_table)

job.commit()
