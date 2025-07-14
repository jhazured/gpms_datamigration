#!/usr/bin/env bash

# tasks.sh
# Usage: ./tasks.sh [command] [ENV]

set -e

COMMAND=$1
ENVIRONMENT=$2  # For build: dev | prod

IMAGE_NAME=my_etl_image

LOGS_DIR="logs"
mkdir -p "$LOGS_DIR"

case $COMMAND in

  build)
    echo "Building Docker image for ENV: '$ENVIRONMENT'"

    if [ "$ENVIRONMENT" = "dev" ]; then
      DOCKERFILE="docker/Dockerfile.dev-ubuntu"
    elif [ "$ENVIRONMENT" = "prod" ]; then
      DOCKERFILE="Dockerfile.jenkins"
    else
      echo "Invalid environment: $ENVIRONMENT"
      exit 1
    fi

    LOG_FILE="${LOGS_DIR}/build_${ENVIRONMENT}_$(date +%Y%m%d_%H%M%S).log"
    echo "Using Dockerfile: $DOCKERFILE"
    echo "Logging build output to $LOG_FILE"

    {
      echo "[Build started at $(date)]"
      docker build --no-cache -f "$DOCKERFILE" -t "${IMAGE_NAME}:${ENVIRONMENT}" .
      echo "[Build completed at $(date)]"
    } | tee "$LOG_FILE"

    ;;

  build_all)
    echo "Rebuilding ALL environments WITHOUT cache..."
    ./scripts/tasks.sh build dev
    ./scripts/tasks.sh build prod
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
    docker system prune -a -f --volumes
    ;;

  *)
    echo "Usage: $0 {build|build_all|run|jupyter|up|down|test|format|lint|clean} [ENV]"
    exit 1
    ;;

esac
