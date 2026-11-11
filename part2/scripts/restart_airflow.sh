#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT:-de-c4w4a2}"

airflow_instance_id="$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=$PROJECT-da-instance" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[0].InstanceId' --output text)"

if [[ -z "$airflow_instance_id" || "$airflow_instance_id" == "None" ]]; then
  echo "No running Airflow EC2 instance found for project $PROJECT." >&2
  exit 1
fi

command_id="$(aws ssm send-command \
  --region "$AWS_REGION" \
  --instance-ids "$airflow_instance_id" \
  --document-name "AWS-RunShellScript" \
  --comment "Restart Airflow service" \
  --parameters 'commands=["sudo bash /opt/airflow/restart_airflow.sh"]' \
  --query 'Command.CommandId' --output text)"

echo "Restart command submitted: $command_id"

for attempt in $(seq 1 30); do
  status="$(aws ssm list-command-invocations \
    --region "$AWS_REGION" \
    --command-id "$command_id" \
    --details \
    --query 'CommandInvocations[0].StatusDetails' --output text)"

  echo "Airflow restart status: $status"

  case "$status" in
    Success)
      echo "Restart command completed. Refresh the Airflow UI."
      exit 0
      ;;
    Failed|Cancelled|TimedOut|Undeliverable|Terminated)
      echo "Airflow restart command did not succeed." >&2
      exit 1
      ;;
  esac

  sleep 10
done

echo "Timed out waiting for the Airflow restart command." >&2
exit 1
