#!/usr/bin/env bash
# Load the Part 1 Coursera lab settings into the current shell:
#   source scripts/setup.sh
#
# The script discovers temporary AWS resource identifiers and prompts for
# environment-specific values. Passwords are kept in this shell only; they
# are never written to ~/.bashrc or to the repository.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Please source this script from the repository root: source scripts/setup.sh" >&2
  exit 1
fi

deftunes_load_part1_env() {
  local project account_id vpc_id subnet_id db_sg_id rds_host data_bucket redshift_host

  project="${TF_VAR_project:-de-c4w4a1}"
  export TF_VAR_project="$project"
  export TF_VAR_region="${TF_VAR_region:-us-east-1}"
  export AWS_DEFAULT_REGION="$TF_VAR_region"
  export AWS_REGION="$TF_VAR_region"

  command -v aws >/dev/null 2>&1 || {
    echo "AWS CLI is required. Configure credentials before running this script." >&2
    return 1
  }

  account_id="$(aws sts get-caller-identity --query Account --output text)" || return 1
  vpc_id="$(aws rds describe-db-instances \
    --db-instance-identifier "${project}-rds" \
    --query 'DBInstances[0].DBSubnetGroup.VpcId' --output text)" || return 1
  subnet_id="$(aws ec2 describe-subnets \
    --filters "Name=tag:aws:cloudformation:logical-id,Values=PublicSubnetA" \
              "Name=vpc-id,Values=$vpc_id" \
    --query 'Subnets[0].SubnetId' --output text)" || return 1
  db_sg_id="$(aws rds describe-db-instances \
    --db-instance-identifier "${project}-rds" \
    --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)" || return 1
  rds_host="$(aws rds describe-db-instances \
    --db-instance-identifier "${project}-rds" \
    --query 'DBInstances[0].Endpoint.Address' --output text)" || return 1
  redshift_host="$(aws redshift describe-clusters \
    --cluster-identifier "${project}-redshift-cluster" \
    --query 'Clusters[0].Endpoint.Address' --output text)" || return 1
  data_bucket="$(aws s3api list-buckets \
    --query "Buckets[?starts_with(Name, '$project') && ends_with(Name, 'data-lake')].Name | [0]" \
    --output text)" || return 1

  for value in "$vpc_id" "$subnet_id" "$db_sg_id" "$rds_host" "$redshift_host" "$data_bucket"; do
    if [[ -z "$value" || "$value" == "None" ]]; then
      echo "AWS resource discovery returned an empty value. Check the lab account and CloudFormation resources." >&2
      return 1
    fi
  done

  export TF_VAR_vpc_id="$vpc_id"
  export TF_VAR_public_subnet_a_id="$subnet_id"
  export TF_VAR_db_sg_id="$db_sg_id"
  export TF_VAR_source_host="$rds_host"
  export TF_VAR_source_port=5432
  export TF_VAR_source_database=postgres
  export TF_VAR_source_username="${TF_VAR_source_username:-postgresuser}"
  export TF_VAR_data_lake_bucket="$data_bucket"
  export TF_VAR_scripts_bucket="${project}-${account_id}-${TF_VAR_region}-scripts"
  export TF_VAR_catalog_database="${project//-/_}_silver_db"
  export TF_VAR_users_table=users
  export TF_VAR_sessions_table=sessions
  export TF_VAR_songs_table=songs
  export TF_VAR_redshift_role_name="${project}-load-role"
  export TF_VAR_redshift_host="$redshift_host"
  export TF_VAR_redshift_user="${TF_VAR_redshift_user:-defaultuser}"
  export TF_VAR_redshift_database=dev
  export TF_VAR_redshift_port=5439

  if [[ -z "${TF_VAR_api_endpoint:-}" ]]; then
    read -r -p "DeFtunes API host or base URL (from CloudFormation APIEndpoint): " TF_VAR_api_endpoint || return 1
  fi
  if [[ "$TF_VAR_api_endpoint" != http://* && "$TF_VAR_api_endpoint" != https://* ]]; then
    TF_VAR_api_endpoint="http://$TF_VAR_api_endpoint"
  fi
  TF_VAR_api_endpoint="${TF_VAR_api_endpoint%/}"
  export TF_VAR_api_endpoint

  if [[ -z "${TF_VAR_source_password:-}" ]]; then
    read -r -s -p "Source PostgreSQL password: " TF_VAR_source_password || return 1
    printf '\n'
  fi
  if [[ -z "${TF_VAR_redshift_password:-}" ]]; then
    read -r -s -p "Redshift password: " TF_VAR_redshift_password || return 1
    printf '\n'
  fi
  export TF_VAR_source_password TF_VAR_redshift_password

  echo "Part 1 environment variables loaded into this shell."
  echo "API base URL: $TF_VAR_api_endpoint"
  echo "No passwords were written to ~/.bashrc."
}

deftunes_load_part1_env
deftunes_status=$?
unset -f deftunes_load_part1_env
if [[ $deftunes_status -ne 0 ]]; then
  return "$deftunes_status"
fi
