#!/usr/bin/env bash
# Source this file from the repository root:
#   source part2/scripts/setup.sh
#
# Discovers lab resource identifiers, prompts for secrets, and uploads the
# Glue scripts. Secrets remain in the current shell session only.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Please source this script from the repository root: source part2/scripts/setup.sh" >&2
  exit 1
fi

deftunes_load_part2_env() {
  local project account_id rds_id redshift_id

  export TF_VAR_project="${TF_VAR_project:-de-c4w4a2}"
  export TF_VAR_region="${TF_VAR_region:-us-east-1}"
  export AWS_DEFAULT_REGION="$TF_VAR_region"
  export AWS_REGION="$TF_VAR_region"

  command -v aws >/dev/null 2>&1 || {
    echo "AWS CLI is required. Configure credentials before running this script." >&2
    return 1
  }
  command -v terraform >/dev/null 2>&1 || {
    echo "Terraform is required." >&2
    return 1
  }

  project="$TF_VAR_project"
  account_id="$(aws sts get-caller-identity --query Account --output text)" || return 1
  rds_id="$project-rds"
  redshift_id="$project-redshift-cluster"

  export TF_VAR_vpc_id
  TF_VAR_vpc_id="$(aws rds describe-db-instances \
    --db-instance-identifier "$rds_id" \
    --query 'DBInstances[0].DBSubnetGroup.VpcId' --output text)" || return 1

  export TF_VAR_private_subnet_a_id
  TF_VAR_private_subnet_a_id="$(aws ec2 describe-subnets \
    --filters "Name=tag:aws:cloudformation:logical-id,Values=PrivateSubnetA" \
              "Name=vpc-id,Values=$TF_VAR_vpc_id" \
    --query 'Subnets[0].SubnetId' --output text)" || return 1

  export TF_VAR_db_sg_id
  TF_VAR_db_sg_id="$(aws rds describe-db-instances \
    --db-instance-identifier "$rds_id" \
    --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)" || return 1

  export TF_VAR_source_host
  TF_VAR_source_host="$(aws rds describe-db-instances \
    --db-instance-identifier "$rds_id" \
    --query 'DBInstances[0].Endpoint.Address' --output text)" || return 1

  export TF_VAR_data_lake_bucket
  TF_VAR_data_lake_bucket="$(aws s3api list-buckets \
    --query "Buckets[?starts_with(Name, '$project') && ends_with(Name, 'data-lake')].Name | [0]" \
    --output text)" || return 1

  export TF_VAR_scripts_bucket="${project}-${account_id}-${TF_VAR_region}-scripts"
  export TF_VAR_source_port=5432
  export TF_VAR_source_database=postgres
  export TF_VAR_source_username="${TF_VAR_source_username:-postgresuser}"
  export TF_VAR_catalog_database="${project//-/_}_silver_db"
  export TF_VAR_users_table=users
  export TF_VAR_sessions_table=sessions
  export TF_VAR_songs_table=songs
  export TF_VAR_redshift_role_name="$project-load-role"

  export TF_VAR_redshift_host
  TF_VAR_redshift_host="$(aws redshift describe-clusters \
    --cluster-identifier "$redshift_id" \
    --query 'Clusters[0].Endpoint.Address' --output text)" || return 1
  export TF_VAR_redshift_user="${TF_VAR_redshift_user:-defaultuser}"
  export TF_VAR_redshift_database=dev
  export TF_VAR_redshift_port=5439

  for value in "$TF_VAR_private_subnet_a_id" "$TF_VAR_db_sg_id" \
               "$TF_VAR_source_host" "$TF_VAR_data_lake_bucket" "$TF_VAR_redshift_host"; do
    if [[ -z "$value" || "$value" == "None" ]]; then
      echo "AWS resource discovery returned an empty value. Check the lab account and CloudFormation stack." >&2
      return 1
    fi
  done

  if [[ -z "${TF_VAR_api_endpoint:-}" ]]; then
    read -r -p "DeFtunes API base URL or host (from CloudFormation APIEndpoint): " TF_VAR_api_endpoint || return 1
  fi
  if [[ "$TF_VAR_api_endpoint" != http://* && "$TF_VAR_api_endpoint" != https://* ]]; then
    TF_VAR_api_endpoint="http://$TF_VAR_api_endpoint"
  fi
  export TF_VAR_api_endpoint="${TF_VAR_api_endpoint%/}"

  if [[ -z "${TF_VAR_source_password:-}" ]]; then
    read -r -s -p "Source PostgreSQL password: " TF_VAR_source_password || return 1
    printf '\n'
  fi
  if [[ -z "${TF_VAR_redshift_password:-}" ]]; then
    read -r -s -p "Redshift password: " TF_VAR_redshift_password || return 1
    printf '\n'
  fi
  export TF_VAR_source_password TF_VAR_redshift_password

  aws s3 cp part2/terraform/assets/extract_jobs/de-c4w4a2-api-extract-job.py \
    "s3://$TF_VAR_scripts_bucket/de-c4w4a2-api-extract-job.py" || return 1
  aws s3 cp part2/terraform/assets/extract_jobs/de-c4w4a2-extract-songs-job.py \
    "s3://$TF_VAR_scripts_bucket/de-c4w4a2-extract-songs-job.py" || return 1
  aws s3 cp part2/terraform/assets/transform_jobs/de-c4w4a2-transform-json-job.py \
    "s3://$TF_VAR_scripts_bucket/de-c4w4a2-transform-json-job.py" || return 1
  aws s3 cp part2/terraform/assets/transform_jobs/de-c4w4a2-transform-songs-job.py \
    "s3://$TF_VAR_scripts_bucket/de-c4w4a2-transform-songs-job.py" || return 1

  echo "Part 2 environment variables loaded into this shell."
  echo "Glue scripts uploaded to s3://$TF_VAR_scripts_bucket."
  echo "No passwords were written to ~/.bashrc."
}

deftunes_load_part2_env
deftunes_status=$?
unset -f deftunes_load_part2_env
if [[ $deftunes_status -ne 0 ]]; then
  return "$deftunes_status"
fi
