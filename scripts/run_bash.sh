#!/usr/bin/env bash

# Define cleanup function to stop and remove the container on exit or interruption
cleanup() {
  echo "Cleaning up... stopping and removing container $CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

# Set traps early to ensure cleanup runs on script exit or interruption
trap cleanup EXIT INT TERM

# Set container name
CONTAINER_NAME="local_test_container"

# Run Docker container interactively with the given name
docker run -it --name "$CONTAINER_NAME" \
  -v gpms_datamigration:/home/etl_user/jobs-output \
  --user root \
  --name gpms_etl_runner_bash \
  gpms_etl_runner:latest \
  bash -c "
    # Create the data directory if it doesn't exist
    mkdir -p /home/etl_user/jobs-output/data && \
    chmod -R 0777 /home/etl_user/jobs-output && \
    exec bash
  "

# When docker run exits, cleanup will be triggered by trap automatically