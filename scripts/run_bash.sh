#!/usr/bin/env bash

# Define cleanup function to stop and remove the container on exit or interruption
cleanup() {
  echo "Cleaning up... stopping and removing container $CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

# Set traps early to ensure cleanup runs on script exit or interruption
trap cleanup EXIT INT TERM

# Set container name
CONTAINER_NAME="local_etl_bash"

# Run Docker container interactively with the given name and mounted volume
docker run -it --name "$CONTAINER_NAME" \
  -v gcp_datamigration:/app/data \
  --user devuser \
  my_etl_image:dev \
  bash -c "
    mkdir -p /app/data && \
    chmod -R 0777 /app/data && \
    exec bash
  "

# When docker run exits, cleanup will be triggered by trap automatically
