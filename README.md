# gcp_datamigration

ETL data migration project for Google Cloud Platform using Apache Spark and Dataflow. This project leverages **Ansible**, **Docker**, and **Jenkins** to automate ETL job deployment and execution in a reproducible and scalable manner.

---

## Features

- Declarative ETL job definitions using Jinja2 templates.
- Automated ETL job deployment and execution via Ansible playbooks.
- Dockerized environments for ETL processing and deployment automation.
- Jenkins pipeline integration for CI/CD of ETL jobs and execution workflows.
- Support for multiple environments (dev, test, uat, prod).
- GCP Dataflow integration for scalable data processing.
- Automated testing and data quality validation.
- Secure handling of GCP credentials and job parameters.

---

## Project Structure

```plaintext
gcp_datamigration/
├── README.md
├── ansible
│   ├── ansible.cfg
│   ├── group_vars
│   │   └── all.yml
│   ├── inventory
│   │   └── localhost.yml
│   ├── playbooks
│   │   └── deploy.yml
│   ├── requirements.yml
│   ├── roles
│   │   ├── docker_build_push
│   │   │   ├── defaults
│   │   │   │   └── main.yml
│   │   │   └── tasks
│   │   │       ├── build.yml
│   │   │       ├── push.yml
│   │   │       └── tag.yml
│   │   ├── docker_management
│   │   │   └── tasks
│   │   │       └── main.yml
│   │   ├── env_variables
│   │   │   └── tasks
│   │   │       └── main.yml
│   │   └── secrets_manager
│   │       └── tasks
│   │           └── main.yml
│   └── templates
├── config
│   ├── app.conf
│   ├── log4j.properties
│   └── spark-defaults.conf
├── data
├── docker
│   ├── Dockerfile.ansible
│   └── Dockerfile.ubuntu
├── docker-compose.yml
├── documentation
│   ├── images
│   └── sequence_diagram.txt
├── env
├── etls
│   ├── customer_order_frequency.yaml.j2
│   ├── customer_sales_summary.yaml.j2
│   ├── product_inventory_report.yaml.j2
│   └── product_sales_summary.yaml.j2
├── framework
│   ├── __init__.py
│   ├── config.py
│   ├── etl.py
│   ├── extract.py
│   ├── load.py
│   ├── main.py
│   ├── transform.py
│   └── utils.py
├── jenkins
│   ├── Jenkinsfile
│   ├── Jenkinsfile.execution
│   ├── etl_groups.groovy
│   └── shared
│       ├── gcp_utils.groovy
│       └── notification_utils.groovy
├── logs
├── makefile
├── requirements
│   ├── dev.txt
│   ├── prod.txt
│   ├── test.txt
│   └── uat.txt
├── scripts
│   ├── delete_etl.sh
│   ├── deploy_etl.sh
│   ├── run_bash.sh
│   ├── run_pytest.sh
│   ├── tasks.sh
│   └── trigger_gcp_run.sh
├── tests
│   ├── __init__.py
│   ├── test_etl.py
│   ├── test_utils.py
│   └── testdata
└── wheels
    ├── README.md
    ├── __init__.py
    ├── custom
    └── vendor
```

---

## Prerequisites

- Jenkins with Docker and GCP CLI installed.
- Google Cloud project with necessary APIs enabled:
  - Cloud Dataflow
  - Cloud Storage
  - Cloud Scheduler
  - Container Registry
  - Secret Manager
  - IAM
- A Google Cloud Service Account with the following roles:
  - Dataflow Admin
  - Storage Admin
  - Secret Manager Accessor
  - Service Account User
- Jenkins credentials configured to securely store the Service Account JSON key.

---

## Scripts

The scripts/ directory includes helper scripts used during local development or Jenkins pipeline runs:

1. **deploy_etl.sh**
   - Wrapper script to deploy ETL jobs using Ansible playbooks inside Docker containers.
   - Supports dynamic environment (ENV) and action (ACTION) parameters for modular deployment tasks.

2. **trigger_gcp_run.sh**
   - Executes ETL jobs on GCP Dataflow with specified parameters.
   - Handles job monitoring and status reporting.

3. **delete_etl.sh**
   - Removes deployed ETL jobs from GCP Dataflow.
   - Useful for cleanup operations during development or teardown.

4. **run_pytest.sh**
   - Executes the test suite with appropriate configurations.
   - Generates test reports and coverage metrics.

These scripts are primarily used by Jenkins or local developers to trigger automated steps consistently without needing to manually execute Docker or Ansible commands.

---

## Jenkins Pipelines

There are two main Jenkinsfiles for different aspects of the ETL workflow:

### Jenkinsfile (Deployment Pipeline)

A comprehensive Jenkins pipeline for ETL job deployment and management:

1. **init** – Initialize deployment environment and validate prerequisites.
2. **deploy-single-glue-job** – Deploy a specific ETL job to the target environment.
3. **bulk-deploy-glue-job** – Deploy all ETL jobs in batch mode.
4. **deploy-playbook** – Execute custom Ansible playbooks for specialized deployments.
5. **delete-single-glue-job** – Remove a specific ETL job from the environment.

### Jenkinsfile.execution (Execution Pipeline)

A dedicated Jenkins pipeline for ETL job execution and monitoring:

1. **run-single-etl** – Execute a single ETL job with specified parameters.
2. **run-bulk-etl** – Execute multiple ETL jobs in parallel.
3. **run-scheduled-batch** – Set up scheduled execution using Cloud Scheduler.
4. **cancel-running-jobs** – Cancel currently running ETL jobs.

---

## Setup Instructions

1. Configure Jenkins and load the pipelines from jenkins/Jenkinsfile and jenkins/Jenkinsfile.execution.
2. Add your GCP Service Account JSON key as a Secret file credential in Jenkins with an ID (e.g., gcp-service-account-key).
3. Run the deployment pipeline steps in order:
   - init
   - deploy-single-glue-job or bulk-deploy-glue-job
4. Use the execution pipeline to run ETL jobs:
   - run-single-etl or run-bulk-etl

---

## Pipeline Actions

### Deployment Pipeline Actions

The deployment pipeline consists of actions that manage ETL job lifecycle:

| ACTION                    | Description                                                  |
|---------------------------|--------------------------------------------------------------|
| init                      | Initialize deployment environment, validate GCP credentials and prepare Docker images. |
| deploy-single-glue-job    | Deploy a specific ETL job template to GCP Dataflow with environment-specific configurations. |
| bulk-deploy-glue-job      | Deploy all available ETL jobs to the target environment in batch mode. |
| deploy-playbook           | Execute custom Ansible playbooks for specialized deployment scenarios. |
| delete-single-glue-job    | Remove a specific ETL job from GCP Dataflow and clean up associated resources. |

### Execution Pipeline Actions

The execution pipeline manages ETL job runtime operations:

| ACTION                    | Description                                                  |
|---------------------------|--------------------------------------------------------------|
| run-single-etl            | Execute a single ETL job with specified parameters and monitor completion. |
| run-bulk-etl              | Execute multiple ETL jobs in parallel with centralized monitoring. |
| run-scheduled-batch       | Create Cloud Scheduler jobs for automated ETL execution. |
| cancel-running-jobs       | Cancel currently running ETL jobs and perform cleanup. |

These actions are triggered by Jenkins with parameters:

- **ENV**: Target environment (dev, test, uat, prod)
- **ACTION**: Desired action from the tables above
- **etl_obj/etl_job**: Specific ETL job name
- **job_parameters**: JSON parameters for job execution

### How These Actions Work Together

1. **init** prepares the deployment environment and validates all prerequisites.
2. **deploy-single-glue-job** or **bulk-deploy-glue-job** deploys ETL job templates to GCP Dataflow.
3. **run-single-etl** or **run-bulk-etl** executes the deployed jobs with runtime parameters.
4. **run-scheduled-batch** sets up automated execution schedules.
5. **delete-single-glue-job** cleans up jobs when no longer needed.

This sequence ensures a clean, reliable, and automated lifecycle for your ETL jobs, with Ansible handling deployment orchestration and GCP Dataflow managing job execution.

---

## ETL Jobs

The project includes pre-configured ETL job templates in the etls/ directory:

Each ETL job is defined as a Jinja2 template that gets rendered with environment-specific variables during deployment.

---

## Framework

The framework/ directory contains the core ETL processing logic:

- **config.py**: Configuration management and environment variable handling.
- **etl.py**: Main ETL orchestration and workflow management.
- **extract.py**: Data extraction utilities for various sources.
- **transform.py**: Data transformation and processing functions.
- **load.py**: Data loading utilities for target systems.
- **utils.py**: Common utilities and helper functions.
- **main.py**: Entry point for ETL job execution.

The framework is designed to be modular and extensible, supporting various data sources and targets.

---

## Ansible

Ansible is responsible for deployment automation and configuration management:

- **Deployment Orchestration**: Managing ETL job deployment to GCP Dataflow.
- **Environment Configuration**: Setting up environment-specific configurations and secrets.
- **Docker Management**: Building and managing Docker images for ETL execution.
- **Resource Cleanup**: Automated cleanup of deployed resources.

Ansible runs inside the Docker container defined by docker/Dockerfile.ansible.

---

## Docker Images

The following images are built and managed:

1. **gpms_deploy_prep:latest** – Deployment preparation and Ansible automation runner
2. **ubuntu-etl:latest** – Runtime environment for ETL job execution

They are built from docker/Dockerfile.* files and used for consistent execution environments.

---

## Testing

The project includes comprehensive testing:

- **Unit Tests**: Framework component testing in tests/test_*.py
- **Integration Tests**: End-to-end ETL job testing
- **Data Quality Tests**: Validation of ETL output data
- **Performance Tests**: ETL job performance benchmarking

Run tests using:
```bash
./scripts/run_pytest.sh
```

---

## Secrets & Credentials

- Secrets are stored in GCP Secret Manager
- Service account keys are injected into Jenkins via withCredentials
- Environment variables managed through Ansible templates
- Job parameters passed securely through Jenkins pipeline parameters

---

## Best Practices

- Use environment-specific configurations and templates
- Run delete-single-glue-job before removing infrastructure
- Keep Jenkins credentials scoped and secure
- Dockerize your ETL runtime for consistency
- Monitor job execution through GCP Console
- Use Ansible roles for maintainable playbooks
- Implement proper error handling and retry logic
- Regular testing of ETL jobs across environments

---

## Troubleshooting

- Check GCP IAM permissions and API enablement
- Validate Dataflow job logs in GCP Console
- Review Jenkins pipeline console output for errors
- Ensure Docker containers have proper resource allocation
- Verify ETL job template syntax and parameters
- Monitor GCP quotas and limits
- Check network connectivity for data sources

---

## Contribution

Feel free to open issues or submit pull requests to improve this project.