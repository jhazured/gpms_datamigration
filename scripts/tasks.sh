#!/usr/bin/env bash

# tasks.sh
# Usage: ./tasks.sh [command] [ENV]

set -e

COMMAND=$1

ENVIRONMENT=$2  # For build: dev | prod

IMAGE_NAME=my_etl_image

# Run the tasks based on command
case $COMMAND in
  build)
    echo "Building Docker image for ENV: '$ENVIRONMENT'"

    if [ "$ENVIRONMENT" = "dev" ]; then
      DOCKERFILE="docker/Dockerfile.ubuntu"
    elif [ "$ENVIRONMENT" = "prod" ]; then
      DOCKERFILE="docker/Dockerfile.jenkins"
    else
      echo "Invalid environment: $ENVIRONMENT"
      exit 1
    fi

    echo "Using Dockerfile: $DOCKERFILE"
    echo "Building image: ${IMAGE_NAME}:${ENVIRONMENT}"

    docker build -f "$DOCKERFILE" -t "${IMAGE_NAME}:${ENVIRONMENT}" .

    ;;

  build_all)
    echo "Rebuilding ALL environments WITH cache..."
    ./scripts/tasks.sh build dev
    echo "Starting etl_test container to initialize volume and run tests..."
    docker compose up etl_test
    ;;


  up)
    echo "Bringing up all services..."
    docker compose up --build
    ;;

  down)
    echo "Stopping all services..."
    docker compose down
    ;;

  clean)
    echo "Pruning dangling Docker images..."
    docker system prune -a -f --volumes
    ;;

  *)
    echo "Usage: $0 {build|build_all|up|down|clean} [ENV]"
    exit 1
    ;;

esac
