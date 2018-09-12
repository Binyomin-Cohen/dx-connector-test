@isTest
private class TestALMJobServices {

    static Instances__c source;
    static Instances__c target;
    static Auth_User__c sourceAuth;
    static Auth_User__c targetAuth;

    private static void setup() {
        source = new Instances__c(Name='dev');
        target = new Instances__c(Name='ALM Org');
        insert new List<Instances__c> {source, target};

        sourceAuth = TestingUtils.createAuthUser(UserInfo.getUserId(), source.Id, true);
        targetAuth = TestingUtils.createAuthUser(UserInfo.getUserId(), target.Id, true);
    }


    /**
    * ALL getJobsToRun() tests use DateTime.now() as the Start/End Schedule
    * date in order to avoid test failures depending on the time of day the
    * test(s) was run
    */
    static testMethod void getJobsToRun_validParams_returnsSCANJob() {
        setup();
        DateTime now = DateTime.now();

        ALM_Job__c scanJob = TestingUtils.buildDefaultScanJob(source, target);
        // Put schedule time around current time
        scanJob.Scheduled_Start_Time__c = now;
        scanJob.Scheduled_End_Time__c = now;
        // Setup interval every 2 hours
        scanJob.Interval__c = 2;
        scanJob.Last_Queue_Time__c = now.addHours(-4);
        insert scanJob;

        Test.startTest();
            List<ALMJob> jobs = ALMJobServices.getJobsToRun(ALMJobServices.ToolType.SCAN);
        Test.stopTest();

        System.assertEquals(1, jobs.size(), 'There should be a single runnable job');
    }

    static testMethod void getJobsToRun_outsideSchedule_returnsEmptyList() {
        setup();
        DateTime now = DateTime.now();

        ALM_Job__c scanJob = TestingUtils.buildDefaultScanJob(source, target);
        // Put schedule time around current time
        scanJob.Scheduled_Start_Time__c = now.addHours(1);
        scanJob.Scheduled_End_Time__c = now.addHours(2);
        insert scanJob;

        Test.startTest();
            List<ALMJob> jobs = ALMJobServices.getJobsToRun(ALMJobServices.ToolType.SCAN);
        Test.stopTest();

        System.assertEquals(true, jobs.isEmpty(), 'There should be no runnable jobs');
    }

    static testMethod void getJobsToRun_beforeInterval_returnsEmptyList() {
        setup();
        DateTime now = DateTime.now();

        ALM_Job__c scanJob = TestingUtils.buildDefaultScanJob(source, target);
        // Put schedule time around current time
        scanJob.Scheduled_Start_Time__c = now;
        scanJob.Scheduled_End_Time__c = now;
        // Make interval to be greater than last queue time
        // Every 6 hours
        scanJob.Interval__c = 6;
        scanJob.Last_Queue_Time__c = now.addHours(-4);
        insert scanJob;

        Test.startTest();
            List<ALMJob> jobs = ALMJobServices.getJobsToRun(ALMJobServices.ToolType.SCAN);
        Test.stopTest();

        System.assertEquals(true, jobs.isEmpty(), 'There should be no runnable jobs');
    }

    static testMethod void getJobsToRun_afterLongInterval_returnsSCANJob() {
        setup();
        DateTime now = DateTime.now();

        ALM_Job__c scanJob = TestingUtils.buildDefaultScanJob(source, target);
        // Put schedule time around current time
        scanJob.Scheduled_Start_Time__c = now;
        scanJob.Scheduled_End_Time__c = now;
        // Make last queue time be several days before interval
        scanJob.Interval__c = 2;
        scanJob.Last_Queue_Time__c = now.addHours(-72);
        insert scanJob;

        Test.startTest();
            List<ALMJob> jobs = ALMJobServices.getJobsToRun(ALMJobServices.ToolType.SCAN);
        Test.stopTest();

        System.assertEquals(1, jobs.size(), 'There should be one runnable job after a long interval');
    }

    static testMethod void executeBUTRJobs_success() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.RunTestsAsynchronous, ALMRestServices.HTTP_OK));

        String testRefreshToken = 'Test Refresh Token';

        setup();

        ALM_Job__c testJob = TestingUtils.buildDefaultButrJob(source, target);
        insert testJob;

        sourceAuth.Refresh_Token__c = testRefreshToken;

        Test.startTest();

            ALMJobServices.executeBUTRJobs(new Set<Id>{testJob.Id}, new Map<Id, Auth_User__c>{source.Id => sourceAuth});

        Test.stopTest();

        ALM_Job__c actualUpdatedJob = [SELECT Status__c, Async_Apex_Job_Id__c FROM ALM_Job__c WHERE Id = :testJob.Id];
        Auth_User__c actualUpdatedAuthUser = [SELECT Refresh_Token__c FROM Auth_User__c WHERE Id = :sourceAuth.Id];
        List<ALM_Application_Result__c> actualUpdatedResults = [SELECT Result__c FROM ALM_Application_Result__c WHERE ALM_Job__c = :testJob.Id];

        System.assertEquals(SCANServices.TOOL_STATUS_RUNNING, actualUpdatedJob.Status__c, 'The job status should be "Running".');
        System.assertEquals(MockToolingAPI.RETURN_ASYNC_JOB_ID, actualUpdatedJob.Async_Apex_Job_Id__c, 'The job async ID should be populated.');

        System.assertEquals(testRefreshToken, actualUpdatedAuthUser.Refresh_Token__c, 'The refresh token should be updated.');

        System.assertEquals(1, actualUpdatedResults.size(), 'There should be one application result created.');
        System.assertEquals(SCANServices.TOOL_STATUS_RUNNING, actualUpdatedResults[0].Result__c, 'The application result result should be "Running".');
    }

    static testMethod void executeBUTRJobs_failure_errorResponse() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.RunTestsAsynchronous, ALMRestServices.HTTP_UNAUTHORIZED));

        setup();

        ALM_Job__c testJob = TestingUtils.buildDefaultButrJob(source, target);
        insert testJob;

        Test.startTest();

            ALMJobServices.executeBUTRJobs(new Set<Id>{testJob.Id}, new Map<Id, Auth_User__c>{source.Id => sourceAuth});

        Test.stopTest();

        ALM_Job__c actualUpdatedJob = [
            SELECT Status__c, Async_Apex_Job_Id__c, Login_Error__c, Last_Failure__c, Errors__c
            FROM ALM_Job__c
            WHERE Id = :testJob.Id
        ];
        List<ALM_Application_Result__c> actualUpdatedResults = [
            SELECT Result__c, Error_Message__c, Error_Code__c, Run_Time__c
            FROM ALM_Application_Result__c
            WHERE ALM_Job__c = :testJob.Id
        ];

        System.assertEquals(SCANServices.TOOL_STATUS_SCHEDULED, actualUpdatedJob.Status__c, 'The job status should be "Scheduled".');
        System.assertEquals(null, actualUpdatedJob.Async_Apex_Job_Id__c, 'The job async ID should not be populated.');
        System.assertEquals(false, actualUpdatedJob.Login_Error__c, 'The login error flag should not be set.');
        System.assertNotEquals(null, actualUpdatedJob.Last_Failure__c, 'The last failure time should be set.');
        System.assert(actualUpdatedJob.Errors__c.contains(String.valueOf(ALMRestServices.HTTP_UNAUTHORIZED)), 'The errors text should contain the error code.');

        System.assertEquals(1, actualUpdatedResults.size(), 'There should be one application result created.');
        System.assertEquals(SCANServices.FAILURE_STATUS, actualUpdatedResults[0].Result__c, 'The application result should be failure.');
        System.assert(actualUpdatedResults[0].Error_Code__c.contains(String.valueOf(ALMRestServices.HTTP_UNAUTHORIZED)), 'The proper exception should be thrown.');
        System.assert(actualUpdatedResults[0].Error_Message__c.contains(String.valueOf(ALMRestServices.HTTP_UNAUTHORIZED)), 'The proper exception should be thrown.');
        System.assertNotEquals(null, actualUpdatedResults[0].Run_Time__c, 'The run time should be set.');
    }

    static testMethod void executeBUTRJobs_failure_unauthorizedEndpoint() {
        Boolean remoteSiteSettingsTest = true;
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(remoteSiteSettingsTest));

        setup();

        ALM_Job__c testJob = TestingUtils.buildDefaultButrJob(source, target);
        insert testJob;

        Test.startTest();

            ALMJobServices.executeBUTRJobs(new Set<Id>{testJob.Id}, new Map<Id, Auth_User__c>{source.Id => sourceAuth});

        Test.stopTest();

        ALM_Job__c actualUpdatedJob = [
            SELECT Status__c, Async_Apex_Job_Id__c, Login_Error__c, Last_Failure__c, Errors__c
            FROM ALM_Job__c
            WHERE Id = :testJob.Id
        ];
        List<ALM_Application_Result__c> actualUpdatedResults = [
            SELECT Result__c, Error_Message__c, Error_Code__c, Run_Time__c
            FROM ALM_Application_Result__c
            WHERE ALM_Job__c = :testJob.Id
        ];

        System.assertEquals(SCANServices.TOOL_STATUS_SCHEDULED, actualUpdatedJob.Status__c, 'The job status should be "Scheduled".');
        System.assertEquals(null, actualUpdatedJob.Async_Apex_Job_Id__c, 'The job async ID should not be populated.');
        System.assertEquals(false, actualUpdatedJob.Login_Error__c, 'The login error flag should not be set.');
        System.assertNotEquals(null, actualUpdatedJob.Last_Failure__c, 'The last failure time should be set.');
        System.assert(actualUpdatedJob.Errors__c.contains(Label.Unauthorized_Endpoint_Error), 'The errors text should contain the error message.');
        System.assert(actualUpdatedJob.Errors__c.contains(ALMJobServices.ERROR_CODE_UNAUTHORIZED_ENDPOINT), 'The errors text should contain the error code.');

        System.assertEquals(1, actualUpdatedResults.size(), 'There should be one application result created.');
        System.assertEquals(SCANServices.FAILURE_STATUS, actualUpdatedResults[0].Result__c, 'The application result should be failure.');
        System.assertEquals(ALMJobServices.ERROR_CODE_UNAUTHORIZED_ENDPOINT, actualUpdatedResults[0].Error_Code__c, 'The proper error code should be displayed');
        System.assert(actualUpdatedResults[0].Error_Message__c.contains(Label.Unauthorized_Endpoint_Error), 'The proper error message should be displayed');
        System.assertNotEquals(null, actualUpdatedResults[0].Run_Time__c, 'The run time should be set.');
    }

    static testMethod void executeBUTRJobs_failure_badAuth() {
        setup();
        sourceAuth.Is_Refresh_Token_Valid__c = false;

        ALM_Job__c testJob = TestingUtils.buildDefaultButrJob(source, target);
        insert testJob;

        Test.startTest();

            ALMJobServices.executeBUTRJobs(new Set<Id>{testJob.Id}, new Map<Id, Auth_User__c>{source.Id => sourceAuth});

        Test.stopTest();

        ALM_Job__c actualUpdatedJob = [
            SELECT Status__c, Async_Apex_Job_Id__c, Login_Error__c, Last_Failure__c, Errors__c
            FROM ALM_Job__c
            WHERE Id = :testJob.Id
        ];
        List<ALM_Application_Result__c> actualUpdatedResults = [
            SELECT Result__c, Error_Message__c, Error_Code__c, Run_Time__c
            FROM ALM_Application_Result__c
            WHERE ALM_Job__c = :testJob.Id
        ];

        System.assertEquals(SCANServices.TOOL_STATUS_SCHEDULED, actualUpdatedJob.Status__c, 'The job status should be "Scheduled".');
        System.assertEquals(null, actualUpdatedJob.Async_Apex_Job_Id__c, 'The job async ID should not be populated.');
        System.assert(actualUpdatedJob.Login_Error__c, 'The login error flag should be set.');
        System.assertNotEquals(null, actualUpdatedJob.Last_Failure__c, 'The last failure time should be set.');
        System.assert(actualUpdatedJob.Errors__c.contains(ALMJobServices.ERROR_CODE_LOGIN), 'The errors text should contain the error code.');
        System.assert(actualUpdatedJob.Errors__c.contains(System.Label.Automated_Testing_Login_Error), 'The errors text should contain the error message.');

        System.assertEquals(1, actualUpdatedResults.size(), 'There should be one application result created.');
        System.assertEquals(SCANServices.FAILURE_STATUS, actualUpdatedResults[0].Result__c, 'The application result should be failure.');
        System.assert(actualUpdatedResults[0].Error_Message__c.contains(System.Label.Automated_Testing_Login_Error), 'The proper error message should be set.');
        System.assert(actualUpdatedResults[0].Error_Code__c.contains(ALMJobServices.ERROR_CODE_LOGIN), 'The proper error code should be set.');
        System.assertNotEquals(null, actualUpdatedResults[0].Run_Time__c, 'The run time should be set.');
    }

    static testMethod void executeBUTRJobs_failure_missingProperty() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.RunTestsAsynchronous, ALMRestServices.HTTP_FORBIDDEN));

        setup();

        ALM_Job__c testJob = TestingUtils.buildDefaultButrJob(source, target);
        insert testJob;

        Test.startTest();

            ALMJobServices.executeBUTRJobs(new Set<Id>{testJob.Id}, new Map<Id, Auth_User__c>{source.Id => sourceAuth});

        Test.stopTest();

        ALM_Job__c actualUpdatedJob = [
            SELECT Status__c, Async_Apex_Job_Id__c, Login_Error__c, Last_Failure__c, Errors__c
            FROM ALM_Job__c
            WHERE Id = :testJob.Id
        ];
        List<ALM_Application_Result__c> actualUpdatedResults = [
            SELECT Result__c, Error_Message__c, Error_Code__c, Run_Time__c
            FROM ALM_Application_Result__c
            WHERE ALM_Job__c = :testJob.Id
        ];

        System.assertEquals(SCANServices.TOOL_STATUS_SCHEDULED, actualUpdatedJob.Status__c, 'The job status should be "Scheduled".');
        System.assertEquals(null, actualUpdatedJob.Async_Apex_Job_Id__c, 'The job async ID should not be populated.');
        System.assertEquals(false, actualUpdatedJob.Login_Error__c, 'The login error flag should not be set.');
        System.assertNotEquals(null, actualUpdatedJob.Last_Failure__c, 'The last failure time should be set.');
        System.assert(actualUpdatedJob.Errors__c.contains(ALMJobServices.ERROR_CODE_NO_TESTS), 'The errors text should contain the error code.');
        System.assert(actualUpdatedJob.Errors__c.contains(System.Label.Automated_Testing_No_Tests_Error), 'The errors text should contain the error message.');

        System.assertEquals(1, actualUpdatedResults.size(), 'There should be one application result created.');
        System.assertEquals(SCANServices.FAILURE_STATUS, actualUpdatedResults[0].Result__c, 'The application result should be failure.');
        System.assert(actualUpdatedResults[0].Error_Code__c.contains(String.valueOf(ALMJobServices.ERROR_CODE_NO_TESTS)), 'The proper error code should be set.');
        System.assert(actualUpdatedResults[0].Error_Message__c.contains(String.valueOf(System.Label.Automated_Testing_No_Tests_Error)), 'The proper error message should be set.');
        System.assertNotEquals(null, actualUpdatedResults[0].Run_Time__c, 'The run time should be set.');
    }

    @isTest
    static void executeBUTRJobs_failure_testsAlreadyInProgress_AT_running() {
        Test.setMock(
            HttpCalloutMock.class,
            new MockToolingAPI(
                MockToolingAPI.Action.RunTestsAsynchronous,
                ALMRestServices.HTTP_BAD_REQUEST,
                ALMJobServices.ERROR_CODE_ALREADY_IN_PROCESS
            )
        );

        setup();

        ALM_Job__c testJob = TestingUtils.buildDefaultButrJob(source, target);
        testJob.Status__c = SCANServices.TOOL_STATUS_RUNNING;
        insert testJob;

        ALM_Application_Result__c inProgressResult = new ALM_Application_Result__c(ALM_Job__c = testJob.Id, Result__c = SCANServices.TOOL_STATUS_RUNNING);
        insert inProgressResult;

        Test.startTest();

            ALMJobServices.executeBUTRJobs(new Set<Id>{testJob.Id}, new Map<Id, Auth_User__c>{source.Id => sourceAuth});

        Test.stopTest();

        ALM_Job__c actualUpdatedJob = [
            SELECT Status__c, Async_Apex_Job_Id__c, Login_Error__c, Last_Failure__c, Errors__c
            FROM ALM_Job__c
            WHERE Id = :testJob.Id
        ];
        List<ALM_Application_Result__c> actualUpdatedResults = [
            SELECT Result__c, Error_Message__c, Error_Code__c, Run_Time__c
            FROM ALM_Application_Result__c
            WHERE ALM_Job__c = :testJob.Id AND Id != :inProgressResult.Id
            LIMIT 1
        ];
        inProgressResult = [SELECT Name FROM ALM_Application_Result__c WHERE Id = :inProgressResult.Id];

        System.assertEquals(SCANServices.TOOL_STATUS_RUNNING, actualUpdatedJob.Status__c, 'The job status should be "Scheduled".');
        System.assertEquals(null, actualUpdatedJob.Async_Apex_Job_Id__c, 'The job async ID should not be populated.');
        System.assertEquals(false, actualUpdatedJob.Login_Error__c, 'The login error flag should not be set.');
        System.assertEquals(null, actualUpdatedJob.Last_Failure__c, 'The last failure time should not be set.');

        System.assertEquals(1, actualUpdatedResults.size(), 'There should be one application result created.');
        System.assertEquals(SCANServices.FAILURE_STATUS, actualUpdatedResults[0].Result__c, 'The application result should be failure.');
        System.assert(actualUpdatedResults[0].Error_Code__c.contains(String.valueOf(ALMJobServices.ERROR_CODE_JOB_IN_PROGRESS)), 'The proper exception should be thrown.');
        System.assert(actualUpdatedResults[0].Error_Message__c.contains(String.valueOf(inProgressResult.Name)), 'The proper exception should be thrown.');
        System.assertNotEquals(null, actualUpdatedResults[0].Run_Time__c, 'The run time should be set.');
    }

    @isTest
    static void executeBUTRJobs_failure_testsAlreadyInProgress_noAT() {
        Test.setMock(
            HttpCalloutMock.class,
            new MockToolingAPI(
                MockToolingAPI.Action.RunTestsAsynchronous,
                ALMRestServices.HTTP_BAD_REQUEST,
                ALMJobServices.ERROR_CODE_ALREADY_IN_PROCESS
            )
        );

        setup();

        ALM_Job__c testJob = TestingUtils.buildDefaultButrJob(source, target);
        insert testJob;

        Test.startTest();

            ALMJobServices.executeBUTRJobs(new Set<Id>{testJob.Id}, new Map<Id, Auth_User__c>{source.Id => sourceAuth});

        Test.stopTest();

        ALM_Job__c actualUpdatedJob = [
            SELECT Status__c, Async_Apex_Job_Id__c, Login_Error__c, Last_Failure__c, Errors__c
            FROM ALM_Job__c
            WHERE Id = :testJob.Id
        ];
        List<ALM_Application_Result__c> actualUpdatedResults = [
            SELECT Result__c, Error_Message__c, Error_Code__c, Run_Time__c
            FROM ALM_Application_Result__c
            WHERE ALM_Job__c = :testJob.Id
            LIMIT 1
        ];

        System.assertEquals(SCANServices.TOOL_STATUS_SCHEDULED, actualUpdatedJob.Status__c, 'The job status should be "Scheduled".');
        System.assertEquals(null, actualUpdatedJob.Async_Apex_Job_Id__c, 'The job async ID should not be populated.');
        System.assertEquals(false, actualUpdatedJob.Login_Error__c, 'The login error flag should not be set.');
        System.assertNotEquals(null, actualUpdatedJob.Last_Failure__c, 'The last failure time should be set.');

        System.assertEquals(1, actualUpdatedResults.size(), 'There should be one application result created.');
        System.assertEquals(SCANServices.FAILURE_STATUS, actualUpdatedResults[0].Result__c, 'The application result should be failure.');
        System.assert(actualUpdatedResults[0].Error_Code__c.contains(String.valueOf(ALMJobServices.ERROR_CODE_JOB_IN_PROGRESS)), 'The proper exception should be thrown.');
        System.assert(actualUpdatedResults[0].Error_Message__c.contains(System.Label.Org_Tests_In_Progress_Error), 'The proper exception should be thrown.');
        System.assertNotEquals(null, actualUpdatedResults[0].Run_Time__c, 'The run time should be set.');
    }

    static testMethod void markJobAsFailure() {
        String testErrorMessage = 'Test Error Message';
        String testErrorCode = 'Test Error Code';

        ALM_Job__c testJob = new ALM_Job__c();

        Test.startTest();

            ALMJobServices.markJobAsFailure(testJob, testErrorMessage, testErrorCode);

        Test.stopTest();

        System.assert(testJob.Errors__c.contains(testErrorCode), 'The errors text should contain the error code.');
        System.assert(testJob.Errors__c.contains(testErrorMessage), 'The errors text should contain the error message.');
        System.assertEquals(SCANServices.TOOL_STATUS_SCHEDULED, testJob.Status__c, 'The job should be scheduled.');
        System.assertNotEquals(null, testJob.Last_Failure__c, 'The last failure time should be set.');
    }

    static testMethod void markJobAsSuccess() {
        ALM_Job__c testJob = new ALM_Job__c();

        Test.startTest();

            ALMJobServices.markJobAsSuccess(testJob);

        Test.stopTest();

        System.assertEquals(null, testJob.Errors__c, 'The errors text should be empty.');
        System.assertEquals(SCANServices.TOOL_STATUS_SCHEDULED, testJob.Status__c, 'The job should be scheduled.');
        System.assertNotEquals(null, testJob.Last_Successful_Run__c, 'The last successful run time should be set.');
    }

    static testMethod void startBUTRJobs() {
        TestingUtils.deleteExistingJobs( new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.RunTestsAsynchronous, ALMRestServices.HTTP_OK));
        //Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        DateTime scheduleTime = DateTime.now().addMinutes( 1 );

        String testRefreshToken = 'Test Refresh Token';

        setup();

        ALM_Job__c testJob = TestingUtils.buildDefaultButrJob(source, target);
        insert testJob;

        sourceAuth.Refresh_Token__c = testRefreshToken;

        Test.startTest();

            ALMJobServices.startBUTRJobs(new Set<Id>{testJob.Id});

        Test.stopTest();
        // Get the information from the CronTrigger API object
        List<CronTrigger> cronTriggers = [SELECT Id, CronJobDetail.Name, CronExpression, TimesTriggered, NextFireTime
                                          FROM CronTrigger
                                          WHERE CronJobDetail.Name = :ExecuteTestMonitorBatch.BATCH_JOB_TITLE];

        /*
        System.assertEquals( 1, cronTriggers.size(), 'Only one Scheduled Job Should be found');

        // Verify the job has not run
        System.assertEquals(0, cronTriggers[0].TimesTriggered, 'The scheduled job should not have fired yet');

        // Verify the next time the job will run
        System.assertEquals(scheduleTime.Date(), cronTriggers[0].NextFireTime.Date(), 'The Job should be scheduled to start at the correct Date');
        System.assertEquals(scheduleTime.hour(), cronTriggers[0].NextFireTime.hour(), 'The Job should be scheduled to start at the correct hour');
        System.assertEquals(scheduleTime.minute(), cronTriggers[0].NextFireTime.minute(), 'The Job should be scheduled to start at the correct minute');
        */
    }

    private static testMethod void getToolName_null() {
        ALMJobServices.ToolType toolType = null;

        Test.startTest();

            String toolName = ALMJobServices.getToolName(toolType);

        Test.stopTest();

        System.assertEquals(null, toolName, 'The proper tool name should be returned.');
    }

    private static testMethod void getToolName_scan() {
        ALMJobServices.ToolType toolType = ALMJobServices.ToolType.SCAN;

        Test.startTest();

            String toolName = ALMJobServices.getToolName(toolType);

        Test.stopTest();

        System.assertEquals('SCAN', toolName, 'The proper tool name should be returned.');
    }

    private static testMethod void getToolName_automatedTesting() {
        ALMJobServices.ToolType toolType = ALMJobServices.ToolType.AUTOMATED_TESTING;

        Test.startTest();

            String toolName = ALMJobServices.getToolName(toolType);

        Test.stopTest();

        System.assertEquals('Automated Testing', toolName, 'The proper tool name should be returned.');
    }

    private static testMethod void getToolName_snapshot() {
        ALMJobServices.ToolType toolType = ALMJobServices.ToolType.SNAPSHOT;

        Test.startTest();

            String toolName = ALMJobServices.getToolName(toolType);

        Test.stopTest();

        System.assertEquals('Snapshot', toolName, 'The proper tool name should be returned.');
    }

    private static testMethod void getToolName_repoSync() {
        ALMJobServices.ToolType toolType = ALMJobServices.ToolType.VC_REPO_SYNC;

        Test.startTest();

            String toolName = ALMJobServices.getToolName(toolType);

        Test.stopTest();

        System.assertEquals('Repo_Sync', toolName, 'The proper tool name should be returned.');
    }
}