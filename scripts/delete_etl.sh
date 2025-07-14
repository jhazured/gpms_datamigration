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
  echo "Usage: delete_etl.sh --env ENV --script ETL_SCRIPT"
  exit 1
fi

echo "Deleting ETL artifacts for: ${ETL_SCRIPT} in environment: ${ENV}"

# Example: Remove job files from GCS bucket
gsutil rm -r "gs://my-etl-bucket/${ENV}/jobs/${ETL_SCRIPT}/"

echo "ETL script '${ETL_SCRIPT}' deleted successfully for environment '${ENV}'."
