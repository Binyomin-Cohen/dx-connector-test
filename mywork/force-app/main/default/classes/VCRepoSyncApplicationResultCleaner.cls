public with sharing class VCRepoSyncApplicationResultCleaner extends ApplicationResultCleaner {
    public static final String CLEANER_NAME = 'Sightline VC Repo Sync Application Result Cleaner';
    @TestVisible
    private static final Integer RECORD_RETENTION_COUNT = 10;

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id FROM VC_Repository__c]);
    }

    /**
    * Retrieves a map of VC repository ID -> application results.
    * @param instanceIds - The collection of VC repository IDs to collect application results for.
    * @return A map of VC repository ID -> application results.
    */
    public override Map<Id, List<ALM_Application_Result__c>> getApplicationResultsMap(Set<Id> vcRepoIds) {
        // Grab all application results for the current batch of repositories.
        List<ALM_Application_Result__c> applicationResults = [
            SELECT ALM_Job__r.VC_Repo__c
            FROM ALM_Application_Result__c
            WHERE ALM_Job__r.VC_Repo__c IN :vcRepoIds AND ALM_Job__r.Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.VC_REPO_SYNC)
            ORDER BY CreatedDate ASC
            LIMIT 10000
        ];
        Map<Id, List<ALM_Application_Result__c>> vcRepoIdToApplicationResults = new Map<Id, List<ALM_Application_Result__c>>();
        for (ALM_Application_Result__c applicationResult : applicationResults) {
            List<ALM_Application_Result__c> currentApplicationResults = vcRepoIdToApplicationResults.get(applicationResult.ALM_Job__r.VC_Repo__c);
            if (currentApplicationResults == null) {
                currentApplicationResults = new List<ALM_Application_Result__c>();
            }

            currentApplicationResults.add(applicationResult);

            vcRepoIdToApplicationResults.put(applicationResult.ALM_Job__r.VC_Repo__c, currentApplicationResults);
        }

        return vcRepoIdToApplicationResults;
    }

    /**
    * Given a map of VC repository ID -> application results, returns a collection of results to be deleted.
    * @param instanceIdToApplicationResults - The map of VC repository ID -> application results to be tested for deletion.
    * @return A collection of application results to be deleted.
    */
    public override List<ALM_Application_Result__c> filterOutRetainedResults(Map<Id, List<ALM_Application_Result__c>> vcRepoIdToApplicationResults) {
        // Clean application results for each version control repository.
        List<ALM_Application_Result__c> resultsToDelete = new List<ALM_Application_Result__c>();
        for (Id repoId : vcRepoIdToApplicationResults.keySet()) {            
            // Tracks the number of records to retain.
            Integer retentionCount = RECORD_RETENTION_COUNT;

            // Grab all application results for the current repository.
            List<ALM_Application_Result__c> results = vcRepoIdToApplicationResults.get(repoId);
            if (results != null) {
                // Iterate backwards (for list removal efficiency) through all results for the current repository, removing any results that should be retained.
                for (Integer i = results.size() - 1; i >= 0 && retentionCount > 0; --i) {
                    results.remove(i);
                    --retentionCount;
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
            ALMJobServices.ToolType.VC_REPO_SYNC
        };
    }

    public void finish(Database.BatchableContext context) {}

    public override String getCleanerName() {
        return CLEANER_NAME;
    }
}