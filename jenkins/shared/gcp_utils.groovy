// GCP Utility Functions for Jenkins Pipelines

/**
 * Authenticate with GCP using service account
 */
def authenticateGcp(String serviceAccountPath = null) {
    if (serviceAccountPath) {
        sh """
            gcloud auth activate-service-account --key-file=${serviceAccountPath}
            gcloud config set project \$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 | cut -d'@' -f2 | cut -d'.' -f1)
        """
    }
    
    // Verify authentication
    sh "gcloud auth application-default print-access-token > /dev/null"
    echo "GCP authentication successful"
}

/**
 * Get current GCP project ID
 */
def getProjectId() {
    return sh(
        script: "gcloud config get-value project",
        returnStdout: true
    ).trim()
}

/**
 * Get GCP region from configuration or environment
 */
def getRegion(String defaultRegion = 'us-central1') {
    def region = env.GCP_REGION ?: defaultRegion
    return region
}

/**
 * Check if GCS bucket exists
 */
def bucketExists(String bucketName) {
    def result = sh(
        script: "gsutil ls gs://${bucketName} 2>/dev/null || echo 'NOT_FOUND'",
        returnStdout: true
    ).trim()
    return !result.contains('NOT_FOUND')
}

/**
 * Create GCS bucket if it doesn't exist
 */
def createBucketIfNotExists(String bucketName, String location = 'US') {
    if (!bucketExists(bucketName)) {
        sh "gsutil mb -l ${location} gs://${bucketName}"
        echo "Created bucket: gs://${bucketName}"
    } else {
        echo "Bucket already exists: gs://${bucketName}"
    }
}

/**
 * Upload file to GCS
 */
def uploadToGcs(String localPath, String gcsPath) {
    sh "gsutil cp ${localPath} ${gcsPath}"
    echo "Uploaded ${localPath} to ${gcsPath}"
}

/**
 * Download file from GCS
 */
def downloadFromGcs(String gcsPath, String localPath) {
    sh "gsutil cp ${gcsPath} ${localPath}"
    echo "Downloaded ${gcsPath} to ${localPath}"
}

/**
 * Check Dataflow job status
 */
def getDataflowJobStatus(String jobId, String region = 'us-central1') {
    return sh(
        script: "gcloud dataflow jobs describe ${jobId} --region=${region} --format='value(currentState)'",
        returnStdout: true
    ).trim()
}

/**
 * List running Dataflow jobs
 */
def getRunningDataflowJobs(String region = 'us-central1', String filter = '') {
    def filterString = filter ? "--filter='${filter}'" : ""
    def jobs = sh(
        script: "gcloud dataflow jobs list --region=${region} ${filterString} --filter='state=JOB_STATE_RUNNING' --format='csv[no-heading](JOB_ID,JOB_NAME,JOB_TYPE,CREATION_TIME)'",
        returnStdout: true
    ).trim()
    
    return jobs.split('\n').findAll { it.trim() }
}

/**
 * Cancel Dataflow job
 */
def cancelDataflowJob(String jobId, String region = 'us-central1') {
    sh "gcloud dataflow jobs cancel ${jobId} --region=${region}"
    echo "Cancelled Dataflow job: ${jobId}"
}

/**
 * Check BigQuery dataset exists
 */
def datasetExists(String datasetId, String projectId = null) {
    def project = projectId ?: getProjectId()
    def result = sh(
        script: "bq show --dataset ${project}:${datasetId} 2>/dev/null || echo 'NOT_FOUND'",
        returnStdout: true
    ).trim()
    return !result.contains('NOT_FOUND')
}

/**
 * Create BigQuery dataset if it doesn't exist
 */
def createDatasetIfNotExists(String datasetId, String location = 'US', String projectId = null) {
    def project = projectId ?: getProjectId()
    if (!datasetExists(datasetId, project)) {
        sh "bq mk --dataset --location=${location} ${project}:${datasetId}"
        echo "Created BigQuery dataset: ${project}:${datasetId}"
    } else {
        echo "Dataset already exists: ${project}:${datasetId}"
    }
}

/**
 * Run BigQuery query
 */
def runBigQueryQuery(String query, String jobId = null) {
    def jobIdFlag = jobId ? "--job_id=${jobId}" : ""
    sh "bq query --use_legacy_sql=false ${jobIdFlag} '${query}'"
}

/**
 * Check GCP service quotas
 */
def checkQuotas(String service = 'compute') {
    sh """
        gcloud ${service} project-info describe --format='table(quotas[].metric,quotas[].usage,quotas[].limit)' | \
        awk 'NR>1 {
            usage=\$2; limit=\$3;
            if (usage && limit && usage > limit * 0.8) {
                print "Warning: " \$1 " quota usage is high: " usage "/" limit
            }
        }'
    """
}

/**
 * Set up GCP environment variables
 */
def setGcpEnvironment(String environment) {
    env.GCP_ENVIRONMENT = environment
    env.GCP_PROJECT_ID = getProjectId()
    env.GCP_REGION = getRegion()
    
    echo "GCP Environment configured:"
    echo "  Project: ${env.GCP_PROJECT_ID}"
    echo "  Region: ${env.GCP_REGION}"
    echo "  Environment: ${env.GCP_ENVIRONMENT}"
}

/**
 * Get secret from Secret Manager
 */
def getSecret(String secretName, String version = 'latest') {
    return sh(
        script: "gcloud secrets versions access ${version} --secret=${secretName}",
        returnStdout: true
    ).trim()
}

/**
 * Create or update secret in Secret Manager
 */
def createOrUpdateSecret(String secretName, String secretValue) {
    // Check if secret exists
    def secretExists = sh(
        script: "gcloud secrets describe ${secretName} 2>/dev/null || echo 'NOT_FOUND'",
        returnStdout: true
    ).trim()
    
    if (secretExists.contains('NOT_FOUND')) {
        // Create new secret
        sh "echo '${secretValue}' | gcloud secrets create ${secretName} --data-file=-"
        echo "Created secret: ${secretName}"
    } else {
        // Add new version
        sh "echo '${secretValue}' | gcloud secrets versions add ${secretName} --data-file=-"
        echo "Updated secret: ${secretName}"
    }
}

/**
 * Validate GCP permissions for required services
 */
def validatePermissions(List<String> services = ['dataflow', 'bigquery', 'storage']) {
    services.each { service ->
        switch(service) {
            case 'dataflow':
                sh "gcloud dataflow jobs list --limit=1 > /dev/null"
                break
            case 'bigquery':
                sh "bq ls --max_results=1 > /dev/null"
                break
            case 'storage':
                sh "gsutil ls > /dev/null"
                break
            case 'secretmanager':
                sh "gcloud secrets list --limit=1 > /dev/null"
                break
        }
        echo "✓ ${service} permissions validated"
    }
}

/**
 * Clean up old Dataflow jobs
 */
def cleanupOldJobs(String environment, int daysOld = 7) {
    def cutoffDate = sh(
        script: "date -d '${daysOld} days ago' '+%Y-%m-%d'",
        returnStdout: true
    ).trim()
    
    echo "Cleaning up Dataflow jobs older than ${cutoffDate}"
    
    sh """
        gcloud dataflow jobs list \\
            --region=${getRegion()} \\
            --filter='createTime<${cutoffDate} AND state!=JOB_STATE_RUNNING' \\
            --format='value(JOB_ID)' | \\
        head -20 | \\
        while read job_id; do
            if [ ! -z "\$job_id" ]; then
                echo "Would clean up job: \$job_id"
                # Uncomment to actually delete:
                # gcloud dataflow jobs cancel \$job_id --region=${getRegion()} 2>/dev/null || true
            fi
        done
    """
}

return this