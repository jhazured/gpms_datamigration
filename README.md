# GPMS Data Migration

A modular ETL framework for migrating and reporting on GPMS data. Uses **YAML/Jinja** configurations, Python ETL modules, and Dockerized development and testing environments.

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

---

## Setup

### 1. Clone the repo  
git clone https://github.com/jhazured/gpms_datamigration.git  
cd gpms_datamigration

### 2. Build and run with Docker Compose  
docker-compose up --build

### 3. Adding a new ETL job  
- Create a new YAML or YAML/Jinja config in the `etls/` folder.  
- Follow the structure of the existing templates (e.g., `customer_sales_summary.yaml.j2`).  
- Reference the new config in `framework/main.py` or your orchestration tool.

### 4. Run an ETL  
Use the helper script to start a Docker session with the ETL environment:  
bash scripts/run_bash.sh  
Once inside the Docker session, you can:  
cd jobs-output  
ls -l  
cat customer_order_frequency.txt  
grep "search_term" *.txt

### 5. Run tests  
Run all tests with the helper script:  
bash scripts/run_pytest.sh etls/customer_order_frequency

---

## CI/CD  
- Jenkins pipeline is defined in the `Jenkinsfile`.  
- Uses `Dockerfile.jenkins` for the pipeline build environment.

---

## Notes  
- **Do NOT** commit secrets — store credentials securely and use environment variables.  
- Use `.gitignore` to exclude `__pycache__`, `.env`, and other local-only files.

---

## Contact  
For questions, open an issue or contact the repo owner.

---

If you want me to format anything else or add more sections, just let me know!
