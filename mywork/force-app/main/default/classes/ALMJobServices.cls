public with sharing class ALMJobServices {
    public static final String RESPONSE_MISSING_PROPERTY = 'Always provide a classes, suites, tests, or testLevel property';

    public static final String ERROR_CODE_LOGIN = 'LOGIN ERROR';
    public static final String ERROR_CODE_NO_TESTS = 'NO TESTS';
    public static final String ERROR_CODE_UNAUTHORIZED_ENDPOINT = 'UNAUTHORIZED ENDPOINT';
    public static final String ERROR_CODE_ALREADY_IN_PROCESS = 'ALREADY_IN_PROCESS';
    public static final String ERROR_CODE_JOB_IN_PROGRESS = 'JOB IN-PROGRESS';
    public static final String UNAUTHORIZED_ENDPOINT_IDENTIFIER = AdminInstanceManagementController.UNAUTHORIZED_ENDPOINT_IDENTIFIER;

    public enum ToolType {
        SCAN,
        AUTOMATED_TESTING,
        SNAPSHOT,
        VC_REPO_SYNC
    }
    private static final Map<ToolType, String> toolTypeToToolName = new Map<ToolType, String>{
        ToolType.SCAN => 'SCAN',
        ToolType.AUTOMATED_TESTING => 'Automated Testing',
        ToolType.SNAPSHOT => 'Snapshot',
        ToolType.VC_REPO_SYNC => 'Repo_Sync'
    };

    /**
    * Returns the BUTR job for a given source instance.
    * @param sourceInstanceId - The source ID for the BUTR job to fetch.
    * @return ALM_Job__c - The BUTR job corresponding to the source instance ID.
    * @throws ALMException
    */
    public static ALM_Job__c getButrJobForInstance(Id sourceInstanceId) {
        if (String.isBlank(sourceInstanceId)) {
            throw new ALMException('Instance ID cannot be empty.');
        }

        List<ALM_Job__c> butrJobs = [
            select  Id,
                    Status__c, Source_Instance__c, Last_Queue_Time__c, Last_Run_Time__c,
                    Scheduled_On_Monday__c, Scheduled_On_Tuesday__c, Scheduled_On_Wednesday__c, Scheduled_On_Thursday__c,
                    Scheduled_On_Friday__c, Scheduled_On_Saturday__c, Scheduled_On_Sunday__c,
                    Scheduled_Start_Time__c, Scheduled_End_Time__c,
                    Tool__c, Interval__c, Mail_To__c
            from ALM_Job__c
            where Source_Instance__c = :sourceInstanceId
            and Tool__c = :getToolName(ToolType.AUTOMATED_TESTING)
        ];

        if(butrJobs.size() > 1) {
            throw new ALMException('Multiple BUTR jobs found for this source instance ID.');
        }

        return butrJobs.isEmpty() ? null : butrJobs[0];
    }

    /**
    * Retrieves jobs that should be run now  filtering by tool type
    * @param toolType   The type of job to look for
    * @return List<ALMJob>
    */
    public static List<ALMJob> getJobsToRun(ALMJobServices.ToolType toolType) {
        List<ALMJob> jobsToRun = new List<ALMJob>();
        List<ALM_Job__c> allJobs = [
            SELECT  Id, Components__c, Excluded_Types__c, Max_Package_Size__c, Sync_Descriptions__c, Include_Profiles__c,
                    Include_Permission_Sets__c, Source_Instance__c, Target_Instance__c, Last_Queue_Time__c, Last_Run_Time__c,
                    Scheduled_On_Monday__c, Scheduled_On_Tuesday__c, Scheduled_On_Wednesday__c, Scheduled_On_Thursday__c,
                    Scheduled_On_Friday__c, Scheduled_On_Saturday__c, Scheduled_On_Sunday__c, Scheduled_Start_Time__c,
                    Scheduled_End_Time__c, Tool__c, Interval__c, Mail_To__c
            FROM ALM_Job__c
            WHERE Tool__c = :ALMJobServices.getToolName(toolType)
            AND Status__c != :SCANServices.TOOL_STATUS_ON_HOLD
        ];

        if(allJobs.isEmpty()) {
            return jobsToRun;
        }

        for(ALM_Job__c currJob : allJobs) {
            ALMJob currAlmJob = new ALMJob(currJob);
            if(currAlmJob.isRunnableNow()) {
                jobsToRun.add(currAlmJob);
            }
        }

        return jobsToRun;
    }

    /**
    * Starts the test jobs associated with the provided job IDs.
    * @param butrJobIds - A set of IDs for the test jobs to start.
    */
    @future (Callout=true)
    public static void startBUTRJobs(Set<Id> butrJobIds) {
        try {
            Map<Id, Auth_User__c> instanceIdToAuthUser = SCANServices.reauthorizeJobs(butrJobIds);

            Boolean jobsRunning = executeBUTRJobs(butrJobIds, instanceIdToAuthUser);

            update instanceIdToAuthUser.values();

            if (jobsRunning && !ExecuteTestMonitorBatchServices.isMonitorBatchScheduledOrRunning()) {
                Integer minutesFromNow = 1;
                DateTime scheduledTime = DateTime.now().addMinutes(minutesFromNow);

                String cronExpression =
                    scheduledTime.second() + ' ' +
                    scheduledTime.minute() + ' ' +
                    scheduledTime.hour() + ' ' +
                    scheduledTime.day() + ' ' +
                    scheduledTime.month() + ' ? ' +
                    scheduledTime.year();

                System.schedule(ExecuteTestMonitorBatch.BATCH_JOB_TITLE, cronExpression, new ExecuteTestMonitorBatch());
            }
        } catch (Exception e) {
            ALMLogServices.error(e, ALMLogServices.Application.AUTOMATED_TESTING);
        }
    }

    @TestVisible
    private static Boolean executeBUTRJobs(Set<Id> butrJobIds, Map<Id, Auth_User__c> instanceIdToAuthUser) {
        Boolean jobsRunning = false;

        List<ALM_Job__c> jobs = getButrJobsToExecute(butrJobIds);

        List<ALM_Application_Result__c> applicationResults = new List<ALM_Application_Result__c>();
        for (ALM_Job__c job : jobs) {
            DateTime now = DateTime.now();

            job.Last_Run_Time__c = now;

            ALM_Application_Result__c applicationResult = ALMApplicationResultServices.buildApplicationResult(
                job,
                ToolType.AUTOMATED_TESTING,
                null,
                now
            );

            Auth_User__c authUser = instanceIdToAuthUser.get(job.Source_Instance__c);

            if (authUser.Is_Refresh_Token_Valid__c) {
                try {
                    job.Async_Apex_Job_Id__c = ToolingServices.runTestsAsynchronous(authUser);
                    job.Status__c = SCANServices.TOOL_STATUS_RUNNING;
                    applicationResult.Result__c = SCANServices.TOOL_STATUS_RUNNING;

                    jobsRunning = true;
                } catch (Exception e) {
                    if (e.getMessage().contains(RESPONSE_MISSING_PROPERTY)) {
                        markJobAsFailure(job, System.Label.Automated_Testing_No_Tests_Error, ERROR_CODE_NO_TESTS);
                        ALMApplicationResultServices.markResultAsFailure(applicationResult, System.Label.Automated_Testing_No_Tests_Error, ERROR_CODE_NO_TESTS);
                    } else if (e.getMessage().contains(UNAUTHORIZED_ENDPOINT_IDENTIFIER)) {
                        String errorMessage = System.Label.Unauthorized_Endpoint_Error +' '+ e.getMessage();
                        markJobAsFailure(job, errorMessage, ERROR_CODE_UNAUTHORIZED_ENDPOINT);
                        ALMApplicationResultServices.markResultAsFailure(applicationResult, errorMessage, ERROR_CODE_UNAUTHORIZED_ENDPOINT);
                    } else if (e.getMessage().contains(ERROR_CODE_ALREADY_IN_PROCESS)) {
                        List<ALM_Application_Result__c> results = [
                            SELECT Name
                            FROM ALM_Application_Result__c
                            WHERE ALM_Job__c = :job.Id AND Result__c = :SCANServices.TOOL_STATUS_RUNNING
                            ORDER BY CreatedDate DESC
                            LIMIT 1
                        ];

                        if (results.size() > 0) {
                            ALMApplicationResultServices.markResultAsFailure(
                                applicationResult,
                                String.format(System.Label.Automated_Testing_Tests_In_Progress_Error, new List<String>{results[0].Name}),
                                ERROR_CODE_JOB_IN_PROGRESS
                            );
                        } else {
                            ALMApplicationResultServices.markResultAsFailure(applicationResult, System.Label.Org_Tests_In_Progress_Error, ERROR_CODE_JOB_IN_PROGRESS);
                            markJobAsFailure(job, System.Label.Org_Tests_In_Progress_Error, ERROR_CODE_JOB_IN_PROGRESS);
                        }
                    } else {
                        markJobAsFailure(job, e.getMessage());
                        ALMApplicationResultServices.markResultAsFailure(applicationResult, e.getMessage());
                    }
                }
            } else {
                markJobAsFailure(job, System.Label.Automated_Testing_Login_Error, ERROR_CODE_LOGIN);
                ALMApplicationResultServices.markResultAsFailure(applicationResult, System.Label.Automated_Testing_Login_Error, ERROR_CODE_LOGIN);
            }

            applicationResults.add(applicationResult);
        }

        try {
            update jobs;
            update instanceIdToAuthUser.values();
            insert applicationResults;
        } catch (DMLException de) {
            ALMLogServices.error(de, ALMLogServices.Application.AUTOMATED_TESTING);
        }

        return jobsRunning;
    }

    /**
    * Marks a job as a failure.
    * @param job - The job to mark as a failure. May be modified as a side effect.
    * @param errorMessage - The error message to add to the job.
    */
    public static void markJobAsFailure(ALM_Job__c job, String errorMessage) {
        markJobAsFailure(job, errorMessage, null);
    }

    /**
    * Marks a job as a failure.
    * @param job - The job to mark as a failure. May be modified as a side effect.
    * @param errorMessage - The error message to add to the job.
    * @param errorCode - The error code to add to the job.
    */
    public static void markJobAsFailure(ALM_Job__c job, String errorMessage, String errorCode) {
        job.Errors__c = errorCode != null ? errorCode + ': ' + errorMessage : errorMessage;
        job.Status__c = SCANServices.TOOL_STATUS_SCHEDULED;
        job.Last_Failure__c = DateTime.now();
    }

    /**
    * Marks a job as a success.
    * @param job - The job to mark as a success. May be modified as a side effect.
    */
    public static void markJobAsSuccess(ALM_Job__c job) {
        job.Errors__c = null;
        job.Status__c = SCANServices.TOOL_STATUS_SCHEDULED;
        job.Last_Successful_Run__c = DateTime.now();
    }

    public static String getToolName(ToolType type) {
        return toolTypeToToolName.get(type);
    }
    
    // Get epoch-formatted time.
    public static Long getJobTime(ALM_Job__c job, Schema.SObjectField timeField) {
        if (job == null || timeField == null) {
            return null;
        }
        DateTime dateTimeValue;
        try {
	        dateTimeValue = ((DateTime)(job.get(timeField)));
        } catch (System.SObjectException sobjEx ){
		  throw new ALMException('An error occured setting the ALM Job field: ' + sobjEx.getMessage());
        }
        if (dateTimeValue == null) {
            return null;
        }

        Time timeValue = dateTimeValue.time();
        return timeValue != null ? DateTime.newInstance(Date.today(), timeValue).getTime() : null;
    }
    
    public static Map<Id, String> getMailToValues(Set<Id> jobIds) {
        List<ALM_Job__c> almJobs = [SELECT Id, Mail_To__c
                                    FROM ALM_Job__c
                                    WHERE Id in: jobIds];
        Map<Id, String> jobIdToEmailMap = new Map<Id, String>();
        for (ALM_Job__c job : almJobs) {
            jobIdToEmailMap.put(job.Id, job.Mail_To__c);
        }
        return jobIdToEmailMap;
    }
    
    private static List<ALM_Job__c> getButrJobsToExecute(Set<Id> butrJobIds) {
        return [
            SELECT Source_Instance__c, Status__c, Async_Apex_Job_Id__c
            FROM ALM_Job__c
            WHERE Id IN :butrJobIds AND Tool__c = :getToolName(ToolType.AUTOMATED_TESTING)
            FOR UPDATE
        ];
    }
}