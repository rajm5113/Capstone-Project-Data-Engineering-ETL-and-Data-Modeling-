import sys
from datetime import date

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext

args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "rds_connection", "data_lake_bucket"],
)

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

ingest_day = date.today()
partition_date = ingest_day.strftime("%Y_%m_%d")
output_path = (
    f"s3://{args['data_lake_bucket']}/landing_zone/db_songs/"
    f"ingest_on={partition_date}"
)

source_frame = glue_context.create_dynamic_frame.from_options(
    connection_type="postgresql",
    connection_options={
        "useConnectionProperties": "true",
        "dbtable": "deftunes.songs",
        "connectionName": args["rds_connection"],
    },
    transformation_ctx="source_node",
)

glue_context.write_dynamic_frame.from_options(
    frame=source_frame,
    connection_type="s3",
    format="csv",
    connection_options={"path": output_path, "partitionKeys": []},
    transformation_ctx="target_node",
)

job.commit()
