pipeline {
    agent any

    parameters {
        choice(name: 'ENV', choices: ['dev', 'test', 'uat', 'prod'], description: 'Select environment')
    }

    environment {
        // Define any global env vars if needed
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image with Ansible') {
            steps {
                script {
                    def env = params.ENV
                    sh """
                        # Build Ansible container
                        docker build -f docker/Dockerfile.ansible -t ansible-image .
                        # Run the Ansible playbook to deploy
                        docker run --rm -v \$(pwd):/workspace ansible-image ansible-playbook ansible/deploy.yml --extra-vars "env=${env}"
                    """
                }
            }
        }

        stage('Prepare Environment File') {
            steps {
                script {
                    def credIdMap = [
                        dev: 'gcp_dev_credentials',
                        test: 'gcp_test_credentials',
                        uat: 'gcp_uat_credentials',
                        prod: 'gcp_prod_credentials'
                    ]

                    def selectedCredId = credIdMap[params.ENV]

                    withCredentials([file(credentialsId: selectedCredId, variable: 'GCP_KEYFILE')]) {
                        sh """
                            cp \$GCP_KEYFILE ./gcp_key.json
                            echo 'GOOGLE_APPLICATION_CREDENTIALS=/app/gcp_key.json' > .env.${params.ENV}
                            echo 'OTHER_ENV_VAR=some_value' >> .env.${params.ENV}
                        """
                    }
                }
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    // Run tests with coverage inside the etl_test container
                    sh """
                        docker compose run --rm --env-file .env.${params.ENV} etl_test pytest --cov=framework --cov-report=term-missing -v
                    """
                }
            }
        }

        stage('Run Docker Compose') {
            steps {
                script {
                    sh """
                        docker compose --env-file .env.${params.ENV} up --build --abort-on-container-exit
                    """
                }
            }
        }

        stage('Clean Up') {
            steps {
                script {
                    sh """
                        docker compose down --volumes
                        docker image prune -f
                        rm -f gcp_key.json .env.${params.ENV}
                    """
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished. Cleanup done."
        }
    }
}
