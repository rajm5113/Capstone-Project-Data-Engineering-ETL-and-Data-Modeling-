from datetime import datetime, timedelta
import os

from airflow import DAG
from airflow.models import Variable
from airflow.operators.empty import EmptyOperator
from airflow.providers.amazon.aws.operators.glue import (
    GlueDataQualityRuleSetEvaluationRunOperator,
    GlueJobOperator,
)
from airflow.providers.docker.operators.docker import DockerOperator
from docker.types import Mount

# Configure these Airflow Variables in the target environment before unpausing.
PROJECT = Variable.get("deftunes_project", default_var="de-c4w4a2")
AWS_REGION = Variable.get("aws_region", default_var="us-east-1")
DATA_BUCKET_NAME = Variable.get(
    "deftunes_data_lake_bucket", default_var="CHANGE_ME_DATA_LAKE_BUCKET"
)
SCRIPTS_BUCKET_NAME = Variable.get(
    "deftunes_scripts_bucket", default_var="CHANGE_ME_SCRIPTS_BUCKET"
)
API_BASE_URL = Variable.get(
    "deftunes_api_base_url", default_var="https://CHANGE_ME_API_HOST"
).rstrip("/")
CATALOG_DATABASE = Variable.get(
    "deftunes_catalog_database", default_var="de_c4w4a2_silver_db"
)
GLUE_ROLE_ARN = Variable.get(
    "deftunes_glue_role_arn",
    default_var="arn:aws:iam::<ACCOUNT_ID>:role/de-c4w4a2-glue-role",
)
DBT_PROJECT_HOST_PATH = Variable.get(
    "deftunes_dbt_project_host_path", default_var="/docker_dbt/dbt_project"
)
DBT_NETWORK_MODE = Variable.get(
    "deftunes_dbt_network_mode", default_var="container:dbt"
)
PIPELINE_SCHEDULE = Variable.get("deftunes_schedule", default_var="0 0 1 * *")

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="deftunes_api_pipeline_dag",
    description="Extract API users and sessions, transform, validate quality, and run dbt",
    default_args=default_args,
    schedule=PIPELINE_SCHEDULE,
    start_date=datetime(2020, 2, 1),
    end_date=datetime(2020, 4, 1),
    catchup=True,
    max_active_runs=1,
    tags=["deftunes", "aws-glue", "data-quality", "dbt"],
) as dag:
    start = EmptyOperator(task_id="start")

    api_users_extract = GlueJobOperator(
        task_id="api_users_extract_glue_job",
        job_name=f"{PROJECT}-api-users-extract-job",
        script_location=f"s3://{SCRIPTS_BUCKET_NAME}/de-c4w4a2-api-extract-job.py",
        job_desc="Extract users from the DeFtunes API into the S3 landing zone",
        iam_role_name=f"{PROJECT}-glue-role",
        s3_bucket=SCRIPTS_BUCKET_NAME,
        region_name=AWS_REGION,
        create_job_kwargs={
            "GlueVersion": "4.0",
            "NumberOfWorkers": 2,
            "WorkerType": "G.1X",
        },
        script_args={
            "--target_path": f"s3://{DATA_BUCKET_NAME}/landing_zone/api/users",
            "--api_url": f"{API_BASE_URL}/users",
            "--api_start_date": "{{ ds }}",
            "--api_end_date": "{{ macros.ds_add(next_ds, -1) }}",
            "--ingest_date": "{{ next_ds }}",
        },
    )

    api_sessions_extract = GlueJobOperator(
        task_id="api_sessions_extract_glue_job",
        job_name=f"{PROJECT}-api-sessions-extract-job",
        script_location=f"s3://{SCRIPTS_BUCKET_NAME}/de-c4w4a2-api-extract-job.py",
        job_desc="Extract sessions from the DeFtunes API into the S3 landing zone",
        iam_role_name=f"{PROJECT}-glue-role",
        s3_bucket=SCRIPTS_BUCKET_NAME,
        region_name=AWS_REGION,
        create_job_kwargs={
            "GlueVersion": "4.0",
            "NumberOfWorkers": 2,
            "WorkerType": "G.1X",
        },
        script_args={
            "--target_path": f"s3://{DATA_BUCKET_NAME}/landing_zone/api/sessions",
            "--api_url": f"{API_BASE_URL}/sessions",
            "--api_start_date": "{{ ds }}",
            "--api_end_date": "{{ macros.ds_add(next_ds, -1) }}",
            "--ingest_date": "{{ next_ds }}",
        },
    )

    json_transform = GlueJobOperator(
        task_id="json_transform_glue_job",
        job_name=f"{PROJECT}-json-transform-job",
        script_location=f"s3://{SCRIPTS_BUCKET_NAME}/de-c4w4a2-transform-json-job.py",
        job_desc="Transform API users and sessions into Iceberg tables",
        iam_role_name=f"{PROJECT}-glue-role",
        s3_bucket=SCRIPTS_BUCKET_NAME,
        region_name=AWS_REGION,
        create_job_kwargs={
            "GlueVersion": "4.0",
            "NumberOfWorkers": 2,
            "WorkerType": "G.1X",
        },
        script_args={
            "--catalog_database": CATALOG_DATABASE,
            "--ingest_date": "{{ next_ds }}",
            "--users_source_path": f"s3://{DATA_BUCKET_NAME}/landing_zone/api/users",
            "--sessions_source_path": f"s3://{DATA_BUCKET_NAME}/landing_zone/api/sessions",
            "--target_bucket_path": DATA_BUCKET_NAME,
            "--users_table": "users",
            "--sessions_table": "sessions",
        },
    )

    dq_users = GlueDataQualityRuleSetEvaluationRunOperator(
        task_id="dq_check_users",
        role=GLUE_ROLE_ARN,
        rule_set_names=["users_dq_ruleset"],
        number_of_workers=2,
        wait_for_completion=True,
        region_name=AWS_REGION,
        datasource={
            "GlueTable": {
                "TableName": "users",
                "DatabaseName": CATALOG_DATABASE,
            }
        },
    )

    dq_sessions = GlueDataQualityRuleSetEvaluationRunOperator(
        task_id="dq_check_sessions",
        role=GLUE_ROLE_ARN,
        rule_set_names=["sessions_dq_ruleset"],
        number_of_workers=2,
        wait_for_completion=True,
        region_name=AWS_REGION,
        datasource={
            "GlueTable": {
                "TableName": "sessions",
                "DatabaseName": CATALOG_DATABASE,
            }
        },
    )

    dbt = DockerOperator(
        task_id="docker_dbt_command",
        image=Variable.get("deftunes_dbt_image", default_var="dbt_custom_image"),
        api_version="auto",
        auto_remove=True,
        docker_url="unix://var/run/docker.sock",
        command=(
            "bash -c "
            '"dbt --version && '
            "dbt run --profiles-dir /usr/app/.dbt --project-dir /usr/app/dbt_modeling && "
            'dbt test --profiles-dir /usr/app/.dbt --project-dir /usr/app/dbt_modeling"'
        ),
        mounts=[
            Mount(
                source=os.path.join(DBT_PROJECT_HOST_PATH, "dbt_modeling"),
                target="/usr/app/dbt_modeling",
                type="bind",
            ),
            Mount(
                source=os.path.join(DBT_PROJECT_HOST_PATH, ".dbt"),
                target="/usr/app/.dbt",
                type="bind",
            ),
        ],
        network_mode=DBT_NETWORK_MODE,
    )

    end = EmptyOperator(task_id="end")

    start >> [api_users_extract, api_sessions_extract]
    [api_users_extract, api_sessions_extract] >> json_transform
    json_transform >> [dq_users, dq_sessions]
    [dq_users, dq_sessions] >> dbt >> end
