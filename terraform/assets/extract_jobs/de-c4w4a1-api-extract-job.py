import json
import sys
from datetime import datetime

import requests
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext

args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "target_path",
        "api_url",
        "api_start_date",
        "api_end_date",
    ],
)

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

api_url = args["api_url"]
start_date = args["api_start_date"]
end_date = args["api_end_date"]
target_path = args["target_path"].rstrip("/")

response = requests.get(
    api_url,
    params={"start_date": start_date, "end_date": end_date},
    timeout=60,
)
response.raise_for_status()
records = response.json()

if not isinstance(records, list):
    records = [records]
if not records:
    raise RuntimeError(f"The API returned no records for {start_date} through {end_date}.")

# Spark's JSON reader expects one JSON object per input record.
json_rows = [json.dumps(record) for record in records]
api_data_df = spark.read.json(sc.parallelize(json_rows)).coalesce(1)
api_data_df.printSchema()

ingest_date = datetime.now().strftime("%Y-%m-%d")
output_path = f"{target_path}/{ingest_date}/"
api_data_df.write.mode("overwrite").json(output_path)

job.commit()
