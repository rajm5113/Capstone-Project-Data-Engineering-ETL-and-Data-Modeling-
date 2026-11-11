# DeFtunes — End-to-End Data Engineering Capstone

**Project focus:** ETL pipeline, AWS data lake, Apache Iceberg, Redshift Spectrum, infrastructure as code, and dbt  
**Project context:** DeFtunes music-streaming and digital song-purchase business  
**Region used in the lab configuration:** `us-east-1`

---

## 1. Project Overview

DeFtunes is a music platform that offers subscription-based song streaming and has expanded into digital song purchases. The business needs a reliable way to bring together operational song information and purchase activity so that its Data Analysis team can query consistent, well-structured data.

This two-part project builds that data platform in stages. Part 1 establishes the AWS data lake, extraction and transformation workloads, Iceberg tables, Glue Catalog, Redshift Spectrum and Terraform infrastructure. Part 2 extends the platform with incremental ingestion, Glue Data Quality rules, Airflow orchestration, dbt dimensional models and business views, and an Apache Superset visualization workflow.

The pipeline follows a three-zone, medallion-style design:

1. **Landing zone:** raw data extracted from the source systems and stored in Amazon S3.
2. **Transformation zone:** cleaned and structured data stored as Apache Iceberg tables in Amazon S3 and registered in the AWS Glue Data Catalog.
3. **Serving zone:** analytical access through Amazon Redshift and Redshift Spectrum, with dbt used to organize SQL transformations for the final serving layer.

Part 2 extends this foundation into a more governed and operational workflow with quality validation, scheduled orchestration and BI-ready outputs.

## 2. Business Problem

The DeFtunes application has information in separate operational systems:

- A PostgreSQL database contains the catalogue of songs available for purchase.
- An API exposes user and session information associated with activity in the application.

Keeping these sources separate makes it harder for analysts to work with a unified view of the business. The data therefore needs to be extracted, stored centrally, standardized, and made available for analytical queries.

This capstone addresses that need by creating a data pipeline that:

- Extracts song data from PostgreSQL.
- Extracts users and sessions data from the API.
- Preserves source data in an S3 landing area.
- Normalizes and standardizes the extracted records.
- Stores transformed datasets in Apache Iceberg format.
- Uses the Glue Data Catalog to expose table metadata.
- Makes the transformed data queryable from Redshift Spectrum.
- Establishes a dbt project connected to the Redshift serving schema.

## 3. Project Objectives

The main technical objectives are:

- Build a three-zone data lake architecture using Amazon S3.
- Implement extraction and transformation workloads with AWS Glue.
- Store transformed datasets as Apache Iceberg tables.
- Use AWS Glue Data Catalog to maintain metadata for the Iceberg datasets.
- Provision reusable AWS infrastructure through Terraform modules.
- Use Amazon Redshift Spectrum to query the S3-based Iceberg tables without first copying all their data into native Redshift tables.
- Prepare a dbt project to manage SQL-based transformations in the serving layer.
- Keep credentials and generated environment files out of the public source repository.

## 4. Architecture

The architecture diagram below is included in the repository.

![DeFtunes Part 1 data engineering architecture](images/Capstone-diagram.svg)

### 4.1 High-level data flow

```mermaid
flowchart TD
    A["PostgreSQL on Amazon RDS<br/>deftunes.songs"]
    B["DeFtunes API<br/>/users and /sessions"]
    C["AWS Glue extraction jobs"]
    D["Amazon S3<br/>Landing zone — raw data"]
    E["AWS Glue transformation jobs"]
    F["Apache Iceberg tables<br/>Amazon S3 — transformation zone"]
    G["AWS Glue Data Catalog"]
    H["Amazon Redshift Spectrum"]
    I["Amazon Redshift<br/>Serving schema"]
    J["dbt models"]
    K["Analytics-ready serving data"]

    A --> C
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I
    I --> J
    J --> K
```

### 4.2 Architecture components

| Component | Responsibility in this project |
|---|---|
| Amazon RDS for PostgreSQL | Hosts the operational `deftunes` database and its `songs` table. |
| DeFtunes API | Provides user and session records through API endpoints. |
| AWS Glue | Runs the extraction and transformation jobs. |
| Amazon S3 | Stores the landing-zone data and the transformed Iceberg datasets. |
| Apache Iceberg | Provides the table format used for the transformation-zone datasets. |
| AWS Glue Data Catalog | Stores metadata used to discover and query the Iceberg tables. |
| Amazon Redshift | Provides the data warehouse and serving environment. |
| Redshift Spectrum | Allows Redshift to query the S3 data through the Glue Catalog. |
| Terraform | Defines and provisions the AWS infrastructure in a repeatable way. |
| dbt | Provides the project structure and SQL workflow for serving-layer data models. |
| Python and SQL | Implement extraction, transformation, exploration, and analytical modeling tasks. |

## 5. Data Sources

The notebook documents two source systems.

### 5.1 PostgreSQL source database

The operational database runs on Amazon RDS with PostgreSQL.

- **Database:** `postgres`
- **Schema:** `deftunes`
- **Table used:** `songs`
- **Purpose:** provides the song catalogue and song-level information relevant to digital purchases.
- **Dataset context:** the notebook notes that the `songs` table is based on the Million Song Dataset.

The notebook connects to the database with SQL magic and explores the `deftunes.songs` table. A small sample is loaded into a Pandas DataFrame to inspect its columns, data types, and descriptive statistics.

### 5.2 DeFtunes API

The API provides application activity data.

| Endpoint | Information retrieved | Extraction purpose |
|---|---|---|
| `GET /sessions` | Session records, with a start-date and end-date filter | Extracts user session activity. |
| `GET /users` | User records | Extracts information about application users. |

The notebook tests the API requests and checks for a successful HTTP response. It also inspects example JSON records before the extraction jobs are deployed.

**Important:** the API host and AWS resource endpoints are environment-specific. Obtain current values from the CloudFormation stack outputs or the configured lab environment instead of copying endpoint values from an old notebook run.

## 6. Exploratory Data Analysis

Before building the pipeline, the notebook performs an initial exploration of the source data.

The steps include:

1. Querying a sample from `deftunes.songs` using SQL.
2. Converting the query result into a Pandas DataFrame.
3. Using `DataFrame.info()` to inspect column names, data types, and non-null values.
4. Using `DataFrame.describe()` to review summary statistics for numerical columns.
5. Converting the API JSON responses into DataFrames with `pandas.json_normalize()`.
6. Inspecting sample user and session records.

This exploration helps establish the structure of the source data before extraction and transformation logic is applied.

## 7. ETL Pipeline

The ETL workflow has three main phases: extraction into the landing zone, transformation into the Iceberg-based transformation zone, and analytical access through the serving zone.

### 7.1 Phase 1 — Landing zone: data extraction

The landing zone is the first layer of the S3 data lake. It stores data extracted from the source systems before the transformation jobs process it.

Three AWS Glue extraction jobs are provisioned:

| Glue job | Source | Purpose |
|---|---|---|
| `de-c4w4a1-rds-extract-job` | PostgreSQL on Amazon RDS | Extracts the `songs` data from the source database. |
| `de-c4w4a1-api-users-extract-job` | DeFtunes API `/users` endpoint | Extracts user records from the API. |
| `de-c4w4a1-api-sessions-extract-job` | DeFtunes API `/sessions` endpoint | Extracts session records from the API. |

The API extraction script accepts endpoint parameters and is reused for the API extraction workloads. The database extraction script handles the PostgreSQL source.

The notebook specifies that landing-zone data is organized into subfolders based on the ingestion date. In the lab, the default date is based on the server's Pacific Time setting (UTC−7).

**Output of this phase:** raw source extracts stored in the S3 landing zone, ready for transformation.

### 7.2 Phase 2 — Transformation zone: standardization and Iceberg

The transformation zone is the second layer of the data lake. Its purpose is to convert raw source extracts into structured datasets that can be queried consistently.

Two AWS Glue transformation jobs are provisioned:

| Glue job | Input | Transformation purpose |
|---|---|---|
| `de-c4w4a1-json-transform-job` | JSON data extracted from the API | Normalizes nested JSON fields, adds metadata, and writes the transformed data in Apache Iceberg format. |
| `de-c4w4a1-songs-transform-job` | Song data extracted from PostgreSQL | Casts fields to the appropriate data types, adds metadata, and writes the transformed data in Apache Iceberg format. |

The transformed datasets are stored in the S3 transformation zone as Apache Iceberg tables. Their table metadata is registered in the AWS Glue Data Catalog.

The notebook describes this layer as the **silver layer**.

**Why Apache Iceberg is used here:** it provides a table format for organizing the transformed datasets in the data lake. The Glue Catalog keeps the table metadata available to services such as Redshift Spectrum.

**Output of this phase:** structured Iceberg datasets for songs, users, and sessions, registered in the Glue Data Catalog.

### 7.3 Phase 3 — Serving zone: Redshift and Spectrum

The serving zone is the final layer of the architecture. It provides an analytical access layer for the transformed data.

Amazon Redshift is provisioned as the data warehouse. Redshift Spectrum is configured to access the Iceberg tables in S3 through the AWS Glue Data Catalog.

This is important because Spectrum can query the S3-based data through the external schema rather than requiring the project to load every source dataset into a native Redshift table first.

The notebook uses the following Redshift database and schema names:

| Name | Purpose |
|---|---|
| `dev` | Redshift database used in the lab. |
| `deftunes_transform` | External schema that exposes the transformation-zone Iceberg tables. |
| `deftunes_serving` | Schema intended for the serving-layer models. |

The notebook validates the setup by listing schemas and tables and selecting sample records from the external `songs`, `sessions`, and `users` tables.

The notebook describes the serving layer as the **gold layer**.

**Output of this phase:** an analytical environment in Redshift that can query the transformed Iceberg datasets and host serving-layer models.

## 8. Infrastructure as Code with Terraform

Terraform is used to define and provision the AWS infrastructure. The project separates infrastructure into modules so that the extraction, transformation, and serving components can be deployed in stages.

### 8.1 Terraform module layout

| Module | Main responsibility | Supporting configuration |
|---|---|---|
| `extract_job` | Creates the extraction Glue jobs and supporting access/network configuration. | Glue job definitions, IAM role and policies, private subnet and database security-group configuration, variables, and outputs. |
| `transform_job` | Creates the Glue transformation jobs and associated configuration for writing transformed datasets. | Glue job definitions, variables, and outputs. |
| `serving` | Creates the Redshift serving infrastructure and its required IAM configuration. | Redshift resource definition, IAM configuration, provider configuration, variables, and outputs. |

The root Terraform configuration is in the `terraform/` directory. The module definitions are connected through `main.tf`, and relevant deployment outputs are exposed through `outputs.tf`.

### 8.2 Deployment sequence

Run Terraform from the `terraform` directory. The notebook deploys the modules in this order:

```bash
cd terraform
terraform init
terraform plan
```

Deploy the extraction module:

```bash
terraform apply -target=module.extract_job
```

Deploy the transformation module:

```bash
terraform apply -target=module.transform_job
```

Deploy the serving module:

```bash
terraform apply -target=module.serving
```

Terraform prompts for confirmation before applying infrastructure changes. Review the plan and confirm that the target resources and region are correct before approving an apply.

**Note:** targeted applies are the staged deployment approach shown in the capstone notebook. For a production workflow, review the complete Terraform dependency graph and deployment plan rather than assuming targeted applies are always the preferred approach.

### 8.3 Glue script storage

The notebook copies the Python Glue scripts to the S3 scripts bucket before deploying and running the related jobs. The scripts are stored in:

- `terraform/assets/extract_jobs/`
- `terraform/assets/transform_jobs/`

The scripts bucket name is supplied by the lab environment. Use the current CloudFormation output or environment configuration to identify it.

### 8.4 Running and monitoring Glue jobs

The notebook starts a Glue job with the AWS CLI:

```bash
aws glue start-job-run --job-name <JOB-NAME>
```

The returned job run ID can be used to check the job state:

```bash
aws glue get-job-run \
  --job-name <JOB-NAME> \
  --run-id <JOB-RUN-ID> \
  --query "JobRun.JobRunState" \
  --output text
```

A successful run reports:

```text
SUCCEEDED
```

Run the three extraction jobs after deploying the extraction module. Run the two transformation jobs after deploying the transformation module. The serving infrastructure is deployed after the transformation layer is in place.

## 9. Validating the Data in Redshift

After the serving infrastructure has been deployed, the notebook verifies that Redshift can discover and query the Iceberg tables through Spectrum.

Examples of the validation queries used in the notebook:

```sql
SHOW SCHEMAS FROM DATABASE dev;
```

List the tables exposed by the external schema:

```sql
SHOW TABLES FROM SCHEMA dev.deftunes_transform;
```

Inspect a sample of the songs:

```sql
SELECT *
FROM deftunes_transform.songs
LIMIT 10;
```

Inspect a sample of the sessions:

```sql
SELECT *
FROM deftunes_transform.sessions
LIMIT 10;
```

Inspect a sample of the users:

```sql
SELECT *
FROM deftunes_transform.users
LIMIT 10;
```

These checks validate that the external schema is available and that Redshift Spectrum can read the registered transformation-zone tables.

## 10. Data Modeling with dbt

The project includes a dbt project under `dbt_modeling/`. The notebook uses dbt with Amazon Redshift as the target so SQL models can be organized and executed in the serving environment.

### 10.1 dbt connection configuration

The lab's Redshift connection uses the following settings:

| Setting | Value or source |
|---|---|
| Adapter | Redshift |
| Host | Current Redshift cluster endpoint from the AWS environment |
| Port | `5439` |
| Database | `dev` |
| User | Configured Redshift user |
| Schema | `deftunes_serving` |
| Threads | `1` |

Use the template at `scripts/profiles.yml.example` as a reference. Replace its placeholders with the current environment's connection details in a local dbt profile. Do not commit a profile containing real credentials.

A typical local profile location is:

```text
~/.dbt/profiles.yml
```

Test the connection from the dbt project directory:

```bash
cd dbt_modeling
dbt debug
```

A successful connection test reports an `OK` connection status.

### 10.2 Serving-layer star schema

The original Coursera notebook labels this modeling extension optional and not graded. It asks for a `serving_layer` folder, one SQL model for each fact or dimension table, a `schema.yml` file, and a run with `dbt run -s serving_layer`. This repository now includes that implementation as a portfolio extension.

The source tables are the Redshift Spectrum external tables in `dev.deftunes_transform`. The dbt profile targets `deftunes_serving`.

| Model | Role | Transformation |
|---|---|---|
| `dim_users` | Dimension | Keeps the latest user attributes for each `user_id`. |
| `dim_songs` | Dimension | Keeps the latest catalogue attributes for each `song_id`. |
| `dim_artists` | Dimension | Keeps one current artist record per `artist_id`, sourced from the songs table. |
| `fact_session` | Fact | Stores user/song/artist activity, price, like status and session start time. |

The models use dbt's `source()` function, with source declarations in `dbt_modeling/models/sources.yml`. The serving models are materialized as Redshift tables. The accompanying `schema.yml` documents the models and checks dimension business keys for uniqueness and completeness.

**Important grain detail:** the upstream Glue JSON transformation explodes the `session_items` array, so the sessions table contains one row per song item in a session. For that reason, `fact_session` is at session-item grain and `session_id` is not tested as a unique key by itself.

Run the project from the `dbt_modeling/` directory after the Glue jobs have populated the three source tables:

```bash
dbt debug
dbt run -s serving_layer
dbt test -s serving_layer
```

The resulting tables can be checked in Redshift:

```sql
SHOW TABLES FROM SCHEMA dev.deftunes_serving;
SELECT * FROM deftunes_serving.fact_session LIMIT 10;
```

## 11. Repository Structure

The repository keeps the two capstone parts together while separating their implementation files.

~~~text
.
├── README.md
├── .gitignore
├── images/
│   └── Capstone-diagram.svg
├── scripts/
│   ├── setup.sh
│   └── profiles.yml.example
├── terraform/
│   ├── assets/
│   │   ├── extract_jobs/
│   │   └── transform_jobs/
│   ├── modules/
│   │   ├── extract_job/
│   │   ├── transform_job/
│   │   └── serving/
│   └── root Terraform files
├── dbt_modeling/
│   ├── models/
│   │   ├── sources.yml
│   │   └── serving_layer/
│   │       ├── dim_users.sql
│   │       ├── dim_songs.sql
│   │       ├── dim_artists.sql
│   │       ├── fact_session.sql
│   │       └── schema.yml
│   ├── dbt_project.yml
│   └── README.md
└── part2/
    ├── README.md
    ├── dags/
    │   ├── deftunes_api_pipeline.py
    │   └── deftunes_songs_pipeline.py
    ├── images/
    │   └── Capstone-part2-architecture.svg
    ├── dbt_modeling/
    │   ├── dbt_project.yml
    │   ├── packages.yml
    │   ├── macros/
    │   └── models/
    │       ├── serving_layer/
    │       └── bi_views/
    ├── scripts/
    └── terraform/
        ├── assets/
        └── modules/
            ├── data_quality/
            ├── extract_job/
            ├── transform_job/
            └── serving/
~~~

Generated directories such as Terraform's `.terraform/`, Terraform state files, dbt `target/` and `logs/`, and local credential files are intentionally excluded from version control.

## 12. Running the Project — Practical Checklist

Use the following sequence as a high-level checklist. Exact endpoint values, resource identifiers, and credentials must come from the current AWS lab environment.

1. **Prepare the environment**
   - Configure AWS CLI credentials.
   - Confirm access to the lab's AWS account and region.
   - Review `scripts/setup.sh` and the Terraform variables.
   - Run the setup script from the project root when the required AWS resources are available:

   ```bash
   source scripts/setup.sh
   ```

2. **Prepare the extraction jobs**
   - Review the Python scripts under `terraform/assets/extract_jobs/`.
   - The setup script uploads the four extraction and transformation scripts to the discovered S3 scripts bucket.
   - Initialize Terraform and deploy `module.extract_job`.

3. **Extract the source data**
   - Start the RDS songs extraction job.
   - Start the API users extraction job.
   - Start the API sessions extraction job.
   - Monitor the job runs until they finish successfully.

4. **Prepare and run transformations**
   - Review the scripts under `terraform/assets/transform_jobs/`.
   - The setup script has already uploaded the extraction and transformation scripts to the S3 scripts bucket. Rerun it after changing a Glue script.
   - Deploy `module.transform_job`.
   - Start the JSON transformation job and the songs transformation job.
   - Verify that the transformed Iceberg tables are registered in the Glue Catalog.

5. **Deploy the serving layer**
   - Deploy `module.serving`.
   - Confirm the Redshift cluster and the required IAM configuration.
   - Verify the external schema and query the Iceberg tables with Redshift Spectrum.

6. **Configure and test dbt**
   - Configure a local `~/.dbt/profiles.yml` using the safe example profile.
   - Run `dbt debug` to test connectivity.
   - Run `dbt run -s serving_layer` to build the four dimension/fact models.
   - Run `dbt test -s serving_layer` to check the model tests.
   - Query the resulting serving tables in Redshift.

## 13. Security and Configuration

This repository is intended to be a reviewable project portfolio, not a place to publish live infrastructure credentials.

- Do not commit AWS access keys, session tokens, console sign-in URLs, database passwords, private keys, or real `.env` files.
- Keep `scripts/profiles.yml` local; use `scripts/profiles.yml.example` as the shareable template.
- Source `scripts/setup.sh` to discover lab resource identifiers and load `TF_VAR_` settings into the current shell. It prompts for the DeFtunes API base URL and database passwords; passwords are not written to `~/.bashrc`.
- Use current endpoints from the AWS environment rather than embedding temporary endpoint values in source code.
- Review Terraform variables and backend configuration before deploying from a different AWS account.
- The `.gitignore` file excludes local credentials and generated Terraform/dbt files. The local Terraform backend writes `terraform.tfstate`, which remains untracked.

The course environment may issue new resource endpoints and configuration values when it is recreated. Old outputs should not be treated as reusable credentials or current infrastructure identifiers.

## 14. Scope and Possible Extensions

Both capstone parts are represented in this repository. The assignment notebooks are intentionally not included; the executable source code, Terraform configuration, Airflow DAGs, dbt models and project documentation are the portfolio artifacts.

## 15. Skills Demonstrated

This project brings together several practical data engineering skills:

- Working with PostgreSQL and REST API data sources.
- Exploring structured and JSON data with SQL and Pandas.
- Building extraction and transformation workloads with AWS Glue.
- Designing a landing, transformation, and serving-zone data lake.
- Storing analytical datasets in Amazon S3 using Apache Iceberg.
- Managing table metadata through AWS Glue Data Catalog.
- Querying data lake tables with Amazon Redshift Spectrum.
- Provisioning modular cloud infrastructure with Terraform.
- Organizing SQL transformations in a dbt project.
- Validating pipeline stages and database connectivity.
- Managing configuration and excluding credentials from source control.

## 16. Acknowledgment

This repository documents the DeFtunes ETL and data modeling capstone completed as part of a Coursera data engineering learning program. The original course notebook was used as a reference while preparing the source code and documentation, but is intentionally not included in this portfolio repository.

---

**Project takeaway:** DeFtunes demonstrates how operational database records and API data can be brought into an S3-based data lake, transformed into catalogued Iceberg tables, and made available for analytics through Redshift Spectrum and a dbt-oriented serving workflow.


---

# Part 2 — Data Quality, Orchestration and Visualization

Part 2 extends the original ETL platform with operational controls and an analytics presentation layer. The complete source and a dedicated technical guide are under **part2/**.

![DeFtunes Part 2 architecture](part2/images/Capstone-part2-architecture.svg)

## Part 2 capabilities

### Incremental ingestion

The extraction jobs accept an ingestion date and write source extracts into date-partitioned S3 paths. The corresponding Glue transformations read the selected partition, enrich the data and write it to partitioned Apache Iceberg tables. If the same logical ingestion date is rerun, the matching Iceberg partition is overwritten rather than duplicated.

### AWS Glue Data Quality

The Terraform data_quality module defines rule sets for users, sessions and songs in the Glue Data Catalog. The rule sets check required values, identifier lengths, user-ID uniqueness and a business price bound. Airflow runs these checks after transformation and waits for their results before starting dbt.

### Apache Airflow orchestration

Two Airflow DAGs coordinate the workflow:

- **Songs DAG:** RDS extract → songs transform → songs quality evaluation → dbt.
- **API DAG:** users and sessions API extracts in parallel → JSON transform → users and sessions quality checks in parallel → dbt.

Retries, retry delays, catchup/backfill behavior and date-driven job parameters are configured in the DAGs. Environment-specific values are externalized into Airflow Variables.

**Schedule note:** the supplied course DAG sample defaults to a monthly cron schedule (0 0 1 * *), while the assignment prose describes a daily run. The schedule is configurable through the deftunes_schedule Airflow Variable; validate the desired backfill window before changing it to @daily.

### dbt analytical models

Part 2 adds a dimensional serving layer:

| Model | Role |
|---|---|
| dim_users | User descriptive attributes |
| dim_songs | Song descriptive attributes |
| dim_artists | Artist descriptive attributes |
| fact_session | Session-level measures and relationships |

It also adds two business views:

- **sales_per_artist_vw:** total sales by artist and year.
- **sales_per_country_vw:** total sales by country, month and year.

### Apache Superset visualization

The lab workflow connects Superset to Redshift, registers the BI views as datasets, builds charts and assembles a dashboard. The supplied archive did not include a portable Superset dashboard export, so this repository documents the workflow rather than claiming to contain a dashboard definition.

## Part 2 source layout

- **part2/dags/** — Airflow DAGs for API and songs pipelines.
- **part2/terraform/modules/data_quality/** — DQDL rule sets.
- **part2/terraform/assets/** — incremental Glue extraction and transformation scripts.
- **part2/dbt_modeling/models/serving_layer/** — fact and dimension models.
- **part2/dbt_modeling/models/bi_views/** — sales analysis views.
- **part2/scripts/** — secure setup helper, dbt profile template and Airflow restart helper.

Read the [Part 2 technical guide](part2/README.md) for the complete data-quality rules, task dependencies, model descriptions, Airflow Variables and setup sequence.

## Portfolio and reproducibility notes

- The Part 2 setup script prompts for database passwords and does not append them to the shell profile.
- Local dbt profiles, Terraform variable files and Terraform state must remain untracked.
- Airflow Variables must be configured for the target environment before unpausing either DAG.
- The training IAM policy includes broad permissions for the lab; replace wildcard permissions with least-privilege policies before production use.
- AWS Glue, Redshift, S3, EC2, Airflow and Superset may incur costs. Review and clean up lab resources after use.
