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
        "ingest_date",
    ],
)

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)


def fetch_data_from_api(api_url: str):
    """Fetch a JSON response from the configured DeFtunes API endpoint."""
    response = requests.get(api_url, timeout=60)
    response.raise_for_status()
    return response.json()


api_url = args["api_url"]
request_start_date = args["api_start_date"]
request_end_date = args["api_end_date"]
target_path = args["target_path"]

ingest_date = datetime.strptime(args["ingest_date"], "%Y-%m-%d")
formatted_ingest_date = ingest_date.strftime("%Y_%m_%d")

request_api_url = (
    f"{api_url}?start_date={request_start_date}&end_date={request_end_date}"
)
print(f"Extracting API data for {request_start_date} through {request_end_date}")
request_data = fetch_data_from_api(request_api_url)

api_data_df = spark.read.json(sc.parallelize([json.dumps(request_data)]))
api_data_df = api_data_df.coalesce(1)
api_data_df.printSchema()

# Partition by the logical ingestion date to support repeatable incremental loads.
output_path = f"{target_path.rstrip('/')}/ingest_on={formatted_ingest_date}/"
api_data_df.write.mode("overwrite").json(output_path)

job.commit()
