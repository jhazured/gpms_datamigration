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
  echo "Usage: deploy_etl.sh --env ENV --script ETL_SCRIPT"
  exit 1
fi

echo "Deploying ETL script: $ETL_SCRIPT"
echo "Environment: $ENV"

# Example: Copy ETL script to GCS or staging folder
# Replace with your actual deployment logic
gsutil cp "etl_jobs/${ETL_SCRIPT}.py" "gs://my-etl-bucket/${ENV}/jobs/"

echo "ETL script deployed successfully."
