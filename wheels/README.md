# Wheels Directory

This directory contains Python wheel files for the GCP Data Migration ETL project. Wheels are pre-compiled Python packages that enable faster installation and deployment of dependencies in containerized and cloud environments.

---

## Directory Structure

```plaintext
wheels/
├── README.md
├── __init__.py
├── custom/          # Custom wheels built from project requirements
└── vendor/          # Third-party vendor wheels and dependencies
```

---

## Purpose

The wheels directory serves several key functions:

1. **Dependency Management**: Store pre-compiled Python packages for consistent deployments across environments.
2. **Performance Optimization**: Reduce build times in Docker containers and CI/CD pipelines.
3. **Offline Installation**: Enable package installation in environments with limited internet access.
4. **Version Control**: Maintain specific versions of dependencies for reproducible builds.

---

## Directory Contents

### custom/
Contains Python wheels built from the project's requirements files:
- Wheels compiled from `requirements/dev.txt`
- Wheels compiled from `requirements/test.txt`
- Wheels compiled from `requirements/uat.txt`
- Wheels compiled from `requirements/prod.txt`

These wheels are generated during the Jenkins deployment pipeline using:
```bash
pip wheel -r requirements/${environment}.txt -w wheels/custom/
```

### vendor/
Contains third-party vendor wheels and specialized dependencies:
- External library wheels not available in standard PyPI
- Custom builds of modified packages
- Vendor-specific integrations and tools

---

## Usage

### In Docker Builds
Wheels are used during Docker image builds to speed up package installation:
```dockerfile
COPY wheels/ /wheels/
RUN pip install --find-links /wheels/ --no-index -r requirements.txt
```

### In Jenkins Pipelines
The deployment pipeline automatically compiles wheels for playbook deployments:
```groovy
stage('Compile Python Wheels') {
    when {
        expression { params.stack_action == 'deploy-playbook' }
    }
    steps {
        script {
            echo "Compiling Python wheels for playbook deployment"
            sh """
                mkdir -p wheels/custom
                pip wheel -r requirements/${params.environment}.txt -w wheels/custom/
            """
        }
    }
}
```

### Local Development
For local testing and development:
```bash
# Install from wheels directory
pip install --find-links wheels/custom/ --no-index package_name

# Or install all requirements using wheels
pip install --find-links wheels/custom/ -r requirements/dev.txt
```

---

## Building Wheels

### Automatic Building
Wheels are automatically built during Jenkins pipeline execution for playbook deployments.

### Manual Building
To manually build wheels for a specific environment:

```bash
# Create custom wheels directory
mkdir -p wheels/custom

# Build wheels for specific environment
pip wheel -r requirements/dev.txt -w wheels/custom/

# Build wheels for all environments
for env in dev test uat prod; do
    pip wheel -r requirements/${env}.txt -w wheels/custom/
done
```

### Building Vendor Wheels
For custom or vendor-specific packages:

```bash
# Build wheel from source
pip wheel /path/to/source/package -w wheels/vendor/

# Build wheel from Git repository
pip wheel git+https://github.com/user/repo.git -w wheels/vendor/

# Build wheel with specific version
pip wheel package==1.2.3 -w wheels/vendor/
```

---

## Best Practices

1. **Version Pinning**: Ensure all wheels are built with pinned versions from requirements files.
2. **Environment Separation**: Keep environment-specific wheels organized and separate.
3. **Regular Updates**: Rebuild wheels when updating dependencies or security patches.
4. **Size Management**: Regularly clean up unused or outdated wheels to manage storage.
5. **Security Scanning**: Scan wheels for vulnerabilities before deployment.

---

## Maintenance

### Cleaning Up Wheels
Remove outdated or unused wheels:
```bash
# Remove all wheels in custom directory
rm -rf wheels/custom/*

# Remove wheels older than 30 days
find wheels/ -name "*.whl" -mtime +30 -delete
```

### Updating Wheels
Update wheels when requirements change:
```bash
# Rebuild wheels after requirements update
rm -rf wheels/custom/*
pip wheel -r requirements/${ENV}.txt -w wheels/custom/
```

### Verifying Wheels
Verify wheel integrity and compatibility:
```bash
# Check wheel contents
unzip -l wheels/custom/package-1.0.0-py3-none-any.whl

# Test wheel installation
pip install --dry-run --find-links wheels/custom/ package_name
```

---

## Integration with CI/CD

The wheels directory integrates with the project's CI/CD pipeline:

1. **Build Stage**: Wheels are compiled during the deployment preparation stage.
2. **Testing**: Wheels are used in test environments to ensure consistent dependencies.
3. **Deployment**: Production deployments use pre-built wheels for faster, more reliable installations.
4. **Cleanup**: Old wheels are automatically cleaned up during pipeline execution.

---

## Troubleshooting

### Common Issues

**Wheel Build Failures**:
- Check Python version compatibility
- Verify system dependencies are installed
- Ensure sufficient disk space

**Installation Issues**:
- Verify wheel platform compatibility (linux, windows, macos)
- Check Python version requirements
- Ensure wheel integrity with checksum validation

**Storage Issues**:
- Implement wheel rotation policy
- Use compression for archival storage
- Monitor disk usage in CI/CD environments

---

## Security Considerations

- Scan wheels for known vulnerabilities
- Verify checksums and signatures when available
- Use trusted sources for vendor wheels
- Regularly update wheels with security patches
- Implement access controls for wheel storage