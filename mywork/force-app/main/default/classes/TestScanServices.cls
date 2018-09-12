@isTest
private class TestScanServices {

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
    * Even with seeAllData=false, CronJobDetail records in org data are visible in tests
    * This method checks and ensures that they are removed before a test
    */
    private static void deleteExistingScanJobs() {
        TestingUtils.deleteExistingJobs( new List<String>{SCANServices.SCHED_JOB_NAME_1, SCANServices.SCHED_JOB_NAME_2});
    }

    static testMethod void createSCANJobRequest() {
        ALM_Private__c settings = TestingUtils.createOAuthSettings();

        setup();

        ALM_Job__c scanJob = new ALM_Job__c();
        scanJob.Source_Instance__c = source.Id;
        scanJob.Target_Instance__c = target.Id;
        scanJob.Components__c = '*';
        scanJob.Excluded_Types__c = 'Document';

        insert scanJob;

         Map<Id, Auth_User__c> instanceToAuthUser = new Map<Id, Auth_User__c> {
            source.Id => sourceAuth,
            target.Id => targetAuth
        };

        ALM_Application_Result__c testResult =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);

        Test.startTest();

            SCANServices.SCANJobRequest request = ScanServices.createScanJobRequest(new Set<Id>{scanJob.Id}, instanceToAuthUser, new Map<Id, ALM_Application_Result__c>{scanJob.Id => testResult});

        Test.stopTest();

        System.assertEquals(UserInfo.getOrganizationId(), request.orgId, 'The orgID should be set on the request');
        System.assertEquals(1, request.jobs.size(), 'The jobs should be populated on the request');

        SCANServices.SCANJob job = request.jobs[0];

        System.assertEquals(scanJob.Id, job.jobId, 'The jobId should be populated on the request');
        System.assertEquals(scanJob.Source_Instance__c, job.sourceInstanceId, 'The source instance should be populated on the request');
        System.assertEquals(scanJob.Components__c, job.components, 'components should be populated on the request');
        System.assertEquals(sourceAuth.Refresh_Token__c, job.sourceRefreshToken, 'The source access token should be populated on the request from the Auth User for the source');
        System.assertEquals(sourceAuth.Instance_URL__c + ScanServices.SOAP_ENDPOINT, job.sourceEndpoint, 'The source instance url should be populated on the request from the Auth User for the source');

        System.assertEquals(targetAuth.Refresh_Token__c, job.targetRefreshToken, 'The target access token should be populated on the request from the Auth User for the target');
        System.assertEquals(targetAuth.Instance_URL__c + ScanServices.SOAP_ENDPOINT, job.targetEndpoint, 'The target instance url should be populated on the request from the Auth User for the target');

        System.assertEquals(null, job.maxPackageSize, 'The max package size should be set to null when it is not populated');
        System.assertEquals(false, job.syncDescriptions, 'The max package size should be set to null when it is not populated');
        System.assertEquals(false, job.includeProfiles, 'Include profiles should be set to false when it is not populated');
        System.assertEquals(false, job.includePermissionSets, 'Include permissionsets should be set to null when it is not populated');
        System.assertEquals(scanJob.Excluded_Types__c, job.excludedTypes, 'The excluded types property on the request should be populated from the scan job');

        System.assertEquals(job.clientId, settings.Consumer_Key__c, 'The clientId should be pouplated withe the cosumer key from the custom setting');
        System.assertEquals(job.clientSecret, settings.Consumer_Secret__c, 'The clientSecret should be populated with the cosumer secret from the custom setting');

        System.assertEquals(testResult.Id, job.currentApplicationResultId, 'The current application result ID should be populated.');
    }

    static testMethod void createScanJobRequest_excludeJobsWithInvalidAuthUsers() {
        TestingUtils.createOAuthSettings();

        setup();

        sourceAuth.Is_Refresh_Token_Valid__c = false;
        targetAuth.Is_Refresh_Token_Valid__c = true;

        Map<Id, Auth_User__c> instanceToAuthUser = new Map<Id, Auth_User__c> {
            source.Id => sourceAuth,
            target.Id => targetAuth
        };

        ALM_Job__c validJob = new ALM_Job__c();
        validJob.Source_Instance__c = target.Id;
        validJob.Target_Instance__c = target.Id;
        validJob.Components__c = '*';

        ALM_Job__c invalidJob = new ALM_Job__c();
        invalidJob.Source_Instance__c = source.Id;
        invalidJob.Target_Instance__c = target.Id;
        invalidJob.Components__c = '*';

        insert new List<ALM_Job__c> { invalidJob, validJob };

        ALM_Application_Result__c testResultForValidJob =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);
        testResultForValidJob.ALM_Job__c = validJob.Id;
        ALM_Application_Result__c testResultForInvalidJob =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);
        testResultForInvalidJob.ALM_Job__c = invalidJob.Id;
        update new List<ALM_Application_Result__c>{ testResultForValidJob, testResultForInvalidJob };

        Map<Id, ALM_Application_Result__c> actualResults = new Map<Id, ALM_Application_Result__c>([SELECT Id FROM ALM_Application_Result__c WHERE ALM_Job__c IN (:validJob.Id, :invalidJob.Id)]);
        System.assertEquals(2, actualResults.size(), 'Two application results should exist.');

        Test.startTest();

            SCANServices.SCANJobRequest request =
                ScanServices.createScanJobRequest(
                    new Set<Id>{invalidJob.Id, validJob.Id},
                    instanceToAuthUser,
                    new Map<Id, ALM_Application_Result__c>{
                        invalidJob.Id => actualResults.get(testResultForValidJob.Id),
                        validJob.Id => actualResults.get(testResultForValidJob.Id)
                    }
                );

        Test.stopTest();

        System.assertEquals(1, request.jobs.size(), 'Only active jobs should be included in the request.');
        System.assertEquals(validJob.Id, request.jobs[0].jobId, 'Only active jobs should be included in the request.');
        System.assertEquals(testResultForValidJob.Id, request.jobs[0].currentApplicationResultId, 'The current application result ID should be populated.');
    }

    static testMethod void reAuthorizeJobs_validAuth() {
        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();

        setup();

        ALM_Job__c scanJob = new ALM_Job__c();
        scanJob.Source_Instance__c = source.Id;
        scanJob.Target_Instance__c = target.Id;
        scanJob.Components__c = '*';

        insert scanJob;

        Test.startTest();

            ScanServices.reauthorizeJobs(new Set<Id>{scanJob.Id});

        Test.stopTest();

        Auth_User__c updatedSourceAuth = [ SELECT  Id, Access_Token__c FROM Auth_User__c WHERE Id = :sourceAuth.Id];
        Auth_User__c updatedTargetAuth = [ SELECT  Id, Access_Token__c FROM Auth_User__c WHERE Id = :targetAuth.Id];

        System.assertEquals(updatedSourceAuth.Access_Token__c, updatedSourceAuth.Access_Token__c, 'The source access token should remain unchanged when it is valid');
        System.assertEquals(targetAuth.Access_Token__c, updatedTargetAuth.Access_Token__c, 'The target access token should remain unchanged when it is valid');
    }

    static testMethod void ensureScanJobSchedulesExist_noJobsExist() {
        Test.setMock(HttpCalloutMock.class, new MockScanAPI(MockScanAPI.SUCCESS_SCAN_JOB_REQUEST));
        TestingUtils.createOAuthSettings();
        deleteExistingScanJobs();

        Test.startTest();
            SCANServices.ensureScanJobSchedulesExist();
        Test.stopTest();

        List<CronJobDetail> scheduledJobs = [
            SELECT Id
            FROM CronJobDetail
            WHERE Name IN (:SCANServices.SCHED_JOB_NAME_1, :SCANServices.SCHED_JOB_NAME_2)
        ];

        System.assertEquals(2, scheduledJobs.size(), 'There should be two scheduled jobs for SCAN');
    }

    static testMethod void ensureScanJobSchedulesExist_bothJobsExist_nothingCreated() {
        Test.setMock(HttpCalloutMock.class, new MockScanAPI(MockScanAPI.SUCCESS_SCAN_JOB_REQUEST));
        TestingUtils.createOAuthSettings();
        deleteExistingScanJobs();

        System.schedule(
            SCANServices.SCHED_JOB_NAME_1,
            SCANServices.SCHED_JOB_CRON_EXP_1,
            new ScanScheduler()
        );
        System.schedule(
            SCANServices.SCHED_JOB_NAME_2,
            SCANServices.SCHED_JOB_CRON_EXP_2,
            new ScanScheduler()
        );
        List<CronJobDetail> scheduledJobs = [
            SELECT Id
            FROM CronJobDetail
            WHERE Name IN (:SCANServices.SCHED_JOB_NAME_1, :SCANServices.SCHED_JOB_NAME_2)
        ];

        System.assertEquals(2, scheduledJobs.size(), 'There should be two scheduled jobs for SCAN');

        Test.startTest();
            SCANServices.ensureScanJobSchedulesExist();
        Test.stopTest();

        scheduledJobs = [
            SELECT Id
            FROM CronJobDetail
            WHERE Name IN (:SCANServices.SCHED_JOB_NAME_1, :SCANServices.SCHED_JOB_NAME_2)
        ];

        System.assertEquals(2, scheduledJobs.size(), 'Their should still only be 2 scheduled SCAN jobs');
    }

    static testMethod void ensureScanJobSchedulesExist_singleJobExists_singleJobCreated() {
        Test.setMock(HttpCalloutMock.class, new MockScanAPI(MockScanAPI.SUCCESS_SCAN_JOB_REQUEST));
        TestingUtils.createOAuthSettings();
        deleteExistingScanJobs();

        System.schedule(
            SCANServices.SCHED_JOB_NAME_1,
            SCANServices.SCHED_JOB_CRON_EXP_1,
            new ScanScheduler()
        );
        List<CronJobDetail> scheduledJobs = [
            SELECT Id
            FROM CronJobDetail
            WHERE Name IN (:SCANServices.SCHED_JOB_NAME_1, :SCANServices.SCHED_JOB_NAME_2)
        ];

        System.assertEquals(1, scheduledJobs.size(), 'There should be one scheduled job for SCAN');

        Test.startTest();
            SCANServices.ensureScanJobSchedulesExist();
        Test.stopTest();

        scheduledJobs = [
            SELECT Id
            FROM CronJobDetail
            WHERE Name IN (:SCANServices.SCHED_JOB_NAME_1, :SCANServices.SCHED_JOB_NAME_2)
        ];

        System.assertEquals(2, scheduledJobs.size(), 'Both scheduled jobs should now be created');
    }

    static testMethod void getScanJobForInstance_validInstance_returnsScanJob() {
        setup();

        ALM_Job__c job = TestingUtils.buildScanJob(source.Id, source.Id, 'Scheduled');
        insert job;

        Test.startTest();
            ALM_Job__c retrievedJob = SCANServices.getScanJobForInstance(source.Id);
        Test.stopTest();

        System.assertEquals(job.Id, retrievedJob.Id, 'Should retrieve the original SCAN job for this instance');

    }

    static testMethod void getScanJobForInstance_invalidInstance_throwsException() {
        Test.startTest();
            try {
                SCANServices.getScanJobForInstance(null);
                System.assert(false, 'An exception should be thrown for bad input.');
            } catch(Exception e) {
                System.assert(e instanceof ALMException, 'An exception of type ALMException was expected.');
            }
        Test.stopTest();
    }

    static testMethod void getScanJobForInstance_noScanJobs_returnsNull() {
        setup();

        Test.startTest();
            ALM_Job__c scanJob = SCANServices.getScanJobForInstance(source.Id);
        Test.stopTest();
        System.assertEquals(null, scanJob, 'null should be returned when there are no matching scan jobs');
    }

    static testMethod void sendScanJobRequest_AuthorizedAndUnAuthorizedScanJobs() {
        AuthorizationSetup authSetup = new AuthorizationSetup();

        authSetup.testMultiMock.addRequestMock(authSetup.sightlineUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        authSetup.testMultiMock.addRequestMock(authSetup.sourceUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        authSetup.testMultiMock.addRequestMock(authSetup.targetUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST));

        ALM_Job__c validJob = new ALM_Job__c();
        validJob.Source_Instance__c = source.Id;
        validJob.Target_Instance__c = target.Id;
        validJob.Components__c = '*';

        ALM_Job__c invalidJob = new ALM_Job__c();
        invalidJob.Source_Instance__c = target.Id;
        invalidJob.Target_Instance__c = target.Id;
        invalidJob.Components__c = '*';

        insert new List<ALM_Job__c> { invalidJob, validJob };

        ALM_Application_Result__c testResultForValidJob =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);
        testResultForValidJob.ALM_Job__c = validJob.Id;
        ALM_Application_Result__c testResultForInvalidJob =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);
        testResultForInvalidJob.ALM_Job__c = invalidJob.Id;

        update new List<ALM_Application_Result__c>{ testResultForValidJob, testResultForInvalidJob };

        Test.setMock(HttpCalloutMock.class, authSetup.testMultiMock);
        Test.startTest();
            try{
                ScanServices.sendScanJobRequest(new Set<Id> {validJob.Id, invalidJob.Id});
            }catch(Exception ex){
                System.assert(false, 'No exceptions should be thrown : ' + ex.getMessage());
            }
        Test.stopTest();

        Map<Id, ALM_Application_Result__c> actualApplicationResultsMap = new Map<Id, ALM_Application_Result__c>(
            [SELECT Id, Error_Message__c, Result__c, ALM_Job__r.Last_Failure__c
            FROM ALM_Application_Result__c]
        );
        System.assertEquals(SCANServices.FAILURE_STATUS, actualApplicationResultsMap.get(testResultForInvalidJob.Id).Result__c, 'The unauthorized job result should be failed');
        System.assertEquals(SCANServices.TOOL_STATUS_QUEUED, actualApplicationResultsMap.get(testResultForValidJob.Id).Result__c, 'The authorized job result should be successful');
        System.assertNotEquals(null, actualApplicationResultsMap.get(testResultForInvalidJob.Id).ALM_Job__r.Last_Failure__c, 'The unauthorized job should be failed');
        System.assertEquals(System.Label.Instance_Auth_Invalid,
                            actualApplicationResultsMap.get(testResultForInvalidJob.Id).Error_Message__c,
                            'The unauthorized job should be failed with the correct error message');
        System.assertEquals(null, actualApplicationResultsMap.get(testResultForValidJob.Id).ALM_Job__r.Last_Failure__c, 'The authorized job should not be failed');
    }

    static testMethod void sendScanJobRequest_AuthorizedScanJobs_unAuthorizedSightlineUser() {
        AuthorizationSetup authSetup = new AuthorizationSetup();

        authSetup.testMultiMock.addRequestMock(authSetup.sightlineUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST));
        authSetup.testMultiMock.addRequestMock(authSetup.sourceUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        authSetup.testMultiMock.addRequestMock(authSetup.targetUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));

        ALM_Job__c validJob = new ALM_Job__c();
        validJob.Source_Instance__c = target.Id;
        validJob.Target_Instance__c = target.Id;
        validJob.Components__c = '*';

        ALM_Job__c validJob2 = new ALM_Job__c();
        validJob2.Source_Instance__c = source.Id;
        validJob2.Target_Instance__c = target.Id;
        validJob2.Components__c = '*';

        insert new List<ALM_Job__c> { validJob, validJob2 };

        ALM_Application_Result__c testResultForValidJob =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);
        testResultForValidJob.ALM_Job__c = validJob.Id;
        ALM_Application_Result__c testResultForValidJob2 =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);
        testResultForValidJob2.ALM_Job__c = validJob2.Id;

        update new List<ALM_Application_Result__c>{ testResultForValidJob, testResultForValidJob2 };

        Test.setMock(HttpCalloutMock.class, authSetup.testMultiMock);
        Test.startTest();
            try{
                ScanServices.sendScanJobRequest(new Set<Id> {validJob.Id, validJob2.Id});
            }catch(Exception ex){
                System.assert(false, 'No exceptions should be thrown : ' + ex.getMessage());
            }
        Test.stopTest();

        Map<Id, ALM_Application_Result__c> actualApplicationResultsMap = new Map<Id, ALM_Application_Result__c>(
            [SELECT Id, Error_Message__c, Result__c, ALM_Job__r.Last_Failure__c
            FROM ALM_Application_Result__c]
        );
        System.assertEquals(SCANServices.FAILURE_STATUS, actualApplicationResultsMap.get(testResultForValidJob.Id).Result__c, 'The authorized job result should be failed');
        System.assertEquals(SCANServices.FAILURE_STATUS, actualApplicationResultsMap.get(testResultForValidJob2.Id).Result__c, 'The second authorized job result should be failed');
        System.assertNotEquals(null, actualApplicationResultsMap.get(testResultForValidJob.Id).ALM_Job__r.Last_Failure__c, 'The authorized job should be failed');
        System.assertNotEquals(null, actualApplicationResultsMap.get(testResultForValidJob2.Id).ALM_Job__r.Last_Failure__c, 'The second authorized job should be failed');
        System.assertEquals(System.Label.Sightline_Instance_Not_Authorized,
                            actualApplicationResultsMap.get(testResultForValidJob.Id).Error_Message__c,
                            'The unauthorized job should be failed with the correct error message');
        System.assertEquals(System.Label.Sightline_Instance_Not_Authorized,
                            actualApplicationResultsMap.get(testResultForValidJob2.Id).Error_Message__c,
                            'The second unauthorized job should be failed with the correct error message');
    }

    static testMethod void sendScanJobRequest_AuthorizedScanJobs_missingSightlineUser() {
        AuthorizationSetup authSetup = new AuthorizationSetup();
        //unset the sightline instance
        Instances__c sightlineInstance = [
                                            SELECT Id
                                            FROM Instances__c
                                            WHERE Is_ALM_Instance__c = true
                                            LIMIT 1
                                         ];
        sightlineInstance.Is_ALM_Instance__c = false;
        update sightlineInstance;

        authSetup.testMultiMock.addRequestMock(authSetup.sightlineUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        authSetup.testMultiMock.addRequestMock(authSetup.sourceUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        authSetup.testMultiMock.addRequestMock(authSetup.targetUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));

        ALM_Job__c validJob = new ALM_Job__c();
        validJob.Source_Instance__c = target.Id;
        validJob.Target_Instance__c = target.Id;
        validJob.Components__c = '*';

        ALM_Job__c validJob2 = new ALM_Job__c();
        validJob2.Source_Instance__c = source.Id;
        validJob2.Target_Instance__c = target.Id;
        validJob2.Components__c = '*';

        insert new List<ALM_Job__c> { validJob, validJob2 };

        ALM_Application_Result__c testResultForValidJob =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);
        testResultForValidJob.ALM_Job__c = validJob.Id;
        ALM_Application_Result__c testResultForValidJob2 =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);
        testResultForValidJob2.ALM_Job__c = validJob2.Id;

        update new List<ALM_Application_Result__c>{ testResultForValidJob, testResultForValidJob2 };

        Test.setMock(HttpCalloutMock.class, authSetup.testMultiMock);
        Test.startTest();
            try{
                ScanServices.sendScanJobRequest(new Set<Id> {validJob.Id, validJob2.Id});
            }catch(Exception ex){
                System.assert(false, 'No exceptions should be thrown : ' + ex.getMessage());
            }
        Test.stopTest();

        Map<Id, ALM_Application_Result__c> actualApplicationResultsMap = new Map<Id, ALM_Application_Result__c>(
            [SELECT Id, Error_Message__c, Result__c, ALM_Job__r.Last_Failure__c
            FROM ALM_Application_Result__c]
        );
        System.assertEquals(SCANServices.FAILURE_STATUS, actualApplicationResultsMap.get(testResultForValidJob.Id).Result__c, 'The authorized job result should be failed');
        System.assertEquals(SCANServices.FAILURE_STATUS, actualApplicationResultsMap.get(testResultForValidJob2.Id).Result__c, 'The second authorized job result should be failed');
        System.assertNotEquals(null, actualApplicationResultsMap.get(testResultForValidJob.Id).ALM_Job__r.Last_Failure__c, 'The authorized job should be failed');
        System.assertNotEquals(null, actualApplicationResultsMap.get(testResultForValidJob2.Id).ALM_Job__r.Last_Failure__c, 'The second authorized job should be failed');
        System.assertEquals(System.Label.Sightline_Instance_Not_Authorized,
                            actualApplicationResultsMap.get(testResultForValidJob.Id).Error_Message__c,
                            'The unauthorized job should be failed with the correct error message');
        System.assertEquals(System.Label.Sightline_Instance_Not_Authorized,
                            actualApplicationResultsMap.get(testResultForValidJob2.Id).Error_Message__c,
                            'The second unauthorized job should be failed with the correct error message');
    }

    static testMethod void sendScanJobRequest_AuthorizedScanJobs_cannotConnectToSightlineServer() {
        AuthorizationSetup authSetup = new AuthorizationSetup();
        authSetup.testMultiMock.addRequestMock(ScanServices.SCAN_JOB_ENDPOINT, new MockScanAPI(MockScanAPI.UNAUTHORIZED_ENDPOINT_SCAN_JOB_REQUEST));

        authSetup.testMultiMock.addRequestMock(authSetup.sightlineUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        authSetup.testMultiMock.addRequestMock(authSetup.sourceUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        authSetup.testMultiMock.addRequestMock(authSetup.targetUserAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));

        ALM_Job__c validJob = new ALM_Job__c();
        validJob.Source_Instance__c = target.Id;
        validJob.Target_Instance__c = target.Id;
        validJob.Components__c = '*';

        ALM_Job__c validJob2 = new ALM_Job__c();
        validJob2.Source_Instance__c = source.Id;
        validJob2.Target_Instance__c = target.Id;
        validJob2.Components__c = '*';

        insert new List<ALM_Job__c> { validJob, validJob2 };

        ALM_Application_Result__c testResultForValidJob =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);
        testResultForValidJob.ALM_Job__c = validJob.Id;
        ALM_Application_Result__c testResultForValidJob2 =
            TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now().addMinutes(1), SCANServices.TOOL_STATUS_QUEUED, 'Test Status', source.Id, ALMJobServices.ToolType.SCAN);
        testResultForValidJob2.ALM_Job__c = validJob2.Id;

        update new List<ALM_Application_Result__c>{ testResultForValidJob, testResultForValidJob2 };

        Test.setMock(HttpCalloutMock.class, authSetup.testMultiMock);
        Test.startTest();
            try{
                ScanServices.sendScanJobRequest(new Set<Id> {validJob.Id, validJob2.Id});
            }catch(Exception ex){
                System.assert(false, 'No exceptions should be thrown : ' + ex.getMessage());
            }
        Test.stopTest();

        Map<Id, ALM_Application_Result__c> actualApplicationResultsMap = new Map<Id, ALM_Application_Result__c>(
            [SELECT Id, Error_Message__c, Result__c, ALM_Job__r.Last_Failure__c
            FROM ALM_Application_Result__c]
        );
        System.assertEquals(SCANServices.FAILURE_STATUS, actualApplicationResultsMap.get(testResultForValidJob.Id).Result__c, 'The authorized job result should be failed');
        System.assertEquals(SCANServices.FAILURE_STATUS, actualApplicationResultsMap.get(testResultForValidJob2.Id).Result__c, 'The second authorized job result should be failed');
        System.assertNotEquals(null, actualApplicationResultsMap.get(testResultForValidJob.Id).ALM_Job__r.Last_Failure__c, 'The authorized job should be failed');
        System.assertNotEquals(null, actualApplicationResultsMap.get(testResultForValidJob2.Id).ALM_Job__r.Last_Failure__c, 'The second authorized job should be failed');
        System.assertEquals(System.Label.Unable_To_Connect_To_Sightline_Server_Error,
                            actualApplicationResultsMap.get(testResultForValidJob.Id).Error_Message__c,
                            'The unauthorized job should be failed with the correct error message');
        System.assertEquals(System.Label.Unable_To_Connect_To_Sightline_Server_Error,
                            actualApplicationResultsMap.get(testResultForValidJob2.Id).Error_Message__c,
                            'The second unauthorized job should be failed with the correct error message');
    }
    private class AuthorizationSetup {
        public ALM_Private__c settings = TestingUtils.createOAuthSettings();
        public Auth_User__c sightlineAuthUser = TestingUtils.setupSightlineAuth();
        private final String LOGIN_ENDPOINT = 'https://login.salesforce.com';
        private String generalAuthEndpoint = LOGIN_ENDPOINT + OAuthRequest.OAUTH_TOKEN_URL;
        private String retryAuthEndpoint = LOGIN_ENDPOINT + OAuthRequest.OAUTH_USERINFO_URL + MockOAuthApi.SUCCESS_ACCESS_TOKEN;
        public String sightlineUserAuthEndpoint;
        public String sourceUserAuthEndpoint;
        public String targetUserAuthEndpoint;
        public MockOAuthAPI testMultiMock;

        public AuthorizationSetup(){
            setup();
            sightlineAuthUser.Access_Token__c = 'abcabc';
            sourceAuth.Access_Token__c = '123123';
            update new List<Auth_User__c>{sourceAuth, sightlineAuthUser};

            sightlineUserAuthEndpoint = LOGIN_ENDPOINT + OAuthRequest.OAUTH_USERINFO_URL + sightlineAuthUser.Access_Token__c;
            sourceUserAuthEndpoint = LOGIN_ENDPOINT + OAuthRequest.OAUTH_USERINFO_URL + sourceAuth.Access_Token__c;
            targetUserAuthEndpoint = LOGIN_ENDPOINT + OAuthRequest.OAUTH_USERINFO_URL + targetAuth.Access_Token__c;

            testMultiMock = new MockOAuthAPI(
            new Map<String, HttpCalloutMock> {generalAuthEndpoint
            => new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST)});
            testMultiMock.addRequestMock(retryAuthEndpoint, new MockOAuthAPI(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST));
            testMultiMock.addRequestMock(ScanServices.SCAN_JOB_ENDPOINT, new MockScanAPI(MockScanAPI.SUCCESS_SCAN_JOB_REQUEST));
        }
    }


}