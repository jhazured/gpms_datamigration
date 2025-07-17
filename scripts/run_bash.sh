#!/usr/bin/env bash

# run_bash.sh - GCP Data Migration ETL Framework Runner
# This script provides an interactive bash session inside the Docker container
# for running ETL jobs, debugging, and development

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTAINER_NAME="gcp_datamigration_runner"
IMAGE_NAME="gcp_datamigration"
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

GCP Data Migration ETL Framework Runner

This script starts an interactive bash session inside the Docker container
for running ETL jobs, development, and debugging.

OPTIONS:
    -h, --help          Show this help message
    -b, --build         Force rebuild of Docker image before starting
    -d, --detach        Run container in detached mode
    -e, --env ENV       Set environment (dev/prod, default: dev)
    -c, --cleanup       Clean up existing containers before starting
    -v, --verbose       Enable verbose output
    --no-mount          Don't mount local directories (use container only)
    --port PORT         Expose additional port (can be used multiple times)

COMMANDS:
    If no command is provided, an interactive bash session is started.
    You can also run specific commands:
    
    Examples:
        $0                          # Interactive bash session
        $0 python framework/main.py # Run ETL framework directly
        $0 pytest tests/            # Run tests
        $0 ls -la etls/             # List ETL configurations

EXAMPLES:
    $0                              # Start interactive session
    $0 --build                      # Rebuild and start interactive session
    $0 --env prod                   # Start with production environment
    $0 python framework/main.py     # Run ETL framework
    $0 --cleanup --build            # Clean rebuild and start

ENVIRONMENT VARIABLES:
    GCP_PROJECT_ID      - GCP Project ID
    GCP_REGION          - GCP Region (default: australia-southeast1)
    GOOGLE_APPLICATION_CREDENTIALS - Path to GCP service account key

OTHER SCRIPTS:
    run_pytest.sh       - Run unit tests
    run_tasks.sh        - Run specific ETL tasks

EOF
}

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running or not accessible"
        exit 1
    fi
}

# Check if docker-compose is available
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        log_error "Docker Compose is not installed or not accessible"
        exit 1
    fi
}

# Clean up existing containers
cleanup_containers() {
    log_info "Cleaning up existing containers..."
    
    # Stop and remove container if it exists
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Stopping and removing existing container: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" &> /dev/null || true
        docker rm "$CONTAINER_NAME" &> /dev/null || true
    fi
    
    # Clean up docker-compose containers
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        log_info "Cleaning up docker-compose containers..."
        cd "$PROJECT_ROOT"
        $DOCKER_COMPOSE_CMD down --remove-orphans &> /dev/null || true
    fi
}

# Build Docker image
build_image() {
    log_info "Building Docker image..."
    cd "$PROJECT_ROOT"
    
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        log_info "Using docker-compose to build image..."
        $DOCKER_COMPOSE_CMD build --no-cache
    else
        log_info "Using Dockerfile to build image..."
        if [[ -f "docker/Dockerfile.dev-ubuntu" ]]; then
            docker build -f docker/Dockerfile.dev-ubuntu -t "$IMAGE_NAME" .
        elif [[ -f "Dockerfile" ]]; then
            docker build -t "$IMAGE_NAME" .
        else
            log_error "No Dockerfile found in expected locations"
            exit 1
        fi
    fi
    
    log_success "Docker image built successfully"
}

# Setup environment variables
setup_environment() {
    local env_file="$PROJECT_ROOT/.env"
    
    # Create .env file if it doesn't exist
    if [[ ! -f "$env_file" ]]; then
        log_info "Creating default .env file..."
        cat > "$env_file" << EOF
# GCP Data Migration Environment Variables
GCP_PROJECT_ID=${GCP_PROJECT_ID:-my-gcp-project}
GCP_REGION=${GCP_REGION:-australia-southeast1}
ENVIRONMENT=${ENVIRONMENT:-dev}

# Add your other environment variables here
# GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
EOF
        log_warning "Created default .env file. Please update it with your actual values."
    fi
}

# Run container with interactive bash
run_interactive_bash() {
    local extra_args=()
    local mount_args=()
    
    # Setup volume mounts unless --no-mount is specified
    if [[ "$NO_MOUNT" != "true" ]]; then
        mount_args+=(
            "-v" "$PROJECT_ROOT:/app"
            "-v" "$PROJECT_ROOT/jobs-output:/app/jobs-output"
        )
        
        # Mount Google Cloud credentials if available
        if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]] && [[ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
            mount_args+=(
                "-v" "$GOOGLE_APPLICATION_CREDENTIALS:/tmp/gcp-key.json"
                "-e" "GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp-key.json"
            )
        fi
    fi
    
    # Add environment file
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        extra_args+=("--env-file" "$PROJECT_ROOT/.env")
    fi
    
    # Add custom ports
    for port in "${CUSTOM_PORTS[@]}"; do
        extra_args+=("-p" "$port:$port")
    done
    
    # Set environment
    extra_args+=("-e" "ENVIRONMENT=$ENVIRONMENT")
    
    # Setup working directory
    extra_args+=("-w" "/app")
    
    # Run container
    log_info "Starting interactive bash session in container..."
    log_info "Container name: $CONTAINER_NAME"
    log_info "Working directory: /app"
    
    if [[ "$DETACH" == "true" ]]; then
        extra_args+=("-d")
        log_info "Running in detached mode"
    else
        extra_args+=("-it")
        log_info "Starting interactive session..."
        echo -e "${GREEN}===============================================${NC}"
        echo -e "${GREEN}  GCP Data Migration ETL Framework${NC}"
        echo -e "${GREEN}===============================================${NC}"
        echo -e "${YELLOW}Available commands:${NC}"
        echo -e "  • python framework/main.py    - Run ETL framework"
        echo -e "  • pytest tests/               - Run tests"
        echo -e "  • ls etls/                    - List ETL configurations"
        echo -e "  • cd jobs-output && ls -l     - Check job outputs"
        echo -e "  • exit                        - Exit container"
        echo -e "${GREEN}===============================================${NC}"
        echo ""
    fi
    
    # Choose image source
    local image_to_run
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        # Use docker-compose service
        cd "$PROJECT_ROOT"
        if [[ ${#COMMAND[@]} -eq 0 ]]; then
            $DOCKER_COMPOSE_CMD run --rm --name "$CONTAINER_NAME" ${extra_args[@]} "${mount_args[@]}" app bash
        else
            $DOCKER_COMPOSE_CMD run --rm --name "$CONTAINER_NAME" ${extra_args[@]} "${mount_args[@]}" app "${COMMAND[@]}"
        fi
    else
        # Use direct docker run
        if [[ ${#COMMAND[@]} -eq 0 ]]; then
            docker run --rm --name "$CONTAINER_NAME" ${extra_args[@]} "${mount_args[@]}" "$IMAGE_NAME" bash
        else
            docker run --rm --name "$CONTAINER_NAME" ${extra_args[@]} "${mount_args[@]}" "$IMAGE_NAME" "${COMMAND[@]}"
        fi
    fi
}

# Main execution function
main() {
    # Default values
    local BUILD=false
    local DETACH=false
    local CLEANUP=false
    local VERBOSE=false
    local NO_MOUNT=false
    local ENVIRONMENT="dev"
    local CUSTOM_PORTS=()
    local COMMAND=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--build)
                BUILD=true
                shift
                ;;
            -d|--detach)
                DETACH=true
                shift
                ;;
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -c|--cleanup)
                CLEANUP=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            --no-mount)
                NO_MOUNT=true
                shift
                ;;
            --port)
                CUSTOM_PORTS+=("$2")
                shift 2
                ;;
            --)
                shift
                COMMAND=("$@")
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                COMMAND=("$@")
                break
                ;;
        esac
    done
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Check prerequisites
    check_docker
    check_docker_compose
    
    # Setup environment
    setup_environment
    
    # Cleanup if requested
    if [[ "$CLEANUP" == "true" ]]; then
        cleanup_containers
    fi
    
    # Build if requested or if image doesn't exist
    if [[ "$BUILD" == "true" ]] || ! docker images --format "table {{.Repository}}" | grep -q "^${IMAGE_NAME}$"; then
        build_image
    fi
    
    # Run the container
    run_interactive_bash
}

# Trap to cleanup on exit
trap cleanup_containers EXIT

# Run main function
main "$@"