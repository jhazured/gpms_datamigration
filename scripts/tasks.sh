#!/bin/bash

# ETL Project Task Runner for GCP
# Usage: ./run_tasks.sh [task] [options]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="etl-project"
DOCKER_REGISTRY="gcr.io/your-project-id"  # Update with your GCP project ID
UBUNTU_IMAGE="ubuntu-etl"
JENKINS_IMAGE="jenkins-etl"
ANSIBLE_IMAGE="ansible-etl"

# Function to print colored messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists gcloud; then
        print_error "gcloud CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check if authenticated with gcloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "Not authenticated with gcloud. Run 'gcloud auth login'"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to setup Python environment
setup_python_env() {
    print_status "Setting up Python environment..."
    
    if [ ! -d "venv" ]; then
        print_status "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    
    # Install development dependencies
    if [ -f "requirements/dev.txt" ]; then
        print_status "Installing development dependencies..."
        pip install -r requirements/dev.txt
    elif [ -f "requirements.txt" ]; then
        print_status "Installing dependencies from requirements.txt..."
        pip install -r requirements.txt
    else
        print_warning "No requirements file found. Installing basic dependencies..."
        pip install pytest pytest-cov pytest-html
    fi
    
    print_success "Python environment setup complete"
}

# Function to run linting (basic setup)
run_linting() {
    print_status "Running code linting..."
    
    source venv/bin/activate
    
    # Install basic linting tools if not present
    pip install flake8 black isort --quiet
    
    print_status "Running black (code formatter)..."
    black --check . || {
        print_warning "Code formatting issues found. Run 'black .' to fix"
    }
    
    print_status "Running isort (import sorting)..."
    isort --check-only . || {
        print_warning "Import sorting issues found. Run 'isort .' to fix"
    }
    
    print_status "Running flake8 (linting)..."
    flake8 . || {
        print_warning "Linting issues found"
    }
    
    print_success "Linting complete"
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    ./run_pytest.sh
    print_success "Tests completed"
}

# Function to build Docker images
build_docker_images() {
    print_status "Building Docker images..."
    
    # Build Ubuntu ETL image with production requirements
    if [ -f "docker/Dockerfile.ubuntu" ]; then
        print_status "Building Ubuntu ETL image..."
        if [ -f "requirements/prod.txt" ]; then
            docker build -t ${UBUNTU_IMAGE}:latest \
                --build-arg REQUIREMENTS_FILE=requirements/prod.txt \
                -f docker/Dockerfile.ubuntu .
        else
            docker build -t ${UBUNTU_IMAGE}:latest -f docker/Dockerfile.ubuntu .
        fi
        print_success "Ubuntu image built successfully"
    fi
    
    # Build Jenkins image
    if [ -f "docker/Dockerfile,jenkins" ]; then
        print_status "Building Jenkins image..."
        docker build -t ${JENKINS_IMAGE}:latest -f docker/Dockerfile.jenkins .
        print_success "Jenkins image built successfully"
    fi
    
    # Build Ansible image
    if [ -f "docker/Dockerfile.ansible" ]; then
        print_status "Building Ansible image..."
        docker build -t ${ANSIBLE_IMAGE}:latest -f docker/Dockerfile.ansible .
        print_success "Ansible image built successfully"
    fi
    
    print_success "All Docker images built successfully"
}

# Function to build only Ubuntu image for local development
build_ubuntu_image() {
    print_status "Building Ubuntu ETL image for local development..."
    
    if [ -f "docker/ubuntu/Dockerfile" ]; then
        # Use dev requirements if available, otherwise fall back to base requirements
        if [ -f "requirements/dev.txt" ]; then
            print_status "Using development requirements..."
            docker build -t ${UBUNTU_IMAGE}:latest \
                --build-arg REQUIREMENTS_FILE=requirements/dev.txt \
                -f docker/ubuntu/Dockerfile .
        else
            print_status "Using base requirements..."
            docker build -t ${UBUNTU_IMAGE}:latest -f docker/ubuntu/Dockerfile .
        fi
        print_success "Ubuntu image built successfully"
    else
        print_error "Ubuntu Dockerfile not found at docker/ubuntu/Dockerfile"
        exit 1
    fi
}

# Function to run Ubuntu container locally
run_ubuntu_container() {
    print_status "Running Ubuntu ETL container locally..."
    
    # Check if image exists
    if ! docker image inspect ${UBUNTU_IMAGE}:latest >/dev/null 2>&1; then
        print_warning "Ubuntu image not found. Building it first..."
        build_ubuntu_image
    fi
    
    # Run container with volume mounts for development
    docker run -it --rm \
        --name ${UBUNTU_IMAGE}-dev \
        -v $(pwd):/workspace \
        -v $(pwd)/data:/data \
        -w /workspace \
        ${UBUNTU_IMAGE}:latest \
        /bin/bash
}

# Function to tag and push images to GCP
deploy_to_gcp() {
    print_status "Deploying images to GCP Container Registry..."
    
    # Configure Docker for GCP
    gcloud auth configure-docker --quiet
    
    # Tag and push Ubuntu image
    docker tag ${UBUNTU_IMAGE}:latest ${DOCKER_REGISTRY}/${UBUNTU_IMAGE}:latest
    docker push ${DOCKER_REGISTRY}/${UBUNTU_IMAGE}:latest
    print_success "Ubuntu image pushed to GCP"
    
    # Tag and push Jenkins image
    docker tag ${JENKINS_IMAGE}:latest ${DOCKER_REGISTRY}/${JENKINS_IMAGE}:latest
    docker push ${DOCKER_REGISTRY}/${JENKINS_IMAGE}:latest
    print_success "Jenkins image pushed to GCP"
    
    # Tag and push Ansible image
    docker tag ${ANSIBLE_IMAGE}:latest ${DOCKER_REGISTRY}/${ANSIBLE_IMAGE}:latest
    docker push ${DOCKER_REGISTRY}/${ANSIBLE_IMAGE}:latest
    print_success "Ansible image pushed to GCP"
    
    print_success "All images deployed to GCP successfully"
}

# Function to run full CI/CD pipeline
run_full_pipeline() {
    print_status "Running full CI/CD pipeline..."
    check_prerequisites
    setup_python_env
    run_linting
    run_tests
    build_docker_images
    deploy_to_gcp
    print_success "Full pipeline completed successfully"
}

# Function to clean up
cleanup() {
    print_status "Cleaning up..."
    
    # Remove dangling Docker images
    docker image prune -f
    
    # Clean Python cache
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Function to show help
show_help() {
    echo "ETL Project Task Runner"
    echo ""
    echo "Usage: ./run_tasks.sh [TASK] [OPTIONS]"
    echo ""
    echo "=== LOCAL DEVELOPMENT TASKS ==="
    echo "  setup           - Setup Python environment"
    echo "  lint            - Run code linting and formatting checks"
    echo "  test            - Run pytest tests"
    echo "  jupyter         - Start Jupyter notebook server"
    echo "  dev-build       - Build Ubuntu image for local development"
    echo "  dev-run         - Run Ubuntu container locally with volume mounts"
    echo ""
    echo "=== PRODUCTION/CI-CD TASKS ==="
    echo "  build           - Build all Docker images (ubuntu, jenkins, ansible)"
    echo "  deploy          - Deploy images to GCP Container Registry"
    echo "  pipeline        - Run full CI/CD pipeline"
    echo ""
    echo "=== UTILITY TASKS ==="
    echo "  cleanup         - Clean up temporary files and Docker images"
    echo "  help            - Show this help message"
    echo ""
    echo "Local development workflow:"
    echo "  1. ./run_tasks.sh setup          # Setup Python environment"
    echo "  2. ./run_tasks.sh jupyter        # Start Jupyter for data exploration"
    echo "  3. ./run_tasks.sh test           # Run tests"
    echo "  4. ./run_tasks.sh dev-build      # Build Ubuntu image"
    echo "  5. ./run_tasks.sh dev-run        # Test ETL in Ubuntu container"
    echo ""
    echo "Production deployment:"
    echo "  ./run_tasks.sh pipeline          # Full CI/CD pipeline"
    echo ""
    echo "Note: Update DOCKER_REGISTRY variable with your GCP project ID"
}

# Main script logic
case "${1:-help}" in
    setup)
        setup_python_env
        ;;
    lint)
        setup_python_env
        run_linting
        ;;
    test)
        setup_python_env
        run_tests
        ;;
    dev-build)
        check_prerequisites
        build_ubuntu_image
        ;;
    dev-run)
        check_prerequisites
        run_ubuntu_container
        ;;
    build)
        check_prerequisites
        build_docker_images
        ;;
    deploy)
        check_prerequisites
        deploy_to_gcp
        ;;
    pipeline)
        run_full_pipeline
        ;;
    cleanup)
        cleanup
        ;;
    jupyter)
        print_status "Starting Jupyter notebook..."
        ./run_jupyter.sh
        ;;
    help)
        show_help
        ;;
    *)
        print_error "Unknown task: $1"
        show_help
        exit 1
        ;;
esac
