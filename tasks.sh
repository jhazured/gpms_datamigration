#!/usr/bin/env bash

# tasks.sh
# Usage: ./tasks.sh [command] [ENV]

set -e

COMMAND=$1
ENVIRONMENT=${2:-dev}  # Default to dev if not provided

IMAGE_NAME=my_etl_image

case $COMMAND in

  build)
    echo "Building Docker image for ENV: $ENVIRONMENT"
    docker build -t ${IMAGE_NAME}:${ENVIRONMENT} .
    ;;

  run)
    echo "Running ETL job for ENV: $ENVIRONMENT"
    docker run --rm -e ENV=${ENVIRONMENT} ${IMAGE_NAME}:${ENVIRONMENT} \
      python3 framework/main.py --config scripts/ETL1.yaml
    ;;

  jupyter)
    echo "Starting JupyterLab with Docker Compose..."
    docker compose up --build jupyterlab
    ;;

  up)
    echo "Bringing up all services..."
    docker compose up --build
    ;;

  down)
    echo "Stopping all services..."
    docker compose down
    ;;

  test)
    echo "Running tests..."
    pytest tests/
    ;;

  format)
    echo "Formatting code with Black..."
    black framework tests
    ;;

  lint)
    echo "Linting code with Flake8..."
    flake8 framework tests
    ;;

  clean)
    echo "Pruning dangling Docker images..."
    docker image prune -f
    ;;

  *)
    echo "Usage: $0 {build|run|jupyter|up|down|test|format|lint|clean} [ENV]"
    exit 1
    ;;

esac
