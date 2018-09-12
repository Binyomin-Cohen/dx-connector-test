public with sharing class InstanceApplicationResultCleaner extends ApplicationResultCleaner {
    public static final String CLEANER_NAME = 'Sightline Instance Application Result Cleaner';

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id FROM Instances__c]);
    }

    /**
    * Retrieves a map of instance ID -> application results.
    * @param instanceIds - The collection of instance IDs to collect application results for.
    * @return A map of instance ID -> application results.
    */
    public override Map<Id, List<ALM_Application_Result__c>> getApplicationResultsMap(Set<Id> instanceIds) {
        // Grab all application results for the current batch of instances (grouped by instance).
        Map<Id, Instances__c> instanceIdToInstanceWithResults = new Map<Id, Instances__c>([
            SELECT (
                SELECT CreatedDate, Tool__c, Run_Time__c, Instance__c, Error_Code__c
                FROM ALM_Application_Results__r
                WHERE Instance__c IN :instanceIds AND Tool__c IN (:ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN), :ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING))
                ORDER BY CreatedDate ASC
                LIMIT 10000
            ) FROM Instances__c
            WHERE Id IN :instanceIds
        ]);

        Map<Id, List<ALM_Application_Result__c>> instanceIdToApplicationResults = new Map<Id, List<ALM_Application_Result__c>>();
        for (Id instanceId : instanceIdToInstanceWithResults.keySet()) {
            instanceIdToApplicationResults.put(instanceId, instanceIdToInstanceWithResults.get(instanceId).ALM_Application_Results__r);
        }

        return instanceIdToApplicationResults;
    }

    /**
    * Given a map of instance ID -> application results, returns a collection of results to be deleted.
    * @param instanceIdToApplicationResults - The map of instance ID -> application results to be tested for deletion.
    * @return A collection of application results to be deleted.
    */
    public override List<ALM_Application_Result__c> filterOutRetainedResults(Map<Id, List<ALM_Application_Result__c>> instanceIdToApplicationResults) {
        // Clean application results for each instance.
        DateTime retentionBoundary = ApplicationResultCleanerServices.getRetentionBoundary();
        List<ALM_Application_Result__c> resultsToDelete = new List<ALM_Application_Result__c>();
        for (Id instanceId : instanceIdToApplicationResults.keySet()) {            
            // Tracks the minimum (if available) number of records to retain, per job type.
            Map<String, Integer> recordCountByTool = new Map<String, Integer>{
                ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN) => 10,
                ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING) => 10
            };

            // Grab all application results for the current instance.
            List<ALM_Application_Result__c> results = instanceIdToApplicationResults.get(instanceId);
            if (results != null) {
                Boolean foundNotInProgressErrorResult = false;

                // Iterate backwards (for list removal efficiency) through all results for the current instance, removing any results that should be retained.
                Integer initialResultsSize = results.size();
                for (Integer i = initialResultsSize - 1; i >= 0; --i) {
                    ALM_Application_Result__c result = results[i];

                    Integer recordCount = recordCountByTool.get(result.Tool__c);
                    if (recordCount != null) {
                        // Retains any application results that are within the first sorted 10, or newer than the retention boundary (if one is specified). In-progress results are only retained if they're the newest result.
                        if (((result.Run_Time__c != null) && (recordCount > 0 || (retentionBoundary != null && result.CreatedDate >= retentionBoundary)))
                            || ((result.Run_Time__c == null) && !foundNotInProgressErrorResult)) {
                            results.remove(i);
                            recordCountByTool.put(result.Tool__c, --recordCount);
                        }
                    } else {
                        // If the current application result corresponds to a tool not specified in the recordCountByTool map, retain it.
                        results.remove(i);
                    }

                    if (result.Error_Code__c != ALMJobServices.ERROR_CODE_JOB_IN_PROGRESS) {
                        foundNotInProgressErrorResult = true;
                    }
                }

                // Add all application results remaining in the query result list to the deletion list.
                resultsToDelete.addAll(results);
            }
        }

        return resultsToDelete;
    }

    /**
    * Returns a collection of tool types cleaned by this cleaner.
    * @return A collection of tool types cleaned by this cleaner.
    */
    public override Set<ALMJobServices.ToolType> getCleanedToolTypes() {
        return new Set<ALMJobServices.ToolType>{
            ALMJobServices.ToolType.SCAN,
            ALMJobServices.ToolType.AUTOMATED_TESTING
        };
    }

    public void finish(Database.BatchableContext context) {
        // Removes application results that are not attached to an instance.
        try {
            delete [
                SELECT Id
                FROM ALM_Application_Result__c
                WHERE Instance__c = null AND Tool__c IN (:ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN), :ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING))
                LIMIT 10000
            ];
        } catch (Exception e) {
            ALMLogServices.error(e, ALMLogServices.Application.APPLICATION_RESULT_CLEANER);
        }
    }

    public override String getCleanerName() {
        return CLEANER_NAME;
    }
}