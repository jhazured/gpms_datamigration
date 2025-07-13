#!/bin/bash

ETL_NAME=$1

echo "Running pytest tests inside Docker..."

docker run --rm -v "$(pwd)":/app -w /app gpms_etl_runner:latest bash -c "\
  if [ -z \"$ETL_NAME\" ]; then \
    pytest tests/ --maxfail=3 --disable-warnings -q; \
  else \
    pytest tests/ -k \"$ETL_NAME\" --maxfail=3 --disable-warnings -q; \
  fi
"

exit_code=$?

if [ $exit_code -eq 0 ]; then
  echo "Tests passed!"
else
  echo "Tests failed with exit code $exit_code"
fi

exit $exit_code
