@isTest
private class TestScanScheduler {
    @isTest
    private static void execute_scanJobs() {
        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();

        ALM_Job__c testJob = TestingUtils.buildScanJob(null, null, SCANServices.TOOL_STATUS_SCHEDULED);
        testJob.Scheduled_On_Monday__c = true;
        testJob.Scheduled_On_Tuesday__c = true;
        testJob.Scheduled_On_Wednesday__c = true;
        testJob.Scheduled_On_Thursday__c = true;
        testJob.Scheduled_On_Friday__c = true;
        testJob.Scheduled_On_Saturday__c = true;
        testJob.Scheduled_On_Sunday__c = true;
        testJob.Scheduled_Start_Time__c = DateTime.newInstance(2018, 1, 0, 0, 0, 0);
        testJob.Scheduled_End_Time__c = DateTime.newInstance(2018, 1, 0, 0, 0, 0);
        insert testJob;

        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));

        ScanScheduler scheduler = new ScanScheduler();

        Test.startTest();
            scheduler.execute(null);
        Test.stopTest();

        List<ALM_Job__c> actualJobs = [SELECT Status__c, Last_Queue_Time__c, Errors__c FROM ALM_Job__c WHERE Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN)];
        List<ALM_Application_Result__c> actualResults = [SELECT ALM_Job__c, Result__c FROM ALM_Application_Result__c WHERE ALM_Job__c = :testJob.Id];

        System.assertEquals(1, actualJobs.size(), 'One SCAN job should be retrieved.');
        System.assert(actualJobs[0].Last_Queue_Time__c != null, 'The last queue time should be set.');
        System.assertEquals(null, actualJobs[0].Errors__c, 'No errors should be encountered.');

        System.assertEquals(1, actualResults.size(), 'One SCAN result should be retrieved.');
        System.assertEquals(SCANServices.TOOL_STATUS_QUEUED, actualResults[0].Result__c, 'The SCAN result should be marked as queued.');
    }

    @isTest
    private static void execute_butrJobs() {
        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();

        ALM_Job__c testJob = TestingUtils.buildButrJob(null, SCANServices.TOOL_STATUS_SCHEDULED);
        testJob.Scheduled_On_Monday__c = true;
        testJob.Scheduled_On_Tuesday__c = true;
        testJob.Scheduled_On_Wednesday__c = true;
        testJob.Scheduled_On_Thursday__c = true;
        testJob.Scheduled_On_Friday__c = true;
        testJob.Scheduled_On_Saturday__c = true;
        testJob.Scheduled_On_Sunday__c = true;
        testJob.Scheduled_Start_Time__c = DateTime.newInstance(2018, 1, 0, 0, 0, 0);
        testJob.Scheduled_End_Time__c = DateTime.newInstance(2018, 1, 0, 0, 0, 0);
        insert testJob;

        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));

        ScanScheduler scheduler = new ScanScheduler();

        Test.startTest();
            scheduler.execute(null);
        Test.stopTest();

        List<ALM_Job__c> actualJobs = [SELECT Status__c, Last_Queue_Time__c, Errors__c FROM ALM_Job__c WHERE Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING)];
        List<ALM_Application_Result__c> actualResults = [SELECT ALM_Job__c, Result__c FROM ALM_Application_Result__c WHERE ALM_Job__c = :testJob.Id];

        System.assertEquals(1, actualJobs.size(), 'One Automated Testing job should be retrieved.');
        System.assert(actualJobs[0].Last_Queue_Time__c != null, 'The last queue time should be set.');
        System.assertEquals(null, actualJobs[0].Errors__c, 'No errors should be encountered.');
    }

    static testMethod void testExecute_repoSyncJobs(){

        TestingUtils.VCRepoSyncSetup repoSyncSetup =  TestingUtils.setupSyncRepoJobs();

        MockVCAPI vcAPI = new MockVCAPI('unusedTestResponseBody');
        Test.setMock(HttpCalloutMock.class, vcAPI);

        ScanScheduler scanScheduler = new ScanScheduler();

        Test.startTest();
            scanScheduler.execute(null);
        Test.stopTest();

        List<ALM_Job__c> originalRepoSyncJobs = repoSyncSetup.getRepoSyncJobs();
        Map<Id, ALM_Job__c> idJobMap = new Map<Id, ALM_Job__C>(originalRepoSyncJobs);
        Set<Id> jobIds = idJobMap.keySet();

        List<ALM_Job__c> finalRepoSyncJobs = [
                SELECT Id, Status__c, Last_Queue_Time__c, Errors__c
                FROM ALM_Job__c
                WHERE Id in :jobIds AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.VC_REPO_SYNC)
        ];

        for(ALM_Job__c job : finalRepoSyncJobs) {
            System.assertEquals( true, job.Last_Queue_Time__c != null, 'the last queue time of the job should now have a value');
            System.assert(String.isEmpty(job.Errors__c));
            System.assertEquals(SCANServices.TOOL_STATUS_QUEUED, job.Status__c, 'the result status should show that the syncRepositories method was called');
        }

    }

    static testMethod void testExecute_repoSyncJobs_nonScheduled(){

        TestingUtils.VCRepoSyncSetup repoSyncSetup =  TestingUtils.setupSyncRepoJobs(false);

        MockVCAPI vcAPI = new MockVCAPI('unusedTestResponseBody');
        Test.setMock(HttpCalloutMock.class, vcAPI);

        ScanScheduler scanScheduler = new ScanScheduler();

        Test.startTest();
            scanScheduler.execute(null);
        Test.stopTest();

        List<ALM_Job__c> originalRepoSyncJobs = repoSyncSetup.getRepoSyncJobs();
        Map<Id, ALM_Job__c> idJobMap = new Map<Id, ALM_Job__C>(originalRepoSyncJobs);
        Set<Id> jobIds = idJobMap.keySet();

        List<ALM_Job__c> finalRepoSyncJobs = [
                SELECT Id, Status__c, Last_Queue_Time__c, Errors__c
                FROM ALM_Job__c
                WHERE Id in :jobIds AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.VC_REPO_SYNC)
        ];

        for(ALM_Job__c job : finalRepoSyncJobs) {
            System.assert(job.Last_Queue_Time__c == null, 'the last queue time of the job should not have a value');
            System.assert(String.isEmpty(job.Errors__c));
            System.assertEquals(null, job.Status__c, 'the job status should show that the syncRepositories method was ' +
                    'not called, meaning the job did not get picked up by the scheduler');
        }

    }


}