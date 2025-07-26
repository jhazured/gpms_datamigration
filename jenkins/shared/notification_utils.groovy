// Notification Utility Functions for Jenkins Pipelines

/**
 * Send Slack notification
 */
def sendSlackNotification(Map config) {
    def webhookUrl = env.SLACK_WEBHOOK_URL ?: config.webhookUrl
    if (!webhookUrl) {
        echo "Warning: Slack webhook URL not configured"
        return
    }
    
    def color = getColorForStatus(config.status ?: 'info')
    def message = buildSlackMessage(config)
    
    def payload = [
        channel: config.channel ?: '#etl-alerts',
        username: config.username ?: 'Jenkins ETL Bot',
        icon_emoji: config.icon ?: ':robot_face:',
        attachments: [[
            color: color,
            title: config.title ?: "ETL Pipeline Notification",
            text: message,
            fields: buildSlackFields(config),
            footer: "Jenkins ETL Pipeline",
            ts: System.currentTimeMillis() / 1000
        ]]
    ]
    
    sh """
        curl -X POST -H 'Content-type: application/json' \\
        --data '${groovy.json.JsonBuilder(payload).toString()}' \\
        ${webhookUrl}
    """
    
    echo "Slack notification sent to ${config.channel ?: '#etl-alerts'}"
}

/**
 * Send email notification
 */
def sendEmailNotification(Map config) {
    def recipients = config.recipients ?: env.ETL_EMAIL_RECIPIENTS
    if (!recipients) {
        echo "Warning: Email recipients not configured"
        return
    }
    
    def subject = config.subject ?: buildEmailSubject(config)
    def body = buildEmailBody(config)
    
    emailext(
        to: recipients,
        subject: subject,
        body: body,
        mimeType: 'text/html',
        attachmentsPattern: config.attachments ?: ''
    )
    
    echo "Email notification sent to: ${recipients}"
}

/**
 * Send Teams notification
 */
def sendTeamsNotification(Map config) {
    def webhookUrl = env.TEAMS_WEBHOOK_URL ?: config.webhookUrl
    if (!webhookUrl) {
        echo "Warning: Teams webhook URL not configured"
        return
    }
    
    def color = getColorForStatus(config.status ?: 'info')
    def message = buildTeamsMessage(config)
    
    def payload = [
        '@type': 'MessageCard',
        '@context': 'https://schema.org/extensions',
        summary: config.title ?: 'ETL Pipeline Notification',
        themeColor: color.replace('#', ''),
        sections: [[
            activityTitle: config.title ?: 'ETL Pipeline Notification',
            activitySubtitle: message,
            facts: buildTeamsFacts(config)
        ]]
    ]
    
    sh """
        curl -X POST -H 'Content-Type: application/json' \\
        --data '${groovy.json.JsonBuilder(payload).toString()}' \\
        ${webhookUrl}
    """
    
    echo "Teams notification sent"
}

/**
 * Send success notification to all configured channels
 */
def notifySuccess(Map config = [:]) {
    def defaultConfig = [
        status: 'success',
        title: '✅ ETL Pipeline Success',
        message: "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} completed successfully",
        jobName: env.JOB_NAME,
        buildNumber: env.BUILD_NUMBER,
        environment: config.environment ?: 'unknown',
        duration: currentBuild.durationString,
        buildUrl: env.BUILD_URL
    ]
    
    def finalConfig = defaultConfig + config
    
    // Send to all configured notification channels
    if (env.SLACK_WEBHOOK_URL || config.slackWebhook) {
        sendSlackNotification(finalConfig + [webhookUrl: config.slackWebhook])
    }
    
    if (env.ETL_EMAIL_RECIPIENTS || config.emailRecipients) {
        sendEmailNotification(finalConfig + [recipients: config.emailRecipients])
    }
    
    if (env.TEAMS_WEBHOOK_URL || config.teamsWebhook) {
        sendTeamsNotification(finalConfig + [webhookUrl: config.teamsWebhook])
    }
}

/**
 * Send failure notification to all configured channels
 */
def notifyFailure(Map config = [:]) {
    def defaultConfig = [
        status: 'failure',
        title: '❌ ETL Pipeline Failure',
        message: "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} failed",
        jobName: env.JOB_NAME,
        buildNumber: env.BUILD_NUMBER,
        environment: config.environment ?: 'unknown',
        duration: currentBuild.durationString,
        buildUrl: env.BUILD_URL,
        errorMessage: currentBuild.description ?: 'Check logs for details'
    ]
    
    def finalConfig = defaultConfig + config
    
    // Send to all configured notification channels
    if (env.SLACK_WEBHOOK_URL || config.slackWebhook) {
        sendSlackNotification(finalConfig + [webhookUrl: config.slackWebhook])
    }
    
    if (env.ETL_EMAIL_RECIPIENTS || config.emailRecipients) {
        sendEmailNotification(finalConfig + [recipients: config.emailRecipients])
    }
    
    if (env.TEAMS_WEBHOOK_URL || config.teamsWebhook) {
        sendTeamsNotification(finalConfig + [webhookUrl: config.teamsWebhook])
    }
}

/**
 * Send warning notification
 */
def notifyWarning(Map config = [:]) {
    def defaultConfig = [
        status: 'warning',
        title: '⚠️  ETL Pipeline Warning',
        message: config.message ?: "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} completed with warnings"
    ]
    
    def finalConfig = defaultConfig + config
    
    if (env.SLACK_WEBHOOK_URL || config.slackWebhook) {
        sendSlackNotification(finalConfig)
    }
}

/**
 * Send job execution notification
 */
def notifyJobExecution(Map config) {
    def message = "ETL Job Execution: ${config.jobName}"
    if (config.status == 'started') {
        message += " started in ${config.environment}"
    } else if (config.status == 'completed') {
        message += " completed successfully in ${config.environment}"
    } else if (config.status == 'failed') {
        message += " failed in ${config.environment}"
    }
    
    def notificationConfig = [
        status: config.status,
        title: "ETL Job: ${config.jobName}",
        message: message,
        environment: config.environment,
        jobName: config.jobName,
        jobId: config.jobId,
        duration: config.duration
    ]
    
    if (config.status == 'failed') {
        notifyFailure(notificationConfig)
    } else if (config.status == 'completed') {
        notifySuccess(notificationConfig)
    } else {
        notifyWarning(notificationConfig)
    }
}

// Helper functions
private def getColorForStatus(String status) {
    switch(status?.toLowerCase()) {
        case 'success':
            return '#36a64f'
        case 'failure':
        case 'failed':
            return '#ff0000'
        case 'warning':
            return '#ffaa00'
        case 'info':
        default:
            return '#439fe0'
    }
}

private def buildSlackMessage(Map config) {
    def message = config.message ?: ''
    
    if (config.environment) {
        message += "\\nEnvironment: *${config.environment}*"
    }
    
    if (config.jobName && config.buildNumber) {
        message += "\\nJob: ${config.jobName} #${config.buildNumber}"
    }
    
    if (config.duration) {
        message += "\\nDuration: ${config.duration}"
    }
    
    if (config.errorMessage) {
        message += "\\nError: `${config.errorMessage}`"
    }
    
    return message
}

private def buildSlackFields(Map config) {
    def fields = []
    
    if (config.environment) {
        fields.add([title: 'Environment', value: config.environment, short: true])
    }
    
    if (config.buildNumber) {
        fields.add([title: 'Build', value: "#${config.buildNumber}", short: true])
    }
    
    if (config.jobId) {
        fields.add([title: 'Job ID', value: config.jobId, short: true])
    }
    
    if (config.buildUrl) {
        fields.add([title: 'Build URL', value: "<${config.buildUrl}|View Build>", short: false])
    }
    
    return fields
}

private def buildEmailSubject(Map config) {
    def status = config.status?.toUpperCase() ?: 'NOTIFICATION'
    def jobName = config.jobName ?: 'ETL Pipeline'
    def buildNumber = config.buildNumber ? " #${config.buildNumber}" : ''
    def environment = config.environment ? " [${config.environment.toUpperCase()}]" : ''
    
    return "${status}: ${jobName}${buildNumber}${environment}"
}

private def buildEmailBody(Map config) {
    def html = """
    <html>
    <body>
        <h2>${config.title ?: 'ETL Pipeline Notification'}</h2>
        <p>${config.message ?: ''}</p>
        
        <table border="1" cellpadding="5" cellspacing="0">
            <tr><td><strong>Job Name</strong></td><td>${config.jobName ?: 'N/A'}</td></tr>
            <tr><td><strong>Build Number</strong></td><td>${config.buildNumber ?: 'N/A'}</td></tr>
            <tr><td><strong>Environment</strong></td><td>${config.environment ?: 'N/A'}</td></tr>
            <tr><td><strong>Status</strong></td><td>${config.status ?: 'N/A'}</td></tr>
            <tr><td><strong>Duration</strong></td><td>${config.duration ?: 'N/A'}</td></tr>
    """
    
    if (config.errorMessage) {
        html += "<tr><td><strong>Error</strong></td><td><code>${config.errorMessage}</code></td></tr>"
    }
    
    if (config.buildUrl) {
        html += "<tr><td><strong>Build URL</strong></td><td><a href='${config.buildUrl}'>View Build</a></td></tr>"
    }
    
    html += """
        </table>
        
        <br/>
        <p><em>This is an automated notification from Jenkins ETL Pipeline</em></p>
    </body>
    </html>
    """
    
    return html
}

private def buildTeamsMessage(Map config) {
    return config.message ?: ''
}

private def buildTeamsFacts(Map config) {
    def facts = []
    
    if (config.environment) {
        facts.add([name: 'Environment', value: config.environment])
    }
    
    if (config.buildNumber) {
        facts.add([name: 'Build', value: "#${config.buildNumber}"])
    }
    
    if (config.duration) {
        facts.add([name: 'Duration', value: config.duration])
    }
    
    if (config.jobId) {
        facts.add([name: 'Job ID', value: config.jobId])
    }
    
    return facts
}

return this