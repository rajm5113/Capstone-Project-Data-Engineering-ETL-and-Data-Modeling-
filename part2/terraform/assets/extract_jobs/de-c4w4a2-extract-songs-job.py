import sys
from datetime import datetime

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext

args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "rds_connection",
        "data_lake_bucket",
        "ingest_date",
    ],
)

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

rds_connection = args["rds_connection"]
data_lake_bucket = args["data_lake_bucket"]
ingest_date = datetime.strptime(args["ingest_date"], "%Y-%m-%d")
partition_date = ingest_date.strftime("%Y_%m_%d")

source_frame = glue_context.create_dynamic_frame.from_options(
    connection_type="postgresql",
    connection_options={
        "useConnectionProperties": "true",
        "dbtable": "deftunes.songs",
        "connectionName": rds_connection,
    },
    transformation_ctx="source_node",
)

s3_path = (
    f"s3://{data_lake_bucket}/landing_zone/db_songs/"
    f"ingest_on={partition_date}/"
)

# The job reads a full source snapshot for this logical date. Clear only this
# date's landing prefix before writing so retries do not append stale CSV files.
glue_context.purge_s3_path(s3_path, options={"retentionPeriod": 0})

glue_context.write_dynamic_frame.from_options(
    frame=source_frame,
    connection_type="s3",
    format="csv",
    connection_options={"path": s3_path, "partitionKeys": []},
    transformation_ctx="target_node",
)

job.commit()
