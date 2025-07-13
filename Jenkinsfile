pipeline {
    agent any

    parameters {
        choice(name: 'ENV', choices: ['dev', 'test', 'uat', 'prod'], description: 'Select environment')
    }

    environment {
        // You can define any global env vars here if needed
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def tag = "my_etl_image:${params.ENV}"
                    sh "docker build -t ${tag} ."
                }
            }
        }

        stage('Prepare Environment File') {
            steps {
                script {
                    // Map environment to Jenkins credentials ID
                    def credIdMap = [
                        dev: 'gcp_dev_credentials',
                        test: 'gcp_test_credentials',
                        uat: 'gcp_uat_credentials',
                        prod: 'gcp_prod_credentials'
                    ]

                    def selectedCredId = credIdMap[params.ENV]

                    // Retrieve GCP credentials file and write .env dynamically
                    withCredentials([file(credentialsId: selectedCredId, variable: 'GCP_KEYFILE')]) {
                        // Copy credentials to workspace and create .env file
                        sh """
                            cp \$GCP_KEYFILE ./gcp_key.json
                            echo 'GOOGLE_APPLICATION_CREDENTIALS=/app/gcp_key.json' > .env.${params.ENV}
                            echo 'OTHER_ENV_VAR=some_value' >> .env.${params.ENV}
                        """
                    }
                }
            }
        }

        stage('Run Docker Compose') {
            steps {
                script {
                    // Use docker compose to start containers, passing env file for selected environment
                    sh """
                        docker compose --env-file .env.${params.ENV} up --build --abort-on-container-exit
                    """
                }
            }
        }

        stage('Clean Up') {
            steps {
                script {
                    // Clean up containers and images optionally
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
