// scripts/etl_groups.groovy
// This script defines ETL groups and individual scripts for dynamic dropdown population

class ETLConfig {
    // Define individual ETL scripts
    static def individualScripts = [
        'customer_order_frequency',
        'sales_etl',
        'inventory_etl',
        'product_analytics',
        'customer_segmentation',
        'financial_reporting'
    ]
    
    // Define ETL groups
    static def etlGroups = [
        'customer_analytics_group': [
            'customer_order_frequency',
            'customer_segmentation'
        ],
        'sales_analytics_group': [
            'sales_etl',
            'product_analytics'
        ],
        'operational_group': [
            'inventory_etl',
            'financial_reporting'
        ],
        'daily_batch_group': [
            'customer_order_frequency',
            'sales_etl',
            'inventory_etl'
        ],
        'weekly_analytics_group': [
            'customer_segmentation',
            'product_analytics',
            'financial_reporting'
        ],
        'all_etls': [
            'customer_order_frequency',
            'sales_etl',
            'inventory_etl',
            'product_analytics',
            'customer_segmentation',
            'financial_reporting'
        ]
    ]
    
    // Get all available options for dropdown (groups + individual scripts)
    static def getAllOptions() {
        def options = [''] // Empty option for when ETL_SCRIPT is not required
        
        // Add group options with prefix
        etlGroups.keySet().each { group ->
            options.add("GROUP:${group}")
        }
        
        // Add individual script options
        options.addAll(individualScripts)
        
        return options
    }
    
    // Get scripts for a given selection
    static def getScripts(selection) {
        if (!selection || selection.trim() == '') {
            return []
        }
        
        if (selection.startsWith('GROUP:')) {
            def groupName = selection.substring(6) // Remove 'GROUP:' prefix
            return etlGroups[groupName] ?: []
        } else {
            return [selection]
        }
    }
    
    // Validate if selection exists
    static def isValidSelection(selection) {
        if (!selection || selection.trim() == '') {
            return true // Empty is valid for build_image action
        }
        
        if (selection.startsWith('GROUP:')) {
            def groupName = selection.substring(6)
            return etlGroups.containsKey(groupName)
        } else {
            return individualScripts.contains(selection)
        }
    }
    
    // Get description for selection
    static def getDescription(selection) {
        if (!selection || selection.trim() == '') {
            return 'No ETL script selected'
        }
        
        if (selection.startsWith('GROUP:')) {
            def groupName = selection.substring(6)
            def scripts = etlGroups[groupName]
            return "Group: ${groupName} (${scripts?.size() ?: 0} scripts: ${scripts?.join(', ') ?: 'none'})"
        } else {
            return "Individual script: ${selection}"
        }
    }
}

// Return the options for Jenkins dropdown
return ETLConfig.getAllOptions()