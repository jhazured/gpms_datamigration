#!/bin/bash

ETL_NAME=$1

echo "Running pytest tests inside the running etl_runner container..."

if [ -z "$ETL_NAME" ]; then
  docker compose exec etl_test pytest tests/ --maxfail=3 --disable-warnings -q --junitxml=/app/data/test-results.xml
else
  docker compose exec etl_test pytest tests/ -k "$ETL_NAME" --maxfail=3 --disable-warnings -q --junitxml=/app/data/test-results.xml
fi

exit_code=$?

if [ $exit_code -eq 0 ]; then
  echo "Tests passed!"
else
  echo "Tests failed with exit code $exit_code"
fi

exit $exit_code

