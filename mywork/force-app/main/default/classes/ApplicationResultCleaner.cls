public abstract with sharing class ApplicationResultCleaner implements Database.Batchable<SObject>, Schedulable {
    public void execute(Database.BatchableContext context, List<SObject> scope) {
        // Gather all record IDs for the current scope.
        Set<Id> scopeRecordIds = Pluck.ids(scope);

        // Map scope records to their application results.
        Map<Id, List<ALM_Application_Result__c>> applicationResultsMap = getApplicationResultsMap(scopeRecordIds);

        // Filter out any results that should be retained.
        List<ALM_Application_Result__c> resultsToDelete = filterOutRetainedResults(applicationResultsMap);

        // Delete all results that are not eligible to be retained.
        try {
            delete resultsToDelete;
        } catch (DmlException e) {
            ALMLogServices.error(e, ALMLogServices.Application.APPLICATION_RESULT_CLEANER);
        }
    }

    public void execute(SchedulableContext context) {
        // Uses the scheduled job as a springboard to execute the cleaner as a batch job.
        ApplicationResultCleanerServices.executeCleaning(getCleanedToolTypes());

        System.abortJob(context.getTriggerId());
    }

    public abstract Map<Id, List<ALM_Application_Result__c>> getApplicationResultsMap(Set<Id> instanceIds);

    public abstract List<ALM_Application_Result__c> filterOutRetainedResults(Map<Id, List<ALM_Application_Result__c>> instanceIdToApplicationResults);

    public abstract Set<ALMJobServices.ToolType> getCleanedToolTypes();

    public abstract String getCleanerName();

    public Boolean equals(Object obj) {
        try {
            return getCleanerName().equals(((ApplicationResultCleaner)obj).getCleanerName());
        } catch (TypeException te) {
            return false;
        }
    }

    public Integer hashCode() {
        return getCleanerName().hashCode();
    }
}