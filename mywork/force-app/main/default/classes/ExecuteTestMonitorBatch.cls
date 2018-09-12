public with sharing class ExecuteTestMonitorBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

    @TestVisible private String query;
    public static final String RUNNING_STATUS = SCANServices.TOOL_STATUS_RUNNING;
    public static Integer SCOPE_SIZE = 1;
    @TestVisible private ExecuteTestMonitorDelay__c delayInMinutes {
        get {
            if (delayInMinutes == null) {
                delayInMinutes = ExecuteTestMonitorDelay__c.getOrgDefaults();
                if (delayInMinutes.DelayInMinutes__c == null) {
                    delayInMinutes.DelayInMinutes__c = 0;
                }
            }
            return delayInMinutes;
        }
        set;
    }
    @TestVisible private static final Integer POLL_INTERVAL_INCREMENT = 1;
    @TestVisible private static final Integer BACKOFF_THRESHOLD_IN_MINUTES = 15;
    public static final String BATCH_JOB_TITLE = 'Execute Test Monitor Batch Job';
    @TestVisible private static final String BUTR_TOOL_NAME = ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING);
    @TestVisible private List<ALM_Job__c> modifiedJobs;

    /**
     * @description Initializes query for alm job records
     */
    public ExecuteTestMonitorBatch() {
        this.query = 'SELECT Id, Async_Apex_Job_Id__c, Tool__c, Source_Instance__c, Status__c FROM ALM_Job__c WHERE Status__c = :RUNNING_STATUS AND Tool__c = :BUTR_TOOL_NAME';
        modifiedJobs = new List<ALM_Job__c>();
    }

    /**
     * @description Initializes the batch querying process
     * @param Database.BatchableContext bc
     * @return Database.QueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }

    /**
     * @description Executes the process of records (alm jobs) that should be monitored for completion
     * @param Database.BatchableContext bc
     * @param SObject[] scope
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        // Maps job IDs to jobs.
        Map<Id, ALM_Job__c> currentScopeMap = new Map<Id, ALM_Job__c>((List<ALM_Job__c>)scope);

        // Retrieve completed job unit test summaries mapped by job ID.
        Map<Id, Unit_Test_Summary__c> jobIdToUnitTestSummary = ExecuteTestMonitorBatchServices.checkForCompletedJobs(currentScopeMap.values());

        // Update the lists of completed jobs.
        List<ALM_Job__c> completedJobs = new List<ALM_Job__c>();
        for (Id jobId : jobIdToUnitTestSummary.keySet()) {
            completedJobs.add(currentScopeMap.get(jobId));
        }
        modifiedJobs.addAll(completedJobs);

        // Retrieves code coverage results and test failure results, mapped by job ID.
        Map<Id, CodeCoverageAggregate> jobIdToCoverageMap = ExecuteTestMonitorBatchServices.getCodeCoverageForJobs(completedJobs);
        Map<Id, CodeTestRunResult> jobIdToTestResultMap = ExecuteTestMonitorBatchServices.getCodeTestResultsForJobs(completedJobs);

        // Updates unit test summary objects with the correct instance lookup and inserts them.
        for (Id jobId : jobIdToUnitTestSummary.keySet()) {
            Unit_Test_Summary__c unitTestSummary = jobIdToUnitTestSummary.get(jobId);
            unitTestSummary.Instance__c = currentScopeMap.get(jobId).Source_Instance__c;
        }
        insert jobIdToUnitTestSummary.values();

        // Retrieves existing application results for the relevant jobs and maps them by job ID.
        Map<Id, ALM_Application_Result__c> jobIdToApplicationResult = 
            ALMApplicationResultServices.getLatestInProgressApplicationResultForJobs(Pluck.ids(completedJobs));

        // Creates code coverage result objects and associates them with their test summary.
        List<Code_Coverage__c> codeCoverageResultsToInsert = new List<Code_Coverage__c>();
        for (Id jobId : jobIdToCoverageMap.keySet()) {
            ALM_Application_Result__c applicationResult = jobIdToApplicationResult.get(jobId);

            if (applicationResult != null && applicationResult.Result__c == SCANServices.FAILURE_STATUS) {
                continue;
            }
            
            CodeCoverageAggregate coverage = jobIdToCoverageMap.get(jobId);
            ALM_Job__c job = currentScopeMap.get(jobId);
            Unit_Test_Summary__c unitTestSummary = jobIdToUnitTestSummary.get(jobId);

            List<Code_Coverage__c> newCodeCoverageResults = 
                ExecuteTestMonitorBatchServices.createCoverageObjectsForJob(coverage, job, applicationResult, unitTestSummary);

            if (newCodeCoverageResults != null) {
                codeCoverageResultsToInsert.addAll(newCodeCoverageResults);
            }
        }

        // Creates unit test failure objects and associates them with their test summary.
        List<Unit_Test_Failure__c> unitTestFailureResultsToInsert = new List<Unit_Test_Failure__c>();
        for (Id jobId : jobIdToTestResultMap.keySet()) {
            ALM_Application_Result__c applicationResult = jobIdToApplicationResult.get(jobId);

            if (applicationResult != null && applicationResult.Result__c == SCANServices.FAILURE_STATUS) {
                continue;
            }
            
            CodeTestRunResult testResult = jobIdToTestResultMap.get(jobId);
            ALM_Job__c job = currentScopeMap.get(jobId);
            Unit_Test_Summary__c unitTestSummary = jobIdToUnitTestSummary.get(jobId);

            List<Unit_Test_Failure__c> newUnitTestFailureResults = 
                ExecuteTestMonitorBatchServices.createUnitTestFailureObjectsForJob(testResult, job, applicationResult, unitTestSummary);

            if (newUnitTestFailureResults != null) {
                unitTestFailureResultsToInsert.addAll(newUnitTestFailureResults);   
            }
        }

        // Set the last successful run time on all successful jobs.
        DateTime now = DateTime.now();
        for (Id jobId : currentScopeMap.keySet()) {
            ALM_Application_Result__c applicationResult = jobIdToApplicationResult.get(jobId);

            if (applicationResult != null && applicationResult.Result__c == SCANServices.SUCCESS_STATUS) {
                ALMJobServices.markJobAsSuccess(currentScopeMap.get(jobId));
            }
        }

        // Inserts and updates relevant objects and sets completed jobs back to "Scheduled" status.
        try {
            insert codeCoverageResultsToInsert;
            insert unitTestFailureResultsToInsert;
            update jobIdToUnitTestSummary.values();
            update jobIdToApplicationResult.values();

            ExecuteTestMonitorBatchServices.updateJobsToScheduled(completedJobs);
        } catch (DMLException e) {
            ALMLogServices.error(e, ALMLogServices.Application.AUTOMATED_TESTING);
        }
    }

    /**
     * @description Aborts the scheduled job and executes the batch job.
     * @param SchedulableContext sc
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ExecuteTestMonitorBatch(), SCOPE_SIZE);

        System.abortJob(sc.getTriggerId());
    }

    /**
     * @description Determines whether to run again, if there are more alm job records that need to be processed.
     * @param Database.BatchableContext bc
     */
    public void finish(Database.BatchableContext bc) {
        List<ALM_Job__c> jobsRemaining = Database.query(this.query + ' LIMIT 1');

        if (!modifiedJobs.isEmpty()) {
            delayInMinutes.DelayInMinutes__c = POLL_INTERVAL_INCREMENT;
        }

        if (!jobsRemaining.isEmpty() && !ExecuteTestMonitorBatchServices.isMonitorBatchScheduledOrRunning()) {
            if (modifiedJobs.isEmpty() && delayInMinutes.DelayInMinutes__c < BACKOFF_THRESHOLD_IN_MINUTES) {
                delayInMinutes.DelayInMinutes__c += POLL_INTERVAL_INCREMENT;
            }
            System.scheduleBatch(new ExecuteTestMonitorBatch(), BATCH_JOB_TITLE, (Integer) delayInMinutes.DelayInMinutes__c, SCOPE_SIZE);
        }
        try{
            upsert delayInMinutes;
        }
        catch (DMLException e) {
            ALMLogServices.error(e, ALMLogServices.Application.AUTOMATED_TESTING);
        }
    }
}