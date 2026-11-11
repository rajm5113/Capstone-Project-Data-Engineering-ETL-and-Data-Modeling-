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

# Set these Airflow Variables in the target environment before unpausing the DAG.
PROJECT = Variable.get("deftunes_project", default_var="de-c4w4a2")
AWS_REGION = Variable.get("aws_region", default_var="us-east-1")
DATA_BUCKET_NAME = Variable.get("deftunes_data_lake_bucket", default_var="CHANGE_ME_DATA_LAKE_BUCKET")
SCRIPTS_BUCKET_NAME = Variable.get("deftunes_scripts_bucket", default_var="CHANGE_ME_SCRIPTS_BUCKET")
CATALOG_DATABASE = Variable.get("deftunes_catalog_database", default_var="de_c4w4a2_silver_db")
GLUE_ROLE_ARN = Variable.get("deftunes_glue_role_arn", default_var="arn:aws:iam::<ACCOUNT_ID>:role/de-c4w4a2-glue-role")
DBT_PROJECT_HOST_PATH = Variable.get(
    "deftunes_dbt_project_host_path", default_var="/docker_dbt/dbt_project"
)
DBT_NETWORK_MODE = Variable.get("deftunes_dbt_network_mode", default_var="container:dbt")
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
    dag_id="deftunes_songs_pipeline_dag",
    description="Extract songs from RDS, transform, validate quality, and run dbt",
    default_args=default_args,
    schedule=PIPELINE_SCHEDULE,
    start_date=datetime(2020, 2, 1),
    end_date=datetime(2020, 3, 1),
    catchup=True,
    max_active_runs=1,
    tags=["deftunes", "aws-glue", "data-quality", "dbt"],
) as dag:
    start = EmptyOperator(task_id="start")

    rds_extract = GlueJobOperator(
        task_id="rds_extract_glue_job",
        job_name=f"{PROJECT}-rds-extract-job",
        script_location=f"s3://{SCRIPTS_BUCKET_NAME}/de-c4w4a2-extract-songs-job.py",
        job_desc="Extract songs from PostgreSQL RDS into the S3 landing zone",
        iam_role_name=f"{PROJECT}-glue-role",
        s3_bucket=SCRIPTS_BUCKET_NAME,
        region_name=AWS_REGION,
        create_job_kwargs={"GlueVersion": "4.0", "NumberOfWorkers": 2, "WorkerType": "G.1X"},
        script_args={
            "--data_lake_bucket": DATA_BUCKET_NAME,
            "--rds_connection": f"{PROJECT}-connection-rds",
            "--ingest_date": "{{ next_ds }}",
        },
    )

    songs_transform = GlueJobOperator(
        task_id="songs_transform_glue_job",
        job_name=f"{PROJECT}-songs-transform-job",
        script_location=f"s3://{SCRIPTS_BUCKET_NAME}/de-c4w4a2-transform-songs-job.py",
        job_desc="Transform songs CSV landing data into an Iceberg table",
        iam_role_name=f"{PROJECT}-glue-role",
        s3_bucket=SCRIPTS_BUCKET_NAME,
        region_name=AWS_REGION,
        create_job_kwargs={"GlueVersion": "4.0", "NumberOfWorkers": 2, "WorkerType": "G.1X"},
        script_args={
            "--catalog_database": CATALOG_DATABASE,
            "--ingest_date": "{{ next_ds }}",
            "--songs_table": "songs",
            "--source_bucket_path": DATA_BUCKET_NAME,
            "--target_bucket_path": DATA_BUCKET_NAME,
        },
    )

    dq_songs = GlueDataQualityRuleSetEvaluationRunOperator(
        task_id="dq_check_songs",
        role=GLUE_ROLE_ARN,
        rule_set_names=["songs_dq_ruleset"],
        number_of_workers=2,
        wait_for_completion=True,
        region_name=AWS_REGION,
        datasource={"GlueTable": {"TableName": "songs", "DatabaseName": CATALOG_DATABASE}},
    )

    dbt = DockerOperator(
        task_id="docker_dbt_command",
        image=Variable.get("deftunes_dbt_image", default_var="dbt_custom_image"),
        api_version="auto",
        auto_remove=True,
        docker_url="unix://var/run/docker.sock",
        command=(
            "bash -c "
            '"dbt --version && dbt debug '
            "--profiles-dir /usr/app/.dbt "
            "--project-dir /usr/app/dbt_modeling && dbt run "
            "--profiles-dir /usr/app/.dbt "
            '--project-dir /usr/app/dbt_modeling"'
        ),
        mounts=[
            Mount(
                source=os.path.join(DBT_PROJECT_HOST_PATH, "dbt_modeling", "dbt_project.yml"),
                target="/usr/app/dbt_modeling/dbt_project.yml",
                type="bind",
            ),
            Mount(
                source=os.path.join(DBT_PROJECT_HOST_PATH, "dbt_modeling", "models"),
                target="/usr/app/dbt_modeling/models",
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
    start >> rds_extract >> songs_transform >> dq_songs >> dbt >> end
