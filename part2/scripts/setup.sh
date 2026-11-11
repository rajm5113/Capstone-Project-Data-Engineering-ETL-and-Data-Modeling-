#!/usr/bin/env bash
# Source this file from the project root:
#   source part2/scripts/setup.sh
#
# This script discovers lab resource metadata through the AWS CLI. It prompts for
# database passwords at runtime and exports them only in the current shell session.
# It never writes credentials to ~/.bashrc or source control.

set -euo pipefail

export TF_VAR_project="${TF_VAR_project:-de-c4w4a2}"
export TF_VAR_region="${TF_VAR_region:-us-east-1}"
export AWS_DEFAULT_REGION="$TF_VAR_region"
export AWS_REGION="$TF_VAR_region"

command -v aws >/dev/null || {
  echo "AWS CLI is required. Configure credentials before running this script." >&2
  return 1 2>/dev/null || exit 1
}
command -v terraform >/dev/null || {
  echo "Terraform is required." >&2
  return 1 2>/dev/null || exit 1
}

account_id="$(aws sts get-caller-identity --query Account --output text)"
rds_id="$TF_VAR_project-rds"
redshift_id="$TF_VAR_project-redshift-cluster"

export TF_VAR_vpc_id
TF_VAR_vpc_id="$(aws rds describe-db-instances \
  --db-instance-identifier "$rds_id" \
  --query 'DBInstances[0].DBSubnetGroup.VpcId' --output text)"

export TF_VAR_private_subnet_a_id
TF_VAR_private_subnet_a_id="$(aws ec2 describe-subnets \
  --filters "Name=tag:aws:cloudformation:logical-id,Values=PrivateSubnetA" \
            "Name=vpc-id,Values=$TF_VAR_vpc_id" \
  --query 'Subnets[0].SubnetId' --output text)"

export TF_VAR_db_sg_id
TF_VAR_db_sg_id="$(aws rds describe-db-instances \
  --db-instance-identifier "$rds_id" \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)"

export TF_VAR_source_host
TF_VAR_source_host="$(aws rds describe-db-instances \
  --db-instance-identifier "$rds_id" \
  --query 'DBInstances[0].Endpoint.Address' --output text)"
export TF_VAR_source_port=5432
export TF_VAR_source_database=postgres
export TF_VAR_source_username="${TF_VAR_source_username:-postgresuser}"

export TF_VAR_data_lake_bucket
TF_VAR_data_lake_bucket="$(aws s3api list-buckets \
  --query "Buckets[?starts_with(Name, '$TF_VAR_project') && ends_with(Name, 'data-lake')].Name | [0]" \
  --output text)"

export TF_VAR_scripts_bucket="${TF_VAR_project}-${account_id}-${TF_VAR_region}-scripts"
export TF_VAR_catalog_database="${TF_VAR_project//-/_}_silver_db"
export TF_VAR_users_table=users
export TF_VAR_sessions_table=sessions
export TF_VAR_songs_table=songs
export TF_VAR_redshift_role_name="$TF_VAR_project-load-role"

export TF_VAR_redshift_host
TF_VAR_redshift_host="$(aws redshift describe-clusters \
  --cluster-identifier "$redshift_id" \
  --query 'Clusters[0].Endpoint.Address' --output text)"
export TF_VAR_redshift_user="${TF_VAR_redshift_user:-defaultuser}"
export TF_VAR_redshift_database=dev
export TF_VAR_redshift_port=5439

read -r -p "DeFtunes API base URL (include https:// or http://): " TF_VAR_api_endpoint
read -r -s -p "Source PostgreSQL password: " TF_VAR_source_password
printf '\n'
read -r -s -p "Redshift password: " TF_VAR_redshift_password
printf '\n'
export TF_VAR_source_password TF_VAR_redshift_password

# Copy the Glue scripts to the environment's scripts bucket.
aws s3 cp part2/terraform/assets/extract_jobs/de-c4w4a2-api-extract-job.py \
  "s3://$TF_VAR_scripts_bucket/de-c4w4a2-api-extract-job.py"
aws s3 cp part2/terraform/assets/extract_jobs/de-c4w4a2-extract-songs-job.py \
  "s3://$TF_VAR_scripts_bucket/de-c4w4a2-extract-songs-job.py"
aws s3 cp part2/terraform/assets/transform_jobs/de-c4w4a2-transform-json-job.py \
  "s3://$TF_VAR_scripts_bucket/de-c4w4a2-transform-json-job.py"
aws s3 cp part2/terraform/assets/transform_jobs/de-c4w4a2-transform-songs-job.py \
  "s3://$TF_VAR_scripts_bucket/de-c4w4a2-transform-songs-job.py"

echo "Environment variables loaded for this shell session."
echo "No credentials were written to ~/.bashrc."
