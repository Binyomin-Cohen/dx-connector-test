public with sharing class ExecuteTestMonitorBatchServices {
    public static final String SCHEDULED_STATUS = 'Scheduled';
    @TestVisible private final static String RUNNING_BATCH = 'Processing';
    @TestVisible private final static String QUEUED_BATCH = 'Queued';
    @TestVisible private final static String PREPARING_BATCH = 'Preparing';
    public final static List<String> STARTING_CATEGORY = new List<String>{QUEUED_BATCH, PREPARING_BATCH};

    public static final String ERROR_RETRIEVAL_AUTH_AND_ASYNC = 'Auth user and Async ApexJob ID cannot be found.';
    public static final String ERROR_RETRIEVAL_AUTH = 'Auth user cannot be found.';
    public static final String ERROR_RETRIEVAL_ASYNC = 'Async ApexJob ID cannot be found.';
    public static final String ERROR_RETRIEVAL_COVERAGE = 'Could not retrieve code coverage results.';
    public static final String ERROR_RETRIEVAL_FAILURES = 'Could not retrieve unit test failure results.';

    public static final String SUMMARY_FAILURES_TRUNCATED = '...[Too long, truncated]';

    @TestVisible private static String ASYNC_TOOLING_BASEQUERY = 'Select UserId, TestTime, SystemModstamp, Status,'
            + 'StartTime, Source, MethodsFailed, MethodsEnqueued,'
            + 'MethodsCompleted, LastModifiedDate, LastModifiedById, '
            + 'JobName, IsDeleted, IsAllTests, Id, EndTime, CreatedDate, '
            + 'CreatedById, ClassesEnqueued, ClassesCompleted, AsyncApexJobId From ApexTestRunResult';

    public static boolean isMonitorBatchScheduledOrRunning() {
        Boolean found = false;

        //First we check to see if the job is scheduled
        String cronQuery =    'SELECT Id'
                + ' FROM CronTrigger WHERE NextFireTime <> null'
                + ' AND CronJobDetail.Name = \''+ExecuteTestMonitorBatch.BATCH_JOB_TITLE+'\''
                + ' LIMIT 1';
        List<CronTrigger> cjobs = Database.query(cronQuery);

        if (!cjobs.isEmpty()) {
            found = true;
        }
        else
        {
            //Then we check to see if it is running or queued
            String query =  'SELECT Id'
                    + ' FROM AsyncApexJob'
                    + ' WHERE (JobType = \'BatchApex\')'
                    + ' AND ApexClass.Name = \'ExecuteTestMonitorBatch\''
                    + ' AND (Status in ' + BluewolfDevUtils.flattenListForQuery(STARTING_CATEGORY)
                    + ' OR Status in '+ BluewolfDevUtils.flattenListForQuery(new List<String>{ RUNNING_BATCH }) + ')'
                    + ' LIMIT 1';

            List<AsyncApexJob> inProgressJobs = Database.query(query);

            if (!inProgressJobs.isEmpty()) {
                found = true;
            }
        }

        return found;
    }

    /**
    * Retrieves unit test summaries for any completed jobs in the given job collection.
    * @param jobs - A collection of jobs to check on.
    * @return A map of "job ID => unit test summary".
    */
    public static Map<Id, Unit_Test_Summary__c> checkForCompletedJobs(List<ALM_Job__c> jobs) {
        Map<Id, Unit_Test_Summary__c> jobIdToUnitTestSummary = new Map<Id, Unit_Test_Summary__c>();

        Map<Id, Set<String>> instanceIdToAsyncJobIds = mapInstanceIdToAsyncJobIds(jobs);
        Map<Id, Auth_User__c> instanceIdToAuthUser = OAuthServices.getAuthUsersForTools(BluewolfDevUtils.convertIdsToStrings(instanceIdToAsyncJobIds.keySet()));

        Map<String, Unit_Test_Summary__c> asyncJobIdToUnitTestSummary = new Map<String, Unit_Test_Summary__c>();
        for (Id instanceId : instanceIdToAsyncJobIds.keySet()) {
            CodeTestRunSummary completedJobsSummary = new CodeTestRunSummary();
            completedJobsSummary.records = new List<CodeTestRunSummary.Records>();

            Auth_User__c authUser = instanceIdToAuthUser.get(instanceId);
            Set<String> asyncJobIds = instanceIdToAsyncJobIds.get(instanceId);

            // If the auth user or async IDs are unavailable, create error results.
            if (authUser == null || asyncJobIds == null) {
                String errorMessage = '';
                if (authUser == null && asyncJobIds == null) {
                    errorMessage = ERROR_RETRIEVAL_AUTH_AND_ASYNC;
                } else if (authUser == null) {
                    errorMessage = ERROR_RETRIEVAL_AUTH;
                } else if (asyncJobIds == null) {
                    errorMessage = ERROR_RETRIEVAL_ASYNC;
                }

                Set<ALM_Job__c> errorJobs = new Set<ALM_Job__c>();
                for (ALM_Job__c job : jobs) {
                    if (job.Source_Instance__c == instanceId) {
                        errorJobs.add(job);
                    }
                }

                completedJobsSummary.error = new ALMException(errorMessage);
                for (ALM_Job__c errorJob : errorJobs) {
                    CodeTestRunSummary.Records errorRecord = new CodeTestRunSummary.Records();
                    errorRecord.asyncApexJobId = errorJob.Async_Apex_Job_Id__c;
                    completedJobsSummary.records.add(errorRecord);
                }
            } else {
                // Try to retrieve summaries for completed jobs, or create error results if this fails.
                try {
                    completedJobsSummary = ToolingServices.getCompletedTestRunSummaries(authUser, asyncJobIds);
                } catch (Exception e) {
                    completedJobsSummary.error = e;
                    for (String asyncJobId : asyncJobIds) {
                        CodeTestRunSummary.Records errorRecord = new CodeTestRunSummary.Records();
                        errorRecord.asyncApexJobId = asyncJobId;
                        completedJobsSummary.records.add(errorRecord);
                    }
                }
            }

            if (completedJobsSummary != null) {
                asyncJobIdToUnitTestSummary.putAll(completedJobsSummary.deconstructIntoSobjectRecords());
            }
        }

        for (ALM_Job__c job : jobs) {
            Unit_Test_Summary__c unitTestSummary = asyncJobIdToUnitTestSummary.get(job.Async_Apex_Job_Id__c);
            if (unitTestSummary != null) {
                jobIdToUnitTestSummary.put(job.Id, unitTestSummary);
            }
        }

        return jobIdToUnitTestSummary;
    }

    /**
    * Retrieves code coverage for all jobs in the given job collection.
    * @param jobs - A collection of jobs to retrieve code coverage for.
    * @return A map of "job ID => code coverage results".
    */
    public static Map<Id, CodeCoverageAggregate> getCodeCoverageForJobs(List<ALM_Job__c> completedJobs) {
        Map<Id, CodeCoverageAggregate> jobIdToAggregatesMapToReturn = new Map<Id, CodeCoverageAggregate>();
        Map<String, List<ALM_Job__c>> jobsGroupedByInstanceId = GroupBy.Strings(ALM_Job__c.Source_Instance__c, completedJobs);
        Map<Id,Auth_User__c> instanceIdToAuthUser = OAuthServices.getAuthUsersForTools(jobsGroupedByInstanceId.keySet());

        for (Id instanceId : instanceIdToAuthUser.keySet()) {
            Auth_User__c authUser = instanceIdToAuthUser.get(instanceId);

            // Try to retrieve code coverage results for jobs, or create error results if this fails.
            try {
                CodeCoverageAggregate coverage = ToolingServices.getCodeCoverage(authUser);
                for (ALM_Job__c job : jobsGroupedByInstanceId.get(instanceId)) {
                    jobIdToAggregatesMapToReturn.put(job.Id, coverage);
                }
            } catch (Exception e) {
                for (ALM_Job__c job : jobsGroupedByInstanceId.get(instanceId)) {
                    CodeCoverageAggregate errorRecord = new CodeCoverageAggregate();
                    errorRecord.error = e;
                    jobIdToAggregatesMapToReturn.put(job.Id, errorRecord);
                }
            }
        }

        return jobIdToAggregatesMapToReturn;
    }

    /**
    * Retrieves test results for all jobs in the given job collection.
    * @param jobs - A collection of jobs to retrieve test results for.
    * @return A map of "job ID => code test run results".
    */
    public static Map<Id, CodeTestRunResult> getCodeTestResultsForJobs(List<ALM_Job__c> completedJobs) {
        Map<Id, CodeTestRunResult> jobIdToTestResultsToReturn = new Map<Id, CodeTestRunResult>();

        Map<String, List<ALM_Job__c>> jobsGroupedByInstanceId = GroupBy.Strings(ALM_Job__c.Source_Instance__c, completedJobs);
        Map<Id,Auth_User__c> instanceIdToAuthUser = OAuthServices.getAuthUsersForTools(jobsGroupedByInstanceId.keySet());

        for (Id instanceId : instanceIdToAuthUser.keySet()) {
            Auth_User__c authUser = instanceIdToAuthUser.get(instanceId);
            Set<String> asyncJobIds = new Set<String>();
            for (ALM_Job__c job : jobsGroupedByInstanceId.get(instanceId)) {
                asyncJobIds.add(job.Async_Apex_Job_Id__c);
            }

            // Try to retrieve test run results for jobs, or create error results if this fails.
            try {
                CodeTestRunResult codeTestResult = ToolingServices.getTestResults(authUser, asyncJobIds);
                for (ALM_Job__c job : jobsGroupedByInstanceId.get(instanceId)) {
                    jobIdToTestResultsToReturn.put(job.Id, codeTestResult);
                }
            } catch (Exception e) {
                for (ALM_Job__c job : jobsGroupedByInstanceId.get(instanceId)) {
                    CodeTestRunResult errorRecord = new CodeTestRunResult();
                    errorRecord.error = e;
                    jobIdToTestResultsToReturn.put(job.Id, errorRecord);
                }
            }
        }

        return jobIdToTestResultsToReturn;
    }

    /**
    * Creates code coverage objects from the given coverage result.
    * @param coverage - A code coverage result.
    * @param job - The test run job. May be modified as a side effect.
    * @param applicationResult - The application result related to the coverage's test run. May be modified as a side effect.
    * @param unitTestSummary - The unit test summary related to the coverage's test run. May be modified as a side effect.
    * @return A collection of code coverage objects.
    */
    public static List<Code_Coverage__c> createCoverageObjectsForJob(CodeCoverageAggregate coverage, ALM_Job__c job, ALM_Application_Result__c applicationResult, Unit_Test_Summary__c unitTestSummary) {
        if (coverage == null || job == null || applicationResult == null || unitTestSummary == null) {
            return null;
        }

        List<Code_Coverage__c> codeCoverageResults = coverage.deconstructIntoSobjectRecords();

        if (coverage.error != null) {
            ALMJobServices.markJobAsFailure(job, ERROR_RETRIEVAL_COVERAGE);
            ALMApplicationResultServices.markResultAsFailure(applicationResult, ERROR_RETRIEVAL_COVERAGE);
            ALMApplicationResultServices.appendWarning(applicationResult, coverage.error.getMessage());

            unitTestSummary.System_Error__c = true;
        } else {
            ALMApplicationResultServices.markResultAsSuccess(applicationResult);

            for (Code_Coverage__c codeCoverageResult : codeCoverageResults) {
                codeCoverageResult.Unit_Test_Summary__c = unitTestSummary.Id;

                unitTestSummary.Apex_Lines_Covered__c =
                    unitTestSummary.Apex_Lines_Covered__c != null ?
                    unitTestSummary.Apex_Lines_Covered__c + codeCoverageResult.Lines_Covered__c :
                    codeCoverageResult.Lines_Covered__c;
                unitTestSummary.Apex_Total_LOC__c =
                    unitTestSummary.Apex_Total_LOC__c != null ?
                    unitTestSummary.Apex_Total_LOC__c + codeCoverageResult.Total_Lines__c :
                    codeCoverageResult.Total_Lines__c;
            }
        }

        return codeCoverageResults;
    }

    /**
    * Creates unit test failure objects from the given code test run result.
    * @param testResult - A code test run result.
    * @param job - The test run job. May be modified as a side effect.
    * @param applicationResult - The application result related to the test result's test run. May be modified as a side effect.
    * @param unitTestSummary - The unit test summary related to the test result's test run. May be modified as a side effect.
    * @return A collection of unit test failure objects.
    */
    public static List<Unit_Test_Failure__c> createUnitTestFailureObjectsForJob(CodeTestRunResult testResult, ALM_Job__c job, ALM_Application_Result__c applicationResult, Unit_Test_Summary__c unitTestSummary) {
        if (testResult == null || job == null || applicationResult == null || unitTestSummary == null) {
            return null;
        }

        List<Unit_Test_Failure__c> unitTestFailureResults = testResult.deconstructIntoSobjectRecords();

        if (testResult.error != null) {
            ALMJobServices.markJobAsFailure(job, ERROR_RETRIEVAL_FAILURES);
            ALMApplicationResultServices.markResultAsFailure(applicationResult, ERROR_RETRIEVAL_FAILURES);
            ALMApplicationResultServices.appendWarning(applicationResult, testResult.error.getMessage());

            unitTestSummary.System_Error__c = true;
        } else {
            ALMApplicationResultServices.markResultAsSuccess(applicationResult);

            for (Unit_Test_Failure__c unitTestFailureResult : unitTestFailureResults) {
                unitTestFailureResult.Unit_Test_Summary__c = unitTestSummary.Id;
            }

            accumulateTestFailuresOntoSummary(unitTestSummary, unitTestFailureResults);
        }

        return unitTestFailureResults;
    }

    public static void updateJobsToScheduled(List<ALM_Job__c> completedJobs) {
        for (ALM_Job__c job : completedJobs) {
            job.Status__c = SCHEDULED_STATUS;
        }
        try {
            update completedJobs;
        }
        catch (DMLException dex) {
            throw dex;
        }

    }

    private static void accumulateTestFailuresOntoSummary(Unit_Test_Summary__c unitTestSummary, List<Unit_Test_Failure__c> unitTestFailures) {
        String unitTestFailureString = 
            unitTestSummary.Error_Details__c != null ? 
            unitTestSummary.Error_Details__c : 
            '';

        for (Unit_Test_Failure__c unitTestFailure : unitTestFailures) {
            unitTestFailureString += 
                unitTestFailure.Class_Name__c + '.' + 
                unitTestFailure.Method_Name__c + ': ' + 
                unitTestFailure.Message__c + 
                '\n\n';
        }

        if (!String.isBlank(unitTestFailureString)) {
            Integer maxLength = Unit_Test_Summary__c.Error_Details__c.getDescribe().getLength();

            if (unitTestFailureString.length() > maxLength) {
                unitTestSummary.Error_Details__c = 
                    unitTestFailureString.abbreviate(maxLength - SUMMARY_FAILURES_TRUNCATED.length()) + 
                    SUMMARY_FAILURES_TRUNCATED;
            } else {
                unitTestSummary.Error_Details__c = unitTestFailureString;
            }
        }
    }

    private static Map<Id, Set<String>> mapInstanceIdToAsyncJobIds(List<ALM_Job__c> jobs) {
        Map<Id, List<ALM_Job__c>> jobsGroupedByInstanceId = GroupBy.Ids(ALM_Job__c.Source_Instance__c, jobs);

        Map<Id, Set<String>> instanceIdToAsyncJobIds = new Map<Id, Set<String>>();
        for (Id instanceId : jobsGroupedByInstanceId.keySet()) {
            Set<String> asyncJobIds = new Set<String>();

            for (ALM_Job__c job : jobsGroupedByInstanceId.get(instanceId)) {
                if (job.Async_Apex_Job_Id__c != null) {
                    asyncJobIds.add(job.Async_Apex_Job_Id__c);
                }
            }

            if (!asyncJobIds.isEmpty()) {
                instanceIdToAsyncJobIds.put(instanceId, asyncJobIds);
            }
        }

        return instanceIdToAsyncJobIds;
    }
}