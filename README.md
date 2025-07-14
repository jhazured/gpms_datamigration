# GCP Data Migration

A modular ETL framework for migrating Google Cloud Platform data. Uses **YAML/Jinja** configurations, Python ETL modules, and Dockerized development and testing environments.

---

## Project Structure

├── etls/                 # YAML/Jinja templates for ETL jobs  
├── framework/            # ETL framework code (extract, transform, load, utils)  
├── tests/                # Unit tests and test data  
├── requirements/         # Python dependencies for different environments  
├── docker/               # Dockerfiles for dev, Jupyter, CI/CD  
├── scripts/              # Helper scripts for local development and testing  
├── Dockerfile.jenkins    # Dockerfile for Jenkins pipeline  
├── Jenkinsfile           # Jenkins pipeline definition  
├── docker-compose.yml    # Multi-container development/test environment  
├── ansible/  
├── deploy.yml            # Main playbook  
├── inventory             # Inventory file (optional, localhost used)  
├── ansible.cfg           # Ansible config (optional)  
└── roles/  
    └── docker_build_push/  
        ├── tasks/  
        │   ├── build.yml  
        │   ├── tag.yml  
        │   ├── push.yml  
        │   └── main.yml  
        └── defaults/  
            └── main.yml

---

## Setup

### 1. Clone the repo  

```bash
git clone https://github.com/jhazured/gcp_datamigration.git  
cd gpms_datamigration

2. Build and run with Docker Compose

- docker-compose up --build

3. Adding a new ETL job
- Create a new YAML or YAML/Jinja config in the etls/ folder.
- Follow the structure of the existing templates (e.g., customer_sales_summary.yaml.j2).
- Reference the new config in framework/main.py or your orchestration tool.

4. Run an ETL
- Use the helper script to start a Docker session with the ETL environment:
- scripts/run_bash.sh
- Once inside the Docker session, you can:
- cd jobs-output  ls -l  cat customer_order_frequency.txt

5. Run tests
- Run all tests with the helper script:
- scripts/run_pytest.sh etls/customer_order_frequency

CI/CD
- Jenkins pipeline is defined in the Jenkinsfile.
- Uses Dockerfile.jenkins for the pipeline build environment.

Notes
- Do NOT commit secrets — store credentials securely and use environment variables.
- Use .gitignore to exclude __pycache__, .env, and other local-only files.

Prerequisites
# Docker installed on the machine running Ansible
# Docker logged in to your GCP Artifact Registry (run gcloud auth configure-docker)
# Ansible installed with community.general collection for docker_image module
# Install with: ansible-galaxy collection install community.general

Configuration_Variables
# Default variables are defined in roles/docker_build_push/defaults/main.yml:
- env:          "dev"                        #Environment to build (dev/prod)	
- project_id:   "my-gcp-project"             #GCP Project ID
- region:       "australia-southeast1"       #GCP Artifact Registry region	
- repository:   "my-repo"                    #Artifact Registry Docker repository
- image_name:   "my_etl_image"               #Docker image name	

#Override any of these in your playbook or via --extra-vars CLI argument.

Running_the_Playbook
- From your project root, run: ansible-playbook ansible/deploy.yml --extra-vars "env=prod"

#This will:
    # Build the Docker image using the appropriate Dockerfile for the given environment.
    #Tag the image to point to your Artifact Registry repo.
    #Push the image to GCP Artifact Registry.

Role_Task_Breakdown
- build.yml
#Uses community.general.docker_image to build the image without cache, pulling latest base images.

- tag.yml
#Tags the local Docker image with the Artifact Registry fully qualified name.

- push.yml
#Pushes the tagged image to GCP Artifact Registry.

- main.yml
#Includes the above tasks in order for a smooth pipeline.

Notes
#Ensure your GCP credentials have permissions to push images to Artifact Registry.
#The docker build context is set to the project root relative to your playbook.
#The role supports dev and prod environments by default; extend Dockerfile logic in the role if you add more environments.

Troubleshooting
#Docker login issues: Run gcloud auth configure-docker and verify login.
#Ansible module missing: Ensure the community.general collection is installed.
#File paths: Verify the Dockerfiles exist at the configured paths:
#docker/Dockerfile.dev-ubuntu
#Dockerfile.jenkins

Permissions: 
#Run Ansible with sufficient privileges if needed.

Contact
#For questions, open an issue or contact the repo owner.