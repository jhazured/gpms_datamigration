#!/bin/bash

# Ensure notebooks directory exists on host
mkdir -p ./notebooks

# Define cleanup function to stop and remove docker-compose services
cleanup() {
  echo "Cleaning up... stopping docker-compose services"
  docker compose down
}

# Set traps to run cleanup on script exit or interruption (Ctrl+C, kill, etc.)
trap cleanup EXIT INT TERM

# Start docker-compose with build and up in detached mode
docker compose -f docker-compose.yml up --build -d

echo "JupyterLab should be running at http://localhost:8888"

# Keep script running to allow manual exit (e.g., Ctrl+C) and trigger cleanup
# This waits indefinitely for any background job (none here), effectively pausing the script
wait
