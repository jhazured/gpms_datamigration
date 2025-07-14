#!/usr/bin/env bash

set -e

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --env) ENV="$2"; shift ;;
    --script) ETL_SCRIPT="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

if [ -z "$ENV" ] || [ -z "$ETL_SCRIPT" ]; then
  echo "Usage: trigger_gcp_run.sh --env ENV --script ETL_SCRIPT"
  exit 1
fi

echo "Triggering ETL run for script: $ETL_SCRIPT"
echo "Environment: $ENV"

# Example: Trigger a Cloud Composer DAG (Airflow)
gcloud composer environments run my-composer-env \
  --location us-central1 \
  trigger_dag -- "my_${ETL_SCRIPT}_dag"

echo "ETL run triggered successfully."
