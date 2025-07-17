# Main execution
print_colored $GREEN "Starting pytest execution for GCP Data Migration Project"
print_colored $BLUE "Environment: ${ENVIRONMENT}"
print_colored $BLUE "Test Path: ${TEST_PATH:-"All tests"}"
print_colored $BLUE "Output Directory: ${OUTPUT_DIR}"

# Handle special modes first
if [[ "${DOCKER_CLEAN}" == "true" ]]; then
    manage_docker_services "clean"
    exit 0
fi

if [[ "${DOCKER_STATUS}" == "true" ]]; then#!/bin/bash

# run_pytest.sh - Comprehensive pytest runner for GCP Data Migration Project
# Supports Docker, Jenkins, and Ansible environments
# Usage: ./run_pytest.sh [OPTIONS] [test_path]

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Default values
DEFAULT_ENV="dev"
DEFAULT_PYTEST_ARGS=""
DEFAULT_OUTPUT_DIR="${PROJECT_ROOT}/test-results"
DEFAULT_COVERAGE_DIR="${PROJECT_ROOT}/coverage"
DEFAULT_REQUIREMENTS_FILE="${PROJECT_ROOT}/requirements/requirements-test.txt"

# Environment detection
IS_DOCKER=${IS_DOCKER:-false}
IS_JENKINS=${JENKINS_URL:+true}
IS_ANSIBLE=${ANSIBLE_PLAYBOOK:+true}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print usage
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [test_path]

OPTIONS:
    -e, --env ENV           Environment (dev/test/prod) [default: ${DEFAULT_ENV}]
    -c, --coverage          Generate coverage report
    -x, --xml               Generate XML test reports (JUnit format)
    -h, --html              Generate HTML coverage report
    -v, --verbose           Verbose pytest output
    -k, --keyword PATTERN   Run tests matching keyword pattern
    -m, --marker MARKER     Run tests with specific marker
    -p, --parallel          Run tests in parallel (pytest-xdist)
    -s, --no-capture        Don't capture stdout (show print statements)
    -f, --failfast          Stop on first failure
    -r, --requirements FILE Custom requirements file
    -o, --output-dir DIR    Output directory for reports [default: ${DEFAULT_OUTPUT_DIR}]
    --clean                 Clean previous test results
    --docker                Force Docker mode
    --jenkins               Force Jenkins mode
    --ansible               Force Ansible mode
    --dev                   Run in development mode (interactive)
    --dev-shell             Start interactive development shell
    --jupyter               Start Jupyter notebook
    --docker-clean          Clean Docker volumes and containers
    --docker-status         Show Docker Compose services status
    --docker-logs           Show Docker Compose logs
    --help                  Show this help message

EXAMPLES:
    $0                                    # Run all tests
    $0 tests/unit                         # Run unit tests only
    $0 tests/integration                  # Run integration tests
    $0 -c -x -v                          # Run with coverage, XML output, verbose
    $0 -k "test_etl" -m "slow"           # Run tests matching pattern with marker
    $0 --env prod --parallel             # Run in prod env with parallel execution
    $0 etls/customer_order_frequency     # Run tests for specific ETL
    $0 --docker -c -x                    # Run in Docker with coverage and XML
    $0 --dev                             # Run in development mode
    $0 --dev-shell                       # Start interactive development shell
    $0 --jupyter                         # Start Jupyter notebook
    $0 --docker-clean                    # Clean Docker resources
    $0 --docker-status                   # Show Docker services status

ENVIRONMENT VARIABLES:
    PYTEST_ARGS                Additional pytest arguments
    GCP_PROJECT_ID             GCP Project ID for integration tests
    GCP_CREDENTIALS_FILE       Path to GCP service account credentials
    SPARK_HOME                 Spark installation directory
    JAVA_HOME                  Java installation directory
    LOCAL_UID                  Local user ID for Docker (default: 1000)
    LOCAL_GID                  Local group ID for Docker (default: 1000)
    
DOCKER COMPOSE PROFILES:
    test                       Test environment with etl_test and test_db
    dev                        Development environment with etl_dev
    ci                         CI/CD environment (includes test profile)
    jupyter                    Jupyter notebook environment
    
EOF
}

# Function to setup environment
setup_environment() {
    print_colored $BLUE "Setting up test environment..."
    
    # Create output directories
    mkdir -p "${OUTPUT_DIR}"
    mkdir -p "${COVERAGE_DIR}"
    mkdir -p "${PROJECT_ROOT}/logs"
    
    # Set environment variables
    export PYTHONPATH="${PROJECT_ROOT}:${PROJECT_ROOT}/framework:${PYTHONPATH}"
    export PYSPARK_PYTHON=python3
    export PYSPARK_DRIVER_PYTHON=python3
    
    # GCP specific environment
    if [[ -n "${GCP_CREDENTIALS_FILE}" && -f "${GCP_CREDENTIALS_FILE}" ]]; then
        export GOOGLE_APPLICATION_CREDENTIALS="${GCP_CREDENTIALS_FILE}"
    fi
    
    # Spark configuration for testing
    export SPARK_CONF_DIR="${PROJECT_ROOT}/conf"
    export SPARK_LOCAL_IP="127.0.0.1"
    
    # Set test-specific environment variables
    export TESTING=true
    export ENV="${ENVIRONMENT}"
    export LOG_LEVEL="INFO"
    
    print_colored $GREEN "Environment setup complete"
}

# Function to install dependencies
install_dependencies() {
    print_colored $BLUE "Installing test dependencies..."
    
    if [[ -f "${REQUIREMENTS_FILE}" ]]; then
        python3 -m pip install -r "${REQUIREMENTS_FILE}"
    else
        print_colored $YELLOW "Warning: Requirements file not found: ${REQUIREMENTS_FILE}"
    fi
    
    # Install additional test dependencies
    python3 -m pip install pytest pytest-cov pytest-xdist pytest-html pytest-mock
    
    print_colored $GREEN "Dependencies installed"
}

# Function to validate environment
validate_environment() {
    print_colored $BLUE "Validating test environment..."
    
    # Check Python version
    python3 --version || {
        print_colored $RED "Error: Python3 not found"
        exit 1
    }
    
    # Check if we're in the correct directory
    if [[ ! -f "${PROJECT_ROOT}/framework/main.py" ]]; then
        print_colored $RED "Error: Not in project root or framework directory missing"
        exit 1
    fi
    
    # Check for test directory
    if [[ ! -d "${PROJECT_ROOT}/tests" ]]; then
        print_colored $RED "Error: Tests directory not found"
        exit 1
    fi
    
    # Check GCP credentials for integration tests
    if [[ "${TEST_PATH}" == *"integration"* ]] && [[ -z "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
        print_colored $YELLOW "Warning: No GCP credentials set for integration tests"
    fi
    
    print_colored $GREEN "Environment validation complete"
}

# Function to clean previous results
clean_results() {
    if [[ "${CLEAN}" == "true" ]]; then
        print_colored $BLUE "Cleaning previous test results..."
        rm -rf "${OUTPUT_DIR}"/*
        rm -rf "${COVERAGE_DIR}"/*
        rm -rf "${PROJECT_ROOT}/.pytest_cache"
        rm -rf "${PROJECT_ROOT}/.coverage"
        find "${PROJECT_ROOT}" -name "*.pyc" -delete
        find "${PROJECT_ROOT}" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
        print_colored $GREEN "Previous results cleaned"
    fi
}

# Function to build pytest command
build_pytest_command() {
    local cmd="python3 -m pytest"
    
    # Add test path
    if [[ -n "${TEST_PATH}" ]]; then
        cmd="${cmd} ${TEST_PATH}"
    else
        cmd="${cmd} tests/"
    fi
    
    # Add coverage options
    if [[ "${COVERAGE}" == "true" ]]; then
        cmd="${cmd} --cov=framework --cov=etls --cov-report=term-missing"
        
        # For Docker, use container paths; for local, use host paths
        if [[ "${IS_DOCKER}" == "true" ]]; then
            cmd="${cmd} --cov-report=xml:/app/data/coverage.xml"
            if [[ "${HTML_REPORT}" == "true" ]]; then
                cmd="${cmd} --cov-report=html:/app/data/coverage"
            fi
        else
            cmd="${cmd} --cov-report=xml:${COVERAGE_DIR}/coverage.xml"
            if [[ "${HTML_REPORT}" == "true" ]]; then
                cmd="${cmd} --cov-report=html:${COVERAGE_DIR}/htmlcov"
            fi
        fi
    fi
    
    # Add XML output for CI/CD
    if [[ "${XML_OUTPUT}" == "true" ]]; then
        if [[ "${IS_DOCKER}" == "true" ]]; then
            cmd="${cmd} --junitxml=/app/data/test-results.xml"
        else
            cmd="${cmd} --junitxml=${OUTPUT_DIR}/junit.xml"
        fi
    fi
    
    # Add HTML report
    if [[ "${HTML_REPORT}" == "true" && "${IS_DOCKER}" != "true" ]]; then
        cmd="${cmd} --html=${OUTPUT_DIR}/report.html --self-contained-html"
    fi
    
    # Add parallel execution
    if [[ "${PARALLEL}" == "true" ]]; then
        cmd="${cmd} -n auto"
    fi
    
    # Add verbose output
    if [[ "${VERBOSE}" == "true" ]]; then
        cmd="${cmd} -v"
    else
        # Use quiet mode for Docker to reduce noise
        if [[ "${IS_DOCKER}" == "true" ]]; then
            cmd="${cmd} -q"
        fi
    fi
    
    # Add no capture
    if [[ "${NO_CAPTURE}" == "true" ]]; then
        cmd="${cmd} -s"
    fi
    
    # Add fail fast
    if [[ "${FAILFAST}" == "true" ]]; then
        cmd="${cmd} -x"
    else
        # For Docker, add maxfail to prevent hanging
        if [[ "${IS_DOCKER}" == "true" ]]; then
            cmd="${cmd} --maxfail=3"
        fi
    fi
    
    # Add keyword filter
    if [[ -n "${KEYWORD}" ]]; then
        cmd="${cmd} -k ${KEYWORD}"
    fi
    
    # Add marker filter
    if [[ -n "${MARKER}" ]]; then
        cmd="${cmd} -m ${MARKER}"
    fi
    
    # Add disable warnings for Docker to reduce output
    if [[ "${IS_DOCKER}" == "true" ]]; then
        cmd="${cmd} --disable-warnings"
    fi
    
    # Add custom pytest arguments
    if [[ -n "${PYTEST_ARGS}" ]]; then
        cmd="${cmd} ${PYTEST_ARGS}"
    fi
    
    echo "${cmd}"
}

# Function to run tests in Docker
run_docker_tests() {
    print_colored $BLUE "Running tests in Docker environment..."
    
    # Check if docker-compose.yml exists
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        # Ensure test database is healthy before running tests
        print_colored $BLUE "Starting test database..."
        docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile test up -d test_db
        
        # Wait for database to be ready
        print_colored $BLUE "Waiting for test database to be ready..."
        docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" exec test_db sh -c 'until pg_isready -U test_user -d test_etl; do sleep 1; done'
        
        # Build or pull the test image
        print_colored $BLUE "Building test image..."
        docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile test build etl_test
        
        # Create custom pytest command for docker-compose
        local pytest_cmd=$(build_pytest_command)
        
        # Override docker-compose command with our custom pytest command
        print_colored $BLUE "Running tests with command: ${pytest_cmd}"
        docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile test run --rm \
            -e TESTING=true \
            -e ENV="${ENVIRONMENT}" \
            -e LOCAL_UID="$(id -u)" \
            -e LOCAL_GID="$(id -g)" \
            etl_test bash -c "${pytest_cmd}"
        
        # Copy results from container volume to host
        print_colored $BLUE "Copying test results..."
        docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile test run --rm \
            -v "${OUTPUT_DIR}:/host_output" \
            -v "${COVERAGE_DIR}:/host_coverage" \
            etl_test bash -c "
                cp -r /app/data/test-results.xml /host_output/ 2>/dev/null || true
                cp -r /app/data/coverage.xml /host_coverage/ 2>/dev/null || true
                cp -r /app/data/coverage /host_coverage/htmlcov 2>/dev/null || true
            "
        
        # Clean up
        print_colored $BLUE "Cleaning up containers..."
        docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile test down
        
    else
        # Fallback to direct docker run
        print_colored $YELLOW "No docker-compose.yml found, using direct docker run..."
        docker run --rm \
            -v "${PROJECT_ROOT}:/app" \
            -v "${OUTPUT_DIR}:/app/test-results" \
            -v "${COVERAGE_DIR}:/app/coverage" \
            -w /app \
            -e TESTING=true \
            -e ENV="${ENVIRONMENT}" \
            python:3.9-slim \
            bash -c "pip install -r requirements/requirements-test.txt && $(build_pytest_command)"
    fi
}

# Function to run tests locally
run_local_tests() {
    print_colored $BLUE "Running tests locally..."
    
    setup_environment
    install_dependencies
    validate_environment
    clean_results
    
    local cmd=$(build_pytest_command)
    print_colored $BLUE "Executing: ${cmd}"
    
    eval "${cmd}"
}

# Function to handle Jenkins environment
setup_jenkins_environment() {
    print_colored $BLUE "Configuring Jenkins environment..."
    
    # Jenkins-specific configurations
    export JENKINS_BUILD=true
    export BUILD_NUMBER="${BUILD_NUMBER:-unknown}"
    export BUILD_URL="${BUILD_URL:-unknown}"
    
    # Force XML output for Jenkins
    XML_OUTPUT=true
    COVERAGE=true
    
    # Create Jenkins-specific directories
    mkdir -p "${WORKSPACE}/test-results"
    mkdir -p "${WORKSPACE}/coverage"
    OUTPUT_DIR="${WORKSPACE}/test-results"
    COVERAGE_DIR="${WORKSPACE}/coverage"
}

# Function to handle Ansible environment
setup_ansible_environment() {
    print_colored $BLUE "Configuring Ansible environment..."
    
    # Ansible-specific configurations
    export ANSIBLE_MANAGED=true
    
    # Use absolute paths for Ansible
    OUTPUT_DIR="${PROJECT_ROOT}/test-results"
    COVERAGE_DIR="${PROJECT_ROOT}/coverage"
}

# Function to manage Docker Compose services
manage_docker_services() {
    local action=$1
    
    case $action in
        "start")
            print_colored $BLUE "Starting Docker Compose services..."
            docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile test up -d
            ;;
        "stop")
            print_colored $BLUE "Stopping Docker Compose services..."
            docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile test down
            ;;
        "clean")
            print_colored $BLUE "Cleaning Docker Compose resources..."
            docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile test down -v
            docker volume prune -f
            ;;
        "status")
            print_colored $BLUE "Docker Compose services status:"
            docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile test ps
            ;;
        "logs")
            print_colored $BLUE "Docker Compose logs:"
            docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile test logs
            ;;
    esac
}

# Function to run development mode tests
run_dev_tests() {
    print_colored $BLUE "Running tests in development mode..."
    
    # Start dev environment
    docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile dev up -d etl_dev test_db
    
    # Wait for services to be ready
    print_colored $BLUE "Waiting for services to be ready..."
    sleep 10
    
    # Run tests inside the dev container
    local pytest_cmd=$(build_pytest_command)
    docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile dev exec etl_dev bash -c "${pytest_cmd}"
    
    # Copy results if needed
    if [[ "${IS_DOCKER}" == "true" ]]; then
        docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile dev exec etl_dev bash -c "
            mkdir -p /app/test-results /app/coverage
            cp -r /app/data/test-results.xml /app/test-results/ 2>/dev/null || true
            cp -r /app/data/coverage.xml /app/coverage/ 2>/dev/null || true
            cp -r /app/data/coverage /app/coverage/htmlcov 2>/dev/null || true
        "
    fi
}

# Function to run interactive development shell
run_dev_shell() {
    print_colored $BLUE "Starting interactive development shell..."
    
    # Start dev environment
    docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile dev up -d etl_dev test_db
    
    # Wait for services to be ready
    sleep 5
    
    # Open interactive shell
    docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile dev exec etl_dev bash
}

# Function to start Jupyter notebook
start_jupyter() {
    print_colored $BLUE "Starting Jupyter notebook..."
    
    # Start Jupyter service
    docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" --profile jupyter up -d jupyter test_db
    
    # Wait for services to be ready
    sleep 10
    
    print_colored $GREEN "Jupyter notebook is running at: http://localhost:8888"
    print_colored $YELLOW "Note: No token required (configured for development)"
}

# Function to check Docker Compose setup
check_docker_setup() {
    print_colored $BLUE "Checking Docker Compose setup..."
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_colored $RED "Error: Docker is not running"
        return 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null; then
        print_colored $RED "Error: docker-compose not found"
        return 1
    fi
    
    # Check if docker-compose.yml exists
    if [[ ! -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        print_colored $RED "Error: docker-compose.yml not found"
        return 1
    fi
    
    # Validate docker-compose configuration
    if ! docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" config &> /dev/null; then
        print_colored $RED "Error: Invalid docker-compose.yml configuration"
        return 1
    fi
    
    # Check if required Dockerfiles exist
    if [[ ! -f "${PROJECT_ROOT}/docker/Dockerfile.ubuntu" ]]; then
        print_colored $RED "Error: docker/Dockerfile.ubuntu not found"
        return 1
    fi
    
    # Check if environment files exist
    if [[ ! -f "${PROJECT_ROOT}/env/.env.test" ]]; then
        print_colored $YELLOW "Warning: env/.env.test not found"
    fi
    
    print_colored $GREEN "Docker Compose setup is valid"
    return 0
}

# Function to display results summary
display_results() {
    print_colored $GREEN "Test execution completed!"
    
    # Check for results in different locations based on execution mode
    local junit_xml=""
    local coverage_xml=""
    local coverage_html=""
    local test_report=""
    
    if [[ "${IS_DOCKER}" == "true" ]]; then
        junit_xml="${OUTPUT_DIR}/test-results.xml"
        coverage_xml="${COVERAGE_DIR}/coverage.xml"
        coverage_html="${COVERAGE_DIR}/htmlcov"
    else
        junit_xml="${OUTPUT_DIR}/junit.xml"
        coverage_xml="${COVERAGE_DIR}/coverage.xml"
        coverage_html="${COVERAGE_DIR}/htmlcov"
        test_report="${OUTPUT_DIR}/report.html"
    fi
    
    if [[ -f "${junit_xml}" ]]; then
        print_colored $BLUE "JUnit XML report: ${junit_xml}"
        
        # Parse and display test summary from JUnit XML
        if command -v xmllint &> /dev/null; then
            local tests=$(xmllint --xpath "//testsuite/@tests" "${junit_xml}" 2>/dev/null | grep -o '[0-9]*' || echo "unknown")
            local failures=$(xmllint --xpath "//testsuite/@failures" "${junit_xml}" 2>/dev/null | grep -o '[0-9]*' || echo "0")
            local errors=$(xmllint --xpath "//testsuite/@errors" "${junit_xml}" 2>/dev/null | grep -o '[0-9]*' || echo "0")
            local skipped=$(xmllint --xpath "//testsuite/@skipped" "${junit_xml}" 2>/dev/null | grep -o '[0-9]*' || echo "0")
            
            print_colored $BLUE "Test Summary: ${tests} tests, ${failures} failures, ${errors} errors, ${skipped} skipped"
        fi
    fi
    
    if [[ -f "${test_report}" ]]; then
        print_colored $BLUE "HTML test report: ${test_report}"
    fi
    
    if [[ -f "${coverage_xml}" ]]; then
        print_colored $BLUE "Coverage XML: ${coverage_xml}"
    fi
    
    if [[ -d "${coverage_html}" ]]; then
        print_colored $BLUE "Coverage HTML: ${coverage_html}/index.html"
    fi
    
    # Display coverage summary if available
    if [[ -f ".coverage" ]]; then
        print_colored $BLUE "Coverage Summary:"
        python3 -m coverage report --show-missing | tail -3
    fi
    
    # Display Docker-specific information
    if [[ "${IS_DOCKER}" == "true" ]]; then
        print_colored $BLUE "Docker test data volume: test_data"
        print_colored $BLUE "Docker test cache volume: test_cache"
        print_colored $YELLOW "Note: Test results are copied from Docker volumes to host directories"
    fi
}

# Parse command line arguments
DEV_MODE=false
DEV_SHELL=false
JUPYTER_MODE=false
DOCKER_CLEAN=false
DOCKER_STATUS=false
DOCKER_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -x|--xml)
            XML_OUTPUT=true
            shift
            ;;
        -h|--html)
            HTML_REPORT=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -k|--keyword)
            KEYWORD="$2"
            shift 2
            ;;
        -m|--marker)
            MARKER="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        -s|--no-capture)
            NO_CAPTURE=true
            shift
            ;;
        -f|--failfast)
            FAILFAST=true
            shift
            ;;
        -r|--requirements)
            REQUIREMENTS_FILE="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --docker)
            IS_DOCKER=true
            shift
            ;;
        --jenkins)
            IS_JENKINS=true
            shift
            ;;
        --ansible)
            IS_ANSIBLE=true
            shift
            ;;
        --dev)
            DEV_MODE=true
            IS_DOCKER=true
            shift
            ;;
        --dev-shell)
            DEV_SHELL=true
            shift
            ;;
        --jupyter)
            JUPYTER_MODE=true
            shift
            ;;
        --docker-clean)
            DOCKER_CLEAN=true
            shift
            ;;
        --docker-status)
            DOCKER_STATUS=true
            shift
            ;;
        --docker-logs)
            DOCKER_LOGS=true
            shift
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            if [[ -z "${TEST_PATH}" ]]; then
                TEST_PATH="$1"
            else
                print_colored $RED "Error: Unknown option $1"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Set default values
ENVIRONMENT=${ENVIRONMENT:-$DEFAULT_ENV}
COVERAGE=${COVERAGE:-false}
XML_OUTPUT=${XML_OUTPUT:-false}
HTML_REPORT=${HTML_REPORT:-false}
VERBOSE=${VERBOSE:-false}
PARALLEL=${PARALLEL:-false}
NO_CAPTURE=${NO_CAPTURE:-false}
FAILFAST=${FAILFAST:-false}
CLEAN=${CLEAN:-false}
REQUIREMENTS_FILE=${REQUIREMENTS_FILE:-$DEFAULT_REQUIREMENTS_FILE}
OUTPUT_DIR=${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}
COVERAGE_DIR=${COVERAGE_DIR:-$DEFAULT_COVERAGE_DIR}

# Environment-specific setup
if [[ "${IS_JENKINS}" == "true" ]]; then
    setup_jenkins_environment
elif [[ "${IS_ANSIBLE}" == "true" ]]; then
    setup_ansible_environment
fi

# Main execution
print_colored $GREEN "Starting pytest execution for GCP Data Migration Project"
print_colored $BLUE "Environment: ${ENVIRONMENT}"
print_colored $BLUE "Test Path: ${TEST_PATH:-"All tests"}"
print_colored $BLUE "Output Directory: ${OUTPUT_DIR}"

# Run tests based on environment
if [[ "${IS_DOCKER}" == "true" ]]; then
    run_docker_tests
else
    run_local_tests
fi

# Display results
display_results

print_colored $GREEN "Test execution finished successfully!"