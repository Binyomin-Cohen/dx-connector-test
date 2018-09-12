@isTest
private class TestAdminInstanceManagementController {
    private static Instances__c instanceProd;
    private static Instances__c instanceSandbox;

    private static Component__c componentWithProdEnvData;
    private static Component__c componentWithSbxEnvData;

    static void setup() {
        instanceProd = new Instances__c(Name='prod', Type__c='Production / Developer');
        instanceSandbox = new Instances__c(Name='sbx', Type__c='Sandbox');

        insert new List<Instances__c>{instanceProd, instanceSandbox};
    }

    static void setupDataWithComponents() {
        setup();

        FieldModifiedData prodEnvData1 = new FieldModifiedData( instanceProd.Name,  Datetime.now().addDays(-1), null, null, null);
        FieldModifiedData sbxEnvData2 = new FieldModifiedData( instanceSandbox.Name,  Datetime.now(), null, null, null);

        componentWithProdEnvData = TestingUtils.buildComponent('Test object 1', 'Object', instanceProd.Id);
        componentWithSbxEnvData = TestingUtils.buildComponent('Test object 2', 'Object', instanceSandbox.Id);

        componentWithProdEnvData.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ prodEnvData1 } );
        componentWithSbxEnvData.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ sbxEnvData2 } );

        insert new List<Component__c> { componentWithProdEnvData, componentWithSbxEnvData};

        Release__c release = new Release__c(Name='test release');

        Build__c build = TestingUtils.createBuild(release.Id, 'Ready');

        Build_Component__c buildComponent = TestingUtils.createUndocumentedBuildComponent(componentWithProdEnvData, build.Id, instanceProd.Name);

    }

    static void setupAuthUser(Id instanceId) {
        TestingUtils.createAuthUser(TestingUtils.ADMIN_USER.Id, instanceId, true);
    }

    static AdminInstanceManagementController setupAdminInstanceManagementController (Instances__c instance) {
        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instance.Id;
        controller.loadInstance();

        return controller;
    }

    static testMethod void controllerConstructor_namespace() {
        setup();
        String test_namespace = 'testNamespace';
        SObjectServices.CURRENT_NAMESPACE = test_namespace;

        Test.startTest();
           AdminInstanceManagementController testController = setupAdminInstanceManagementController(instanceProd);
        Test.stopTest();

        System.assert(String.isNotEmpty(testController.namespace), 'The namespace should be populated');
        System.assert(testController.namespace.startsWith(test_namespace), 'The namespace should be populated correctly');
    }

    static testMethod void controllerConstructor_no_namespace() {
        setup();
        String test_namespace = '';
        SObjectServices.CURRENT_NAMESPACE = test_namespace;

        Test.startTest();
           AdminInstanceManagementController testController = setupAdminInstanceManagementController(instanceProd);
        Test.stopTest();

        System.assert(String.isEmpty(testController.namespace), 'The namespace should not be populated');
    }

    static testMethod void authorizeInstance_Non_Sandbox() {
        setup();

        TestingUtils.createOAuthSettings();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();

        Test.startTest();
            controller.selectedInstanceId = instanceProd.Id;
            PageReference authReference = controller.authorizeInstance();

        Test.stopTest();

        Map<String, String> params = authReference.getParameters();

        System.assertEquals(true, authReference.getUrl().startsWith('https://login.salesforce.com' + OAuthRequest.OAUTH_CODE_END_POINT_URL), 'The oauth endpoint should be set properly');
        System.assertEquals(true, params.containsKey('state'), 'A state parameter should be included');
        System.assertEquals(true, params.containsKey('grant_type'), 'A grant_type parameter should be included');
        System.assertEquals(OAuthRequest.AUTH_GRANT_TYPE_CODE, params.get('grant_type'), 'The grant_type parameter should be set to the authorization code value');

        Map<String, Object> state = (Map<String, Object>)JSON.deserializeUntyped(params.get('state'));
        System.assertEquals(true, state.containsKey('origin_url'), 'An origin_url should be included in the state parameter');
        System.assertEquals(true, state.containsKey(OAuthController.INSTANCE_STATE_PARAM), 'An instanceId should be included in the state parameter');

        String instanceId = (String)state.get(OAuthController.INSTANCE_STATE_PARAM);
        System.assertEquals(instanceProd.Id, instanceId, 'The instance Id should be set to the selected instance.');
    }

    static testMethod void authorizeInstance_Sandbox() {
        setup();

        TestingUtils.createOAuthSettings();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();

        Test.startTest();
            controller.selectedInstanceId = instanceSandbox.Id;
            PageReference authReference = controller.authorizeInstance();

        Test.stopTest();

        Map<String, String> params = authReference.getParameters();

        System.assertEquals(true, authReference.getUrl().startsWith('https://test.salesforce.com' + OAuthRequest.OAUTH_CODE_END_POINT_URL), 'The oauth endpoint should be set properly');
        System.assertEquals(true, params.containsKey('state'), 'A state parameter should be included');
        System.assertEquals(true, params.containsKey('grant_type'), 'A grant_type parameter should be included');
        System.assertEquals(OAuthRequest.AUTH_GRANT_TYPE_CODE, params.get('grant_type'), 'The grant_type parameter should be set to the authorization code value');

        Map<String, Object> state = (Map<String, Object>)JSON.deserializeUntyped(params.get('state'));
        System.assertEquals(true, state.containsKey('origin_url'), 'An origin_url should be included in the state parameter');
        System.assertEquals(true, state.containsKey(OAuthController.INSTANCE_STATE_PARAM), 'An instanceId should be included in the state parameter');

        String instanceId = (String)state.get(OAuthController.INSTANCE_STATE_PARAM);
        System.assertEquals(instanceSandbox.Id, instanceId, 'The instance Id should be set to the selected instance.');
    }

    static testMethod void handleOAuthRedirect_success() {
        setup();

        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();

        Map<String,String> state = new Map<String, String>{
            OAuthController.INSTANCE_STATE_PARAM => instanceProd.Id,
            OAuthController.CSRF_STATE_PARAM => OAuthServices.generateCSRFToken()
        };

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        Test.startTest();
            PageReference ref = Page.AdminInstanceManagement;
            ref.getParameters().put('code', 'somecode');
            ref.getParameters().put('state', JSON.serialize(state));
            Test.setCurrentPage(ref);

            controller.handleOAuthRedirect();

        Test.stopTest();

        List<Auth_User__c> auths = [SELECT Id, Instance__c, User__c, Is_For_Tools__c FROM Auth_User__c];

        System.assertEquals(1, auths.size(), 'when the access token request succeeds, an auth records should be created');
        System.assertEquals(instanceProd.Id, auths[0].Instance__c, 'The instance Id should be set on the auth record');
        System.assertEquals(UserInfo.getUserId(), auths[0].User__c, 'The User Id should be set on the auth record');
        System.assert(auths[0].Is_For_Tools__c, 'The Is_For_Tools__c field should be true on the auth record');
    }

    static testMethod void handleOAuthRedirect_failure_noAuthCreated() {
        setup();

        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        Test.startTest();
            PageReference ref = Page.AdminInstanceManagement;
            ref.getParameters().put('code', 'someinvalidcode');
            ref.getParameters().put('state', '{ \"instance_id\": \"' +instanceProd.Id+ '\" }');
            Test.setCurrentPage(ref);

            controller.handleOAuthRedirect();

        Test.stopTest();

        List<Auth_User__c> auths = [SELECT Id FROM Auth_User__c];

        System.assertEquals(0, auths.size(), 'when the access token request fails, no auth records should be created');
    }

    static testMethod void getJobStatus_validInstance_returnsStatus() {
        setup();

        ALM_Job__c scanJob = TestingUtils.buildScanJob(instanceSandbox.Id, instanceSandbox.Id, ScanServices.TOOL_STATUS_SCHEDULED);
        ALM_Job__c butrJob = TestingUtils.buildButrJob(instanceSandbox.Id, ScanServices.TOOL_STATUS_SCHEDULED);
        List<ALM_Job__c> jobs = new List<ALM_Job__c> { scanJob, butrJob};
        insert jobs;

        Test.startTest();
            String scanStatus = AdminInstanceManagementController.getJobStatus(instanceSandbox.Id, 'scan');
            String butrStatus = AdminInstanceManagementController.getJobStatus(instanceSandbox.Id, 'butr');
        Test.stopTest();

        System.assertEquals(ScanServices.TOOL_STATUS_SCHEDULED, scanStatus, 'The returned status for the scan job should be "Scheduled"');
        System.assertEquals(ScanServices.TOOL_STATUS_SCHEDULED, butrStatus, 'The returned status for the butr job should be "Scheduled"');
    }

    static testMethod void getJobStatus_invalidInstance_throwsException() {
        Test.startTest();
            try {
                String status = AdminInstanceManagementController.getJobStatus(null, 'scan');
                System.assert(false, 'An exception should be thrown for bad input.');
            } catch(ALMException e) {
                System.assert(true, 'An ALMException should be thrown for bad input.');
            } catch(Exception e) {
                System.assert(false, 'An exception of type ALMException was expected.');
            }
        Test.stopTest();
    }

    static testMethod void createOnDemandScanRequest_validParams_pendingJob() {
        setup();
        instanceProd.Is_ALM_Instance__c = true;
        update instanceProd;

        setupAuthUser(instanceSandbox.Id);
        setupAuthUser(instanceProd.Id);

        TestingUtils.createOAuthSettings();
        Test.setMock(HttpCalloutMock.class, new MockScanAPI(MockScanAPI.SUCCESS_SCAN_JOB_REQUEST));

        ALM_Job__c job = TestingUtils.buildScanJob(instanceSandbox.Id, instanceProd.Id, ScanServices.TOOL_STATUS_SCHEDULED);
        insert job;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceSandbox.Id;
        controller.loadInstance();

        System.assertEquals(0, [SELECT Count() FROM ALM_Application_Result__c WHERE Instance__c = :instanceSandbox.Id], 'No application results should exist.');

        Test.startTest();
            controller.createOnDemandScanRequest();
        Test.stopTest();

        System.assertEquals(1, [SELECT Count() FROM ALM_Application_Result__c WHERE Instance__c = :instanceSandbox.Id], 'One application result should exist.');

        System.assert(controller.pageMessages.isEmpty(), 'This should be a valid request with no page messages');
        System.assertEquals(
            SCANServices.TOOL_STATUS_QUEUED,
            [select Status__c from ALM_Job__c where Id = :job.Id limit 1].Status__c,
            'The status should be changed to Pending when on demand SCAN is run'
        );
    }

    static testMethod void createOnDemandButrRequest_validParams_pendingJob() {
        setup();
        instanceProd.Is_ALM_Instance__c = true;
        update instanceProd;

        setupAuthUser(instanceSandbox.Id);
        setupAuthUser(instanceProd.Id);

        TestingUtils.createOAuthSettings();
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.RunTestsAsynchronous, ALMRestServices.HTTP_OK));

        ALM_Job__c job = TestingUtils.buildButrJob(instanceSandbox.Id, ScanServices.TOOL_STATUS_SCHEDULED);
        insert job;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceSandbox.Id;
        controller.loadInstance();

        Test.startTest();
            controller.createOnDemandButrRequest();
        Test.stopTest();

        System.assert(controller.pageMessages.isEmpty(), 'This should be a valid request with no page messages');
        System.assertEquals(
            SCANServices.TOOL_STATUS_QUEUED,
            controller.currentInstance.butrJob.Status__c,
            'The status should be changed to Pending when on demand BUTR is run'
        );
    }

    static testMethod void calloutTest_remoteSiteSetting_missing() {
        setup();
        instanceProd.Is_ALM_Instance__c = true;
        update instanceProd;

        setupAuthUser(instanceProd.Id);
        Boolean remoteSiteSettingsTest = true;
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(remoteSiteSettingsTest));

        Test.startTest();
            String result = AdminInstanceManagementController.calloutTest(instanceProd.Id);
        Test.stopTest();

        System.assert(String.isNotBlank(result), 'Without a remote site setting, we should receive a warning message.');
        System.assert(result.contains(TestingUtils.INSTANCE_URL), 'The warning message should contain the instance url');
    }

    static testMethod void calloutTest_remoteSiteSetting_present() {
        setup();
        instanceProd.Is_ALM_Instance__c = true;
        update instanceProd;

        setupAuthUser(instanceProd.Id);

        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.RunTestsAsynchronous, ALMRestServices.HTTP_OK));

        Test.startTest();
            String result = AdminInstanceManagementController.calloutTest(instanceProd.Id);
        Test.stopTest();

        System.assert(String.isBlank(result), 'With a remote site setting, we should receive a true response.');
    }

    static testMethod void calloutTest_remoteSiteSetting_noAuthUser() {
        setup();
        instanceProd.Is_ALM_Instance__c = true;
        update instanceProd;

        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.RunTestsAsynchronous, ALMRestServices.HTTP_OK));

        Test.startTest();
            String result = AdminInstanceManagementController.calloutTest(instanceProd.Id);
        Test.stopTest();

        System.assert(String.isNotBlank(result), 'Without a remote site setting, we should receive a warning message.');
        System.assertEquals(AdminInstanceManagementController.NO_AUTH_USER_URL_ERROR, result, 'The warning message should indicate there is no authorized user');
    }

    static testMethod void createOnDemandScanRequest_invalidLogin_addError() {
        TestingUtils.createOAuthSettings();
        Test.setMock(HttpCalloutMock.class, new MockScanAPI(MockScanAPI.SUCCESS_SCAN_JOB_REQUEST));
        setup();

        instanceProd.Is_ALM_Instance__c = true;
        update instanceProd;
        setupAuthUser(instanceProd.Id);

        Auth_User__c authUser = TestingUtils.buildAuthUser(UserInfo.getUserId(), instanceSandbox.Id, true);
        authUser.Is_Refresh_Token_Valid__c = false;
        insert authUser;

        ALM_Job__c job = TestingUtils.buildScanJob(instanceSandbox.Id, instanceProd.Id, ScanServices.TOOL_STATUS_SCHEDULED);
        insert job;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();

        controller.selectedInstanceId = instanceSandbox.Id;
        controller.loadInstance();

        System.assertEquals(0, [SELECT Count() FROM ALM_Application_Result__c WHERE Instance__c = :instanceSandbox.Id], 'No application results should exist.');

        Test.startTest();
            controller.createOnDemandScanRequest();
        Test.stopTest();

        System.assertEquals(0, [SELECT Count() FROM ALM_Application_Result__c WHERE Instance__c = :instanceSandbox.Id], 'No application results should exist.');

        System.assertEquals(1, controller.pageMessages.size(), 'An error should be shown when the current scan job has an invalid login');
        System.assertEquals(ApexPages.Severity.ERROR.name().toLowerCase(), controller.pageMessages[0].messageType, 'An error should be shown when the current scan job has an invalid login');

        System.assertEquals(
            SCANServices.TOOL_STATUS_SCHEDULED,
            [select Status__c from ALM_Job__c where Id = :job.Id].Status__c,
            'The status should be unchanged when there is a login error'
        );
    }

    static testMethod void createOnDemandButrRequest_invalidLogin_addError() {
        TestingUtils.createOAuthSettings();
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.RunTestsAsynchronous, ALMRestServices.HTTP_OK));
        setup();

        instanceProd.Is_ALM_Instance__c = true;
        update instanceProd;
        setupAuthUser(instanceProd.Id);

        Auth_User__c authUser = TestingUtils.buildAuthUser(UserInfo.getUserId(), instanceSandbox.Id, true);
        authUser.Is_Refresh_Token_Valid__c = false;
        insert authUser;

        ALM_Job__c job = TestingUtils.buildButrJob(instanceSandbox.Id, ScanServices.TOOL_STATUS_SCHEDULED);
        insert job;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();

        controller.selectedInstanceId = instanceSandbox.Id;
        controller.loadInstance();

        Test.startTest();
            controller.createOnDemandButrRequest();
        Test.stopTest();

        System.assertEquals(1, controller.pageMessages.size(), 'An error should be shown when the current butr job has an invalid login');
        System.assertEquals(ApexPages.Severity.ERROR.name().toLowerCase(), controller.pageMessages[0].messageType, 'An error should be shown when the current butr job has an invalid login');

        System.assertEquals(
            SCANServices.TOOL_STATUS_SCHEDULED,
            controller.currentInstance.butrJob.Status__c,
            'The status should be unchanged when there is a login error'
        );
    }

    static testMethod void createOnDemandScanRequest_noTargetPopulated() {
        TestingUtils.createOAuthSettings();
        Test.setMock(HttpCalloutMock.class, new MockScanAPI(MockScanAPI.SUCCESS_SCAN_JOB_REQUEST));
        setup();

        instanceProd.Is_ALM_Instance__c = true;
        update instanceProd;
        setupAuthUser(instanceProd.Id);
        setupAuthUser(instanceSandbox.Id);

        ALM_Job__c job = TestingUtils.buildScanJob(instanceSandbox.Id, null, ScanServices.TOOL_STATUS_SCHEDULED);
        insert job;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();

        controller.selectedInstanceId = instanceSandbox.Id;
        controller.loadInstance();

        System.assertEquals(0, [SELECT Count() FROM ALM_Application_Result__c WHERE Instance__c = :instanceSandbox.Id], 'No application results should exist.');

        Test.startTest();
            controller.createOnDemandScanRequest();
        Test.stopTest();

        System.assertEquals(1, [SELECT Count() FROM ALM_Application_Result__c WHERE Instance__c = :instanceSandbox.Id], 'One application result should exist.');

        System.assert(controller.pageMessages.isEmpty(), 'This should be a valid request with no page messages');

        job = [SELECT Target_Instance__c, Status__c FROM ALM_Job__c WHERE Id = :job.Id];

        System.assertEquals(
            SCANServices.TOOL_STATUS_QUEUED,
            job.Status__c,
            'The status should be changed to Pending when on demand SCAN is run'
        );

        System.assertEquals(instanceProd.Id, job.Target_Instance__c,
            'The scan job should be updated with the alm instance when running on demand when it is not set'
        );
    }

    static testMethod void addNewInstance_valid() {
        String instanceName = 'TestInstance';
        String instanceType = 'Production / Developer';

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.newInstance.record.Name = instanceName;
        controller.newInstance.record.Type__c = instanceType;

        Test.startTest();
            try {
                controller.addNewInstance();
            } catch(ALMException e) {
                System.assert(false, 'No exception should be thrown.');
            }
        Test.stopTest();

        System.assertEquals(1, ([SELECT Name FROM Instances__c LIMIT 2]).size(), 'There should be one instance after adding a valid new instance.');
        System.assertEquals(null, controller.currentInstance, 'The current instance should be set to null after a new instance is successfully added.');
    }

    static testMethod void addNewInstance_deletedExists() {
        String instanceName = 'TestInstance';
        String instanceType = 'Production / Developer';

        Instances__c testExistingInstance = TestingUtils.buildInstance(instanceName);
        testExistingInstance.Is_Deleted__c = true;
        insert testExistingInstance;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.newInstance.record.Name = instanceName;
        controller.newInstance.record.Type__c = instanceType;
        controller.currentInstance = controller.newInstance;
        Boolean existingDeletedInstanceFlag = false;

        Test.startTest();
            try {
                controller.addNewInstance();
                existingDeletedInstanceFlag = controller.isInstanceDeleted;
            } catch(ALMException e) {
                System.assert(false, 'No exception should be thrown.');
            }
        Test.stopTest();
        List<Instances__c> actualInstances = [SELECT Id, Is_Deleted__c FROM Instances__c];
        System.assertEquals(true, existingDeletedInstanceFlag, 'A deleted existing instance should be detected');
        System.assertEquals(1, actualInstances.size(), 'There should be one instance.');
        System.assertEquals(testExistingInstance.Id, actualInstances[0].Id, 'There correct instance should exist.');
        System.assertEquals(true, actualInstances[0].Is_Deleted__c, 'There instance should still be marked as deleted');
        System.assertNotEquals(null, controller.currentInstance, 'The current instance should not be set to null');
    }

    static testMethod void undeleteInstance() {
        String instanceName = 'TestInstance';
        String instanceType = 'Production / Developer';

        Instances__c testExistingInstance = TestingUtils.buildInstance(instanceName);
        testExistingInstance.Is_Deleted__c = true;
        insert testExistingInstance;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.newInstance.record.Name = instanceName;
        controller.newInstance.record.Type__c = instanceType;

        Test.startTest();
            try {
                 controller.undeleteInstance();
            } catch(ALMException e) {
                System.assert(false, 'No exception should be thrown.');
            }
        Test.stopTest();
        List<Instances__c> actualInstances = [SELECT Id, Is_Deleted__c FROM Instances__c];
        System.assertEquals(1, actualInstances.size(), 'There should be one instance.');
        System.assertEquals(testExistingInstance.Id, actualInstances[0].Id, 'There correct instance should exist.');
        System.assertEquals(false, actualInstances[0].Is_Deleted__c, 'The instance should not be marked as deleted');
    }

    static testMethod void undeleteInstance_error() {
        String instanceName = 'TestInstance';
        String instanceType = 'Production / Developer';

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.newInstance.record.Name = instanceName;
        controller.newInstance.record.Type__c = instanceType;

        Test.startTest();
            controller.undeleteInstance();
        Test.stopTest();

        System.assertEquals(false, controller.pageMessages.isEmpty(), 'An error should be shown when the undelete method encounters an error');
        System.assert(TestingUtils.pageMessageContains(System.Label.Instance_Undelete_Error ), 'The correct error message should be shown');
        List<Instances__c> actualInstances = [SELECT Id, Is_Deleted__c FROM Instances__c];
        System.assertEquals(0, actualInstances.size(), 'There should be zero instances.');
    }

    static testMethod void loadInstance_withNoActiveJobs() {
        setup();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceSandbox.Id;

        Test.startTest();

            controller.loadInstance();

        Test.stopTest();

        System.assertEquals(instanceSandbox.Id, controller.currentInstance.id, 'The selected instance should be loaded');
        System.assertNotEquals(null, controller.currentInstance.scanJob, 'A new Scan Job should be initialized');
        System.assertNotEquals(null, controller.currentInstance.butrJob, 'A new Butr Job should be initialized');
        System.assertEquals(null, controller.currentInstance.scanJob.Id, 'A new Scan Job should be initialized');
        System.assertEquals(null, controller.currentInstance.butrJob.Id, 'A new Butr Job should be initialized');
        System.assertEquals(instanceSandbox.Id, controller.currentInstance.scanJob.Source_Instance__c, 'The new scan job should look up to the selected instance');
        System.assertEquals(instanceSandbox.Id, controller.currentInstance.butrJob.Source_Instance__c, 'The new butr job should look up to the selected instance');
    }

    static testMethod void loadInstance_withActiveJobs() {
        setup();

        Map<String, ALM_Job__c> jobs = new Map<String, ALM_Job__c>();
        ALM_Job__c scanJob = TestingUtils.buildScanJob(instanceSandbox.Id, instanceSandbox.Id, ScanServices.TOOL_STATUS_SCHEDULED);
        ALM_Job__c butrJob = TestingUtils.buildButrJob(instanceSandbox.Id, ScanServices.TOOL_STATUS_SCHEDULED);
        jobs.put('scan', scanJob);
        jobs.put('butr', butrJob);
        insert new List<ALM_Job__c>(jobs.values());

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceSandbox.Id;

        Test.startTest();

            controller.loadInstance();

        Test.stopTest();

        System.assertEquals(instanceSandbox.Id, controller.currentInstance.id, 'The selected instance should be loaded');
        System.assertNotEquals(null, controller.currentInstance.scanJob, 'The existing scan job should be loaded');
        System.assertNotEquals(null, controller.currentInstance.butrJob, 'The existing butr job should be loaded');
        System.assertEquals(jobs.get('scan').Id, controller.currentInstance.scanJob.Id, 'The existing scan job should be loaded');
        System.assertEquals(jobs.get('butr').Id, controller.currentInstance.butrJob.Id, 'The existing butr job should be loaded');
    }

    static testMethod void loadInstance_withActiveScanJob_defaultALMInstance() {
        setup();

        ALM_Job__c scanjob = TestingUtils.buildScanJob(instanceSandbox.Id, null, ScanServices.TOOL_STATUS_SCHEDULED);
        insert scanjob;

        instanceProd.Is_ALM_Instance__c = true;
        update instanceProd;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceSandbox.Id;

        Test.startTest();

            controller.loadInstance();

        Test.stopTest();

        System.assertEquals(instanceProd.Id, controller.currentInstance.scanJob.Target_Instance__c, 'The existing scan job should default the target instance if it is not set.');
    }

    static testMethod void loadInstance_showLoginError() {
        Instances__c sourceInstance = new Instances__c(Name='Test Source Instance');
        insert sourceInstance;

        Auth_User__c authUser = TestingUtils.buildAuthUser(UserInfo.getUserId(), sourceInstance.Id, true);
        authUser.Is_Refresh_Token_Valid__c = false;
        insert authUser;

        ALM_Job__c job = TestingUtils.buildScanJob(sourceInstance.Id, null, ScanServices.TOOL_STATUS_SCHEDULED);
        insert job;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = sourceInstance.Id;

        Test.startTest();

           controller.loadInstance();

        Test.stopTest();

        System.assertEquals(true, !controller.pageMessages.isEmpty(), 'An error should be shown when the current job has an invalid login');

        String expectedMessage = String.format(System.Label.Tool_Connection_Error, new List<String>{ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN), sourceInstance.Name});
        System.assertEquals(expectedMessage, controller.pageMessages[0].message, 'An error should be shown when the current job has an invalid login');
    }

    static testMethod void updateAuthMessages() {
        Instances__c sourceInstance = new Instances__c(Name='Test Source Instance');
        insert sourceInstance;

        Auth_User__c authUser = TestingUtils.buildAuthUser(UserInfo.getUserId(), sourceInstance.Id, true);
        authUser.Is_Refresh_Token_Valid__c = false;
        insert authUser;

        ALM_Job__c job = TestingUtils.buildScanJob(sourceInstance.Id, null, ScanServices.TOOL_STATUS_SCHEDULED);
        insert job;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = sourceInstance.Id;
        controller.loadInstance();
        controller.pageMessages = null;

        Test.startTest();

            controller.updateAuthMessages();

        Test.stopTest();

        System.assertEquals(true, !controller.pageMessages.isEmpty(), 'updateAuthMessages should update the page messages');

        String expectedMessage = String.format(System.Label.Tool_Connection_Error, new List<String>{ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN), sourceInstance.Name});
        System.assertEquals(expectedMessage, controller.pageMessages[0].message, 'updateAuthMessages should re-validate the authorization');
    }

    static testMethod void updateAuthMessages_sightlineUserMatch() {
        TestingUtils.setupSightlineAuth();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.pageMessages = null;

        Test.startTest();

            controller.updateAuthMessages();

        Test.stopTest();

        System.assert(controller.pageMessages.isEmpty(), 'No page messages should be generated');
    }

    static testMethod void updateAuthMessages_sightlineUserMisMatch() {
        TestingUtils.setupSightlineAuth();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.pageMessages = null;

        Auth_User__c sightlineAuthUser = OAuthServices.getAuthUserForTools(InstanceServices.almInstance.Id);
        sightlineAuthUser.Org_Id__c = null;
        update sightlineAuthUser;

        Test.startTest();

            controller.updateAuthMessages();

        Test.stopTest();

        System.assert(!controller.pageMessages.isEmpty(), 'Page messages should be populated');
        System.assertEquals(1, controller.pageMessages.size(), 'One page message should be generated');
        System.assert(TestingUtils.customPageMessageContains(System.Label.Admin_Console_OAuth_Wrong_Org, controller.pageMessages), 'The correct page message should be displayed');
    }

    static testMethod void save_noScanJob() {
        setup();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceSandbox.Id;

        controller.loadInstance();

        Test.startTest();
            String newDomain = 'My.new.domain';
            controller.currentInstance.record.Custom_Domain__c = newDomain;
            controller.save();
        Test.stopTest();

        instanceSandbox = [SELECT Name, Custom_Domain__c FROM Instances__c WHERE Id = :instanceSandbox.Id];

        System.assertEquals(newDomain, instanceSandbox.Custom_Domain__c, 'The instance should be updated with a new domain');

        System.assertEquals(false, controller.currentInstance.hasActiveScanJob, 'A Scan job should not be saved');
    }

    static testMethod void save_activateScanJob() {
        setup();
        TestingUtils.createOAuthSettings();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceSandbox.Id;

        controller.loadInstance();

        Test.startTest();
            controller.isScanActivated = true;
            controller.save();
        Test.stopTest();

        System.assertEquals(true, controller.currentInstance.hasActiveScanJob, 'The scan job should be saved and activated ');

        List<ALM_Job__c> scanJobs = [SELECT Id FROM ALM_Job__c WHERE Source_Instance__c =: instanceSandbox.Id];

        System.assertEquals(1, scanJobs.size(), 'The scan job should be inserted when saving');
    }

    static testMethod void save_activateScanJob_withErrors() {
        setup();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceSandbox.Id;

        controller.loadInstance();

        Test.startTest();
            controller.isScanActivated = true;
            //force the save to fail because of an invalid email
            controller.currentInstance.scanJob.Mail_To__c = 'foobar';

            controller.save();
        Test.stopTest();

        List<ALM_Job__c> scanJobs = [SELECT Id FROM ALM_Job__c WHERE Source_Instance__c =: instanceSandbox.Id];
        System.assertEquals(0, scanJobs.size(), 'No SCAN jobs should be inserted when there is an error');

        System.assertEquals(false, controller.currentInstance.hasActiveScanJob, 'The SCAN job Id should be cleared out if there is an error when inserting');

    }

    static testMethod void save_validateScheduledJobsGetCreated() {
        List<CronJobDetail> scheduledJobs = SCANServices.getCronJobDetails();
        if (scheduledJobs.size() > 0) {
            List<Id> cronJobIds = new List<String>();

            for (CronJobDetail cjd : scheduledJobs) {
                cronJobIds.add(cjd.Id);
            }
            List<CronTrigger> triggers = [SELECT Id FROM CronTrigger Where CronJobDetailId IN :cronJobIds];
            for (CronTrigger ct : triggers) {
                System.abortJob(ct.Id);
            }
        }

        setup();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceSandbox.Id;

        controller.loadInstance();

        Test.startTest();
            controller.isScanActivated = false;
            controller.save();
        Test.stopTest();

        scheduledJobs = SCANServices.getCronJobDetails();

        System.assertEquals(2, scheduledJobs.size(), 'Scheduled jobs should be scheduled when saving.');
    }

    static testMethod void save_pendingScanJobDeletion() {
        setup();

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceSandbox.Id;

        controller.loadInstance();

        Test.startTest();
            controller.isScanActivated = true;
            controller.currentInstance.isScanDeactivationPending = true;
            controller.save();
        Test.stopTest();

        List<ALM_Job__c> almJobs = [SELECT Id FROM ALM_Job__c WHERE Source_Instance__c=:instanceProd.Id];

        System.assertEquals(false, controller.currentInstance.isScanDeactivationPending, 'SCAN deactivation should no longer be pending after it is deleted.');
        System.assert(almJobs.isEmpty(), 'There should be no ALM Jobs after a successful deletion.');
        System.assertEquals(false, controller.isScanActivated, 'SCAN should not be activated after a successful deletion.');
        System.assertEquals(null, controller.currentInstance.scanJob.Id, 'The current instance\'s SCAN job ID should be null.');
    }

    static testMethod void getAllScanResults_validSingleInstance() {
        // Set up run times for instance SCAN jobs.
        DateTime startTime = DateTime.now();
        DateTime endTime = startTime.addMinutes(1);

        // Set up the first test instance.
        Instances__c testInstance = new Instances__c(Name='Test Instance');
        insert testInstance;

        // Set up an application result for the first test instance.
        ALM_Application_Result__c testApplicationResult = TestingUtils.createAlmApplicationResult(startTime, endTime, 'Success', 'Success', testInstance.Id, ALMJobServices.ToolType.SCAN);
        InstanceModel.ScanResult testApplicationScanResult = new InstanceModel.ScanResult(testApplicationResult);

        AdminInstanceManagementController controller = new AdminInstanceManagementController();

        Test.startTest();
            controller.getAllScanResults();
        Test.stopTest();

        List<InstanceModel> models = controller.allInstances;
        System.assertEquals(1, models.size(), 'There should be one instance model returned.');
        System.assertEquals(testApplicationScanResult.instanceId, models[0].lastScanResult.instanceId, 'The correct instance ID should be set on the SCAN result.');
    }

    static testMethod void getAllScanResults_validMultipleInstances() {
        // Set up run times for instance SCAN jobs.
        DateTime startTime = DateTime.now();
        DateTime endTime = startTime.addMinutes(1);

        // Set up the first test instance.
        Instances__c testInstance0 = new Instances__c(Name='Test Instance 0');
        insert testInstance0;

        // Set up an application result for the first test instance.
        ALM_Application_Result__c testApplicationResult = TestingUtils.createAlmApplicationResult(startTime, endTime, 'Success', 'Success', testInstance0.Id, ALMJobServices.ToolType.SCAN);
        InstanceModel.ScanResult testApplicationScanResult0 = new InstanceModel.ScanResult(testApplicationResult);

        // Set up the second test instance.
        Instances__c testInstance1 = new Instances__c(Name='Test Instance 1');
        insert testInstance1;

        // Set up an application result for the second test instance.
        testApplicationResult = TestingUtils.createAlmApplicationResult(startTime, endTime, 'Success', 'Success', testInstance1.Id, ALMJobServices.ToolType.SCAN);
        InstanceModel.ScanResult testApplicationScanResult1 = new InstanceModel.ScanResult(testApplicationResult);

        AdminInstanceManagementController controller = new AdminInstanceManagementController();

        Test.startTest();
            controller.getAllScanResults();
        Test.stopTest();

        List<InstanceModel> models = controller.allInstances;
        System.assertEquals(2, models.size(), 'There should be two instance models returned.');

        // Check the list to ensure that each SCAN result is correct and associated with the correct instance.
        for (Integer i = 0; i < models.size(); ++i) {
            if (models[i].id == testInstance0.Id) {
                System.assertEquals(testApplicationScanResult0.instanceId, models[i].lastScanResult.instanceId, 'The correct instance ID should be set on the SCAN result.');
            }
            else if (models[i].id == testInstance1.Id) {
                System.assertEquals(testApplicationScanResult1.instanceId, models[i].lastScanResult.instanceId, 'The correct instance ID should be set on the SCAN result.');
            }
            else {
                System.assert(false, 'If a result is in the returned collection that matches neither test instance ID, the test should fail.');
            }
        }
    }

    static testMethod void getAllInstances_noInstances() {
        Test.startTest();
            List<InstanceModel> models = AdminInstanceManagementController.getAllInstances();
        Test.stopTest();

        System.assertNotEquals(null, models, 'The returned instance model collection should not be null, even when no instances are present.');
        System.assertEquals(0, models.size(), 'The returned instance model collection should be of size zero when no instances are present.');
    }

    static testMethod void urlParameter_no_id_parameter() {
        Test.startTest();

           AdminInstanceManagementController controller = new AdminInstanceManagementController();

        Test.stopTest();

        System.assertEquals(null, controller.selectedInstanceId, 'The selectedInstanceId should be null when no id parameter is present in the URL');
    }

    static testMethod void urlParameter_has_id_parameter() {
        setup();

        String expectedId = instanceSandbox.Id;
        System.currentPageReference().getParameters().put('id', expectedId);

        Test.startTest();

           AdminInstanceManagementController controller = new AdminInstanceManagementController();

        Test.stopTest();

        System.assertEquals(expectedId, controller.selectedInstanceId, 'The selectedInstanceId should be set when the id parameter is present in the URL');
    }

    static testMethod void deleteScanJob() {
        setup();

        insert TestingUtils.buildScanJob(instanceProd.Id, instanceProd.Id, ScanServices.TOOL_STATUS_SCHEDULED);

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceProd.Id;
        controller.loadInstance();

        Test.startTest();
            controller.deleteScanJob();
        Test.stopTest();

        List<ALM_Job__c> almJobs = [SELECT Id FROM ALM_Job__c WHERE Source_Instance__c=:instanceProd.Id];

        System.assert(almJobs.isEmpty(), 'There should be no ALM Jobs after a successful deletion.');
        System.assertEquals(false, controller.isScanActivated, 'SCAN should not be activated after a successful deletion.');
        System.assertEquals(null, controller.currentInstance.scanJob.Id, 'The current instance\'s SCAN job ID should be null.');
    }

    static testMethod void deleteInstance_valid() {
        setup();

        insert TestingUtils.buildScanJob(instanceProd.Id, instanceProd.Id, ScanServices.TOOL_STATUS_SCHEDULED);

        AdminInstanceManagementController controller = setupAdminInstanceManagementController(instanceProd);

        Test.startTest();
            controller.deleteInstance();
        Test.stopTest();

        List<ALM_Job__c> almJobs = [SELECT Id FROM ALM_Job__c WHERE Source_Instance__c=:instanceProd.Id];
        List<Instances__c> instances = [SELECT Id, Is_Deleted__c FROM Instances__c WHERE Id=:instanceProd.Id];

        System.assertEquals(false, instances.isEmpty(), 'Instance should still exist.');
        System.assert(instances[0].Is_Deleted__c, 'The instance should be soft-deleted.');
        System.assert(almJobs.isEmpty(), 'ALM jobs should not exist.');
    }

    static testMethod void deleteInstance_invalid() {
        setup();

        insert TestingUtils.buildScanJob(instanceProd.Id, instanceProd.Id, ScanServices.TOOL_STATUS_SCHEDULED);

        AdminInstanceManagementController controller = setupAdminInstanceManagementController(instanceProd);

        controller.pageMessages.clear();

        Test.startTest();
            delete instanceProd;
            controller.deleteInstance();
        Test.stopTest();

        System.assertEquals(1, controller.pageMessages.size(), 'There should be one page message error.');
    }

    static testMethod void getAllInstances_exludingSoftDeleted() {
        setup();

        instanceSandbox.Is_Deleted__c = true;
        update instanceSandbox;

        Test.startTest();
            AdminInstanceManagementController controller = new AdminInstanceManagementController();
        Test.stopTest();

        System.assertEquals(1, controller.allInstances.size(), 'There should only be one instance returned.');
        System.assertEquals(instanceProd.Id, controller.allInstances[0].id, 'Only the instance which has not been deleted should be returned.');
    }


    static testMethod void instanceRename_valid() {

        setupDataWithComponents();

        String oldInstanceName = instanceProd.Name;
        String newInstanceName = 'prod_new';

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = instanceProd.Id;
        controller.loadInstance();
        controller.currentInstance.isInstanceRenamePending = true;

        List<Component__c> testComponents = [Select Id, Field_Modified_Data__c, Source_Instances__c, (select id, instance_name__c from Build_Components__r)
                                                from Component__c Where Source_Instances__c includes (:oldInstanceName)];

        System.assertNotEquals(null, controller.currentInstance, 'The selected instance should have been loaded.');
        System.assertEquals(1, testComponents.size(), 'There should be one component with a reference to the old instance name.');
        System.assertEquals(1, testComponents[0].Build_Components__r.size(), 'There should be one build component.');
        System.assertEquals(oldInstanceName, testComponents[0].Build_Components__r[0].instance_name__c, 'There should be one build component with a reference to the old instance name.');


        Test.startTest();
            controller.currentInstance.name = newInstanceName;
            controller.save();
        Test.stopTest();

        Instances__c instanceUpdate = [Select Id, Name from Instances__c Where Id = :instanceProd.Id];
        testComponents = [Select Id, Field_Modified_Data__c, Source_Instances__c, (select id, instance_name__c from Build_Components__r)
                          from Component__c Where Source_Instances__c includes (:newInstanceName)];

        System.assertEquals(newInstanceName, instanceUpdate.Name, 'The name of the selected instance should have been updated.');
        System.assertEquals(1, testComponents.size(), 'There should now be one component with a reference to the new instance name.');
        System.assertEquals(1, testComponents[0].Build_Components__r.size(), 'There should be one build component.');
        System.assertEquals(newInstanceName, testComponents[0].Build_Components__r[0].instance_name__c, 'There should be one build component with a reference to the old instance name.');
        List<FieldModifiedData> cmpEnvData = (List<FieldModifiedData>) JSON.deserialize(testComponents[0].Field_Modified_Data__c, List<FieldModifiedData>.class);
        System.assertEquals(1, cmpEnvData.size(), 'There should be one field modified data record for this component.');
        System.assertNotEquals(oldInstanceName, cmpEnvData[0].environmentName, 'The old instance name should have been replaced with the new name');
        System.assertEquals(false, controller.currentInstance.isInstanceRenamePending, 'We expect the pending changes to be set to false.');
    }

    static testMethod void instanceRename_invalid_locked() {
        setupDataWithComponents();

        String oldInstanceName = 'Old Instance Name';
        String newInstanceName = 'New Instance Name';

        Long expirationTime = DateTime.now().addHours(1).getTime();
        Instances__c lockedInstance = new Instances__c(Name=oldInstanceName, Rename_Lock_Expiration_Time__c=expirationTime);
        insert lockedInstance;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = lockedInstance.Id;

        controller.loadInstance();
        controller.currentInstance.isInstanceRenamePending = true;

        Test.startTest();
            controller.currentInstance.name = newInstanceName;
            controller.save();
        Test.stopTest();

        Instances__c instance = [SELECT Name FROM Instances__c WHERE Id=:lockedInstance.Id LIMIT 1][0];

        System.assertEquals(true, controller.currentInstance.checkIsRenameLocked(), 'The instance should be locked.');
        System.assertEquals(oldInstanceName, instance.Name, 'The instance should not be renamed while the instance is locked.');
        System.assertEquals(false, controller.currentInstance.isInstanceRenamePending, 'The instance should not have a pending rename.');

        List<Component__c> testComponents = [
            SELECT Id, Field_Modified_Data__c, Source_Instances__c,
                (SELECT id, instance_name__c FROM Build_Components__r)
            FROM Component__c
            WHERE Source_Instances__c includes (:newInstanceName)
        ];

        System.assert(testComponents.isEmpty(), 'There should be no components with a reference to the new instance name.');
    }

    static testMethod void instanceRename_invalid_SCAN_pending() {
        setupDataWithComponents();

        String oldInstanceName = 'Old Instance Name';
        String newInstanceName = 'New Instance Name';

        Instances__c testInstance = new Instances__c(Name=oldInstanceName, Rename_Lock_Expiration_Time__c=null);
        insert testInstance;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = testInstance.Id;

        controller.loadInstance();
        controller.currentInstance.isInstanceRenamePending = true;
        controller.currentInstance.initNewScanJob();
        controller.currentInstance.scanJob.Status__c = SCANServices.TOOL_STATUS_QUEUED;

        Test.startTest();
            controller.currentInstance.name = newInstanceName;
            controller.save();
        Test.stopTest();

        Instances__c instance = [SELECT Name FROM Instances__c WHERE Id=:testInstance.Id LIMIT 1][0];

        System.assertEquals(false, controller.currentInstance.checkIsRenameLocked(), 'The instance should be unlocked.');
        System.assertEquals(oldInstanceName, instance.Name, 'The instance should not be renamed while SCAN is pending.');
        System.assertEquals(false, controller.currentInstance.isInstanceRenamePending, 'The instance should not have a pending rename.');

        List<Component__c> testComponents = [
            SELECT Id, Field_Modified_Data__c, Source_Instances__c,
                (SELECT id, instance_name__c FROM Build_Components__r)
            FROM Component__c
            WHERE Source_Instances__c includes (:newInstanceName)
        ];

        System.assert(testComponents.isEmpty(), 'There should be no components with a reference to the new instance name.');
    }

    static testMethod void instanceRename_invalid_SCAN_running() {
        setupDataWithComponents();

        String oldInstanceName = 'Old Instance Name';
        String newInstanceName = 'New Instance Name';

        Instances__c testInstance = new Instances__c(Name=oldInstanceName, Rename_Lock_Expiration_Time__c=null);
        insert testInstance;

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.selectedInstanceId = testInstance.Id;

        controller.loadInstance();
        controller.currentInstance.isInstanceRenamePending = true;
        controller.currentInstance.initNewScanJob();
        controller.currentInstance.scanJob.Status__c = SCANServices.TOOL_STATUS_RUNNING;

        Test.startTest();
            controller.currentInstance.name = newInstanceName;
            controller.save();
        Test.stopTest();

        Instances__c instance = [SELECT Name FROM Instances__c WHERE Id=:testInstance.Id LIMIT 1][0];

        System.assertEquals(false, controller.currentInstance.checkIsRenameLocked(), 'The instance should be unlocked.');
        System.assertEquals(oldInstanceName, instance.Name, 'The instance should not be renamed while SCAN is running.');
        System.assertEquals(false, controller.currentInstance.isInstanceRenamePending, 'The instance should not have a pending rename.');

        List<Component__c> testComponents = [
            SELECT Id, Field_Modified_Data__c, Source_Instances__c,
                (SELECT id, instance_name__c FROM Build_Components__r)
            FROM Component__c
            WHERE Source_Instances__c includes (:newInstanceName)
        ];

        System.assert(testComponents.isEmpty(), 'There should be no components with a reference to the new instance name.');
    }

    private static final String testInstanceName = 'Test Instance Name';
    private static final String testInstanceType = 'Test Instance Type';
    private static final String testInstanceCustomDomain = 'https://www.example.com';
    private static final String testInstanceJobEmail = 'fake@example.com';
    private static final String testInstanceJobStatus = 'Test Instance Job Status';
    private static final Integer testInstanceJobFrequency = 3;
    private static final Long testInstanceJobStartTime = DateTime.now().getTime();
    private static final Long testInstanceJobEndTime = DateTime.newInstance(testInstanceJobStartTime).addMinutes(1).getTime();
    private static final Map<String, Object> testPageStateMap = new Map<String, Object>{
        'name' => testInstanceName,
        'type' => testInstanceType,
        'domain' => testInstanceCustomDomain,
        'isScanActivated' => true,
        'scanEmail' => testInstanceJobEmail,
        'scanStatus' => testInstanceJobStatus,
        'scanScheduledMonday' => true,
        'scanScheduledTuesday' => false,
        'scanScheduledWednesday' => true,
        'scanScheduledThursday' => false,
        'scanScheduledFriday' => true,
        'scanScheduledSaturday' => false,
        'scanScheduledSunday' => true,
        'scanFrequency' => testInstanceJobFrequency,
        'scanStartTime' => testInstanceJobStartTime,
        'scanEndTime' =>testInstanceJobEndTime,
        'isButrActivated' => false,
        'butrEmail' => testInstanceJobEmail,
        'butrStatus' => testInstanceJobStatus,
        'butrScheduledMonday' => false,
        'butrScheduledTuesday' => false,
        'butrScheduledWednesday' => false,
        'butrScheduledThursday' => false,
        'butrScheduledFriday' => false,
        'butrScheduledSaturday' => true,
        'butrScheduledSunday' => true,
        'butrFrequency' => testInstanceJobFrequency,
        'butrStartTime' => testInstanceJobStartTime,
        'butrEndTime' => testInstanceJobEndTime
    };

    private static testMethod void getCurrentPageStateMap() {
        setup();

        ALM_Job__c testScanJob = TestingUtils.createDefaultScanJob(instanceSandbox, instanceProd);
        ALM_Job__c testButrJob = TestingUtils.createDefaultButrJob(instanceSandbox, instanceProd);

        AdminInstanceManagementController testController = new AdminInstanceManagementController();
        testController.selectedInstanceId = instanceSandbox.Id;
        testController.loadInstance();

        Test.startTest();

            testController.currentInstance.Name = testInstanceName;
            testController.currentInstance.record.Type__c = testInstanceType;
            testController.currentInstance.record.Custom_Domain__c = testInstanceCustomDomain;
            testController.isScanActivated = false;
            testController.isButrActivated = true;
            testController.currentInstance.butrJob.Mail_To__c = testInstanceJobEmail;
            testController.currentInstance.butrJob.Status__c = testInstanceJobStatus;
            testController.currentInstance.butrJob.Scheduled_On_Monday__c = true;
            testController.currentInstance.butrJob.Scheduled_On_Tuesday__c = true;
            testController.currentInstance.butrJob.Scheduled_On_Wednesday__c = true;
            testController.currentInstance.butrJob.Scheduled_On_Thursday__c = true;
            testController.currentInstance.butrJob.Scheduled_On_Friday__c = true;
            testController.currentInstance.butrJob.Scheduled_On_Saturday__c = false;
            testController.currentInstance.butrJob.Scheduled_On_Sunday__c = false;
            testController.currentInstance.butrJob.Interval__c = testInstanceJobFrequency;
            testController.currentInstance.butrStartTime = testInstanceJobStartTime;
            testController.currentInstance.butrEndTime = testInstanceJobEndTime;

            Map<String, Object> actualPageStateMap = testController.getCurrentPageStateMap();

        Test.stopTest();

        System.assertEquals(17, actualPageStateMap.size(), 'The proper number of state elements should be retrieved properly.');

        System.assertEquals(testInstanceName, actualPageStateMap.get('name'), 'The instance name should be retrieved properly.');
        System.assertEquals(testInstanceType, actualPageStateMap.get('type'), 'The instance type should be retrieved properly.');
        System.assertEquals(testInstanceCustomDomain, actualPageStateMap.get('domain'), 'The instance custom domain should be retrieved properly.');

        System.assertEquals(false, actualPageStateMap.get('isScanActivated'), 'SCAN should not be active.');
        System.assert(!actualPageStateMap.containsKey('scanEmail'), 'The SCAN email should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanStatus'), 'The SCAN status should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanScheduledMonday'), 'The SCAN Monday schedule should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanScheduledTuesday'), 'The SCAN Tuesday schedule should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanScheduledWednesday'), 'The SCAN Wednesday schedule should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanScheduledThursday'), 'The SCAN Thursday schedule should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanScheduledFriday'), 'The SCAN Friday schedule should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanScheduledSaturday'), 'The SCAN Saturday schedule should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanScheduledSunday'), 'The SCAN Sunday schedule should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanFrequency'), 'The SCAN frequency should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanStartTime'), 'The SCAN start time should not be retrieved.');
        System.assert(!actualPageStateMap.containsKey('scanEndTime'), 'The SCAN end time should not be retrieved.');

        System.assertEquals(true, actualPageStateMap.get('isButrActivated'), 'BUTR should be active.');
        System.assertEquals(testInstanceJobEmail, actualPageStateMap.get('butrEmail'), 'The BUTR email should be retrieved.');
        System.assertEquals(testInstanceJobStatus, actualPageStateMap.get('butrStatus'), 'The BUTR status should be retrieved.');
        System.assertEquals(true, actualPageStateMap.get('butrScheduledMonday'), 'The BUTR Monday schedule should be retrieved.');
        System.assertEquals(true, actualPageStateMap.get('butrScheduledTuesday'), 'The BUTR Tuesday schedule should be retrieved.');
        System.assertEquals(true, actualPageStateMap.get('butrScheduledWednesday'), 'The BUTR Wednesday schedule should be retrieved.');
        System.assertEquals(true, actualPageStateMap.get('butrScheduledThursday'), 'The BUTR Thursday schedule should be retrieved.');
        System.assertEquals(true, actualPageStateMap.get('butrScheduledFriday'), 'The BUTR Friday schedule should be retrieved.');
        System.assertEquals(false, actualPageStateMap.get('butrScheduledSaturday'), 'The BUTR Saturday schedule should be retrieved.');
        System.assertEquals(false, actualPageStateMap.get('butrScheduledSunday'), 'The BUTR Sunday schedule should be retrieved.');
        System.assertEquals(testInstanceJobFrequency, Integer.valueOf(actualPageStateMap.get('butrFrequency')), 'The BUTR frequency should be retrieved.');
        System.assertEquals(testInstanceJobStartTime, (Long)actualPageStateMap.get('butrStartTime'), 'The BUTR start time should be retrieved.');
        System.assertEquals(testInstanceJobEndTime, (Long)actualPageStateMap.get('butrEndTime'), 'The BUTR end time should be retrieved.');
    }

    private static testMethod void restorePageState() {
        setup();

        State.store(new PageState(AdminInstanceManagementController.PAGE_STATE_TOKEN, testPageStateMap));

        AdminInstanceManagementController testController = new AdminInstanceManagementController();
        testController.selectedInstanceId = instanceSandbox.Id;
        testController.loadInstance();

        Test.startTest();

            testController.restorePageState();

        Test.stopTest();

        System.assertEquals(testInstanceName, testController.currentInstance.Name, 'The instance name should be restored properly.');
        System.assertEquals(testInstanceType, testController.currentInstance.record.Type__c, 'The instance type should be restored properly.');
        System.assertEquals(testInstanceCustomDomain, testController.currentInstance.record.Custom_Domain__c, 'The instance custom domain should be restored properly.');

        System.assertEquals(true, testController.isScanActivated, 'SCAN should be active.');
        System.assertEquals(testInstanceJobEmail, testController.currentInstance.scanJob.Mail_To__c, 'The SCAN email should be restored.');
        System.assertEquals(testInstanceJobStatus, testController.currentInstance.scanJob.Status__c, 'The SCAN status should be restored.');
        System.assertEquals(true, testController.currentInstance.scanJob.Scheduled_On_Monday__c, 'The SCAN Monday schedule should be restored.');
        System.assertEquals(false, testController.currentInstance.scanJob.Scheduled_On_Tuesday__c, 'The SCAN Tuesday schedule should be restored.');
        System.assertEquals(true, testController.currentInstance.scanJob.Scheduled_On_Wednesday__c, 'The SCAN Wednesday schedule should be restored.');
        System.assertEquals(false, testController.currentInstance.scanJob.Scheduled_On_Thursday__c, 'The SCAN Thursday schedule should be restored.');
        System.assertEquals(true, testController.currentInstance.scanJob.Scheduled_On_Friday__c, 'The SCAN Friday schedule should be restored.');
        System.assertEquals(false, testController.currentInstance.scanJob.Scheduled_On_Saturday__c, 'The SCAN Saturday schedule should be restored.');
        System.assertEquals(true, testController.currentInstance.scanJob.Scheduled_On_Sunday__c, 'The SCAN Sunday schedule should be restored.');
        System.assertEquals(testInstanceJobFrequency, testController.currentInstance.scanJob.Interval__c, 'The SCAN frequency should be restored.');
        System.assertEquals(testInstanceJobStartTime, testController.currentInstance.scanStartTime, 'The SCAN start time should be restored.');
        System.assertEquals(testInstanceJobEndTime, testController.currentInstance.scanEndTime, 'The SCAN end time should be restored.');

        System.assertEquals(false, testController.isButrActivated, 'BUTR should not be active.');
        System.assertEquals(null, testController.currentInstance.butrJob.Mail_To__c, 'The BUTR email should not be restored.');
        System.assertEquals(SCANServices.TOOL_STATUS_SCHEDULED, testController.currentInstance.butrJob.Status__c, 'The BUTR status should not be restored.');
        System.assertEquals(true, testController.currentInstance.butrJob.Scheduled_On_Monday__c, 'The BUTR Monday schedule should not be restored.');
        System.assertEquals(true, testController.currentInstance.butrJob.Scheduled_On_Tuesday__c, 'The BUTR Tuesday schedule should not be restored.');
        System.assertEquals(true, testController.currentInstance.butrJob.Scheduled_On_Wednesday__c, 'The BUTR Wednesday schedule should not be restored.');
        System.assertEquals(true, testController.currentInstance.butrJob.Scheduled_On_Thursday__c, 'The BUTR Thursday schedule should not be restored.');
        System.assertEquals(true, testController.currentInstance.butrJob.Scheduled_On_Friday__c, 'The BUTR Friday schedule should not be restored.');
        System.assertEquals(false, testController.currentInstance.butrJob.Scheduled_On_Saturday__c, 'The BUTR Saturday schedule should not be restored.');
        System.assertEquals(false, testController.currentInstance.butrJob.Scheduled_On_Sunday__c, 'The BUTR Sunday schedule should not be restored.');
        System.assertEquals(InstanceModel.DEFAULT_BUTR_INTERVAL, testController.currentInstance.butrJob.Interval__c, 'The BUTR frequency should not be restored.');
        System.assertEquals(InstanceModel.DEFAULT_BUTR_START_TIME, DateTime.newInstance(testController.currentInstance.butrStartTime), 'The BUTR start time should not be restored.');
        System.assertEquals(InstanceModel.DEFAULT_BUTR_END_TIME, DateTime.newInstance(testController.currentInstance.butrEndTime), 'The BUTR end time should not be restored.');
    }

    private static testMethod void savePageState() {
        setup();

        ALM_Job__c testScanJob = TestingUtils.createDefaultScanJob(instanceSandbox, instanceProd);
        ALM_Job__c testButrJob = TestingUtils.createDefaultButrJob(instanceSandbox, instanceProd);

        AdminInstanceManagementController testController = new AdminInstanceManagementController();
        testController.selectedInstanceId = instanceSandbox.Id;
        testController.loadInstance();

        Test.startTest();

            testController.currentInstance.Name = testInstanceName;
            testController.currentInstance.record.Type__c = testInstanceType;
            testController.currentInstance.record.Custom_Domain__c = testInstanceCustomDomain;
            testController.isScanActivated = false;
            testController.currentInstance.butrJob.Mail_To__c = testInstanceJobEmail;
            testController.currentInstance.butrJob.Status__c = testInstanceJobStatus;
            testController.currentInstance.butrJob.Scheduled_On_Wednesday__c = false;
            testController.currentInstance.butrJob.Scheduled_On_Sunday__c = false;
            testController.currentInstance.butrJob.Interval__c = testInstanceJobFrequency;
            testController.currentInstance.butrEndTime = testInstanceJobEndTime;

            testController.savePageState();

        Test.stopTest();

        PageState actualPageState = new PageState(AdminInstanceManagementController.PAGE_STATE_TOKEN);
        State.retrieve(actualPageState);

        System.assertEquals(10, actualPageState.stateMap.size(), 'The proper number of state elements should be saved properly.');
        System.assertEquals(testInstanceName, actualPageState.stateMap.get('name'), 'The instance name should be saved properly.');
        System.assertEquals(testInstanceType, actualPageState.stateMap.get('type'), 'The instance type should be saved properly.');
        System.assertEquals(testInstanceCustomDomain, actualPageState.stateMap.get('domain'), 'The instance custom domain should be saved properly.');
        System.assertEquals(false, actualPageState.stateMap.get('isScanActivated'), 'The SCAN activation status should be saved properly.');
        System.assertEquals(testInstanceJobEmail, actualPageState.stateMap.get('butrEmail'), 'The BUTR email should be saved properly.');
        System.assertEquals(testInstanceJobStatus, actualPageState.stateMap.get('butrStatus'), 'The BUTR status should be saved properly.');
        System.assertEquals(false, actualPageState.stateMap.get('butrScheduledWednesday'), 'The BUTR Wednesday schedule should be saved properly.');
        System.assertEquals(false, actualPageState.stateMap.get('butrScheduledSunday'), 'The BUTR Sunday schedule should be saved properly.');
        System.assertEquals(testInstanceJobFrequency, actualPageState.stateMap.get('butrFrequency'), 'The BUTR frequency should be saved properly.');
        System.assertEquals(testInstanceJobEndTime, actualPageState.stateMap.get('butrEndTime'), 'The BUTR end time should be saved properly.');
    }

    private static testMethod void loadPageState() {
        State.store(new PageState(AdminInstanceManagementController.PAGE_STATE_TOKEN, testPageStateMap));

        Test.startTest();

            Map<String, Object> actualPageStateMap = new AdminInstanceManagementController().loadPageState();

        Test.stopTest();

        System.assertEquals(testPageStateMap.size(), actualPageStateMap.size(), 'The proper number of state elements should be loaded properly.');

        System.assertEquals(testInstanceName, actualPageStateMap.get('name'), 'Instance name should be loaded properly.');
        System.assertEquals(testInstanceType, actualPageStateMap.get('type'), 'Instance type should be loaded properly.');
        System.assertEquals(testInstanceCustomDomain, actualPageStateMap.get('domain'), 'Instance custom domain should be loaded properly.');

        System.assertEquals(true, actualPageStateMap.get('isScanActivated'), 'The SCAN activation status should be loaded properly.');
        System.assertEquals(testInstanceJobEmail, actualPageStateMap.get('scanEmail'), 'The SCAN email should be loaded properly.');
        System.assertEquals(testInstanceJobStatus, actualPageStateMap.get('scanStatus'), 'The SCAN status should be loaded properly.');
        System.assertEquals(true, actualPageStateMap.get('scanScheduledMonday'), 'The SCAN Monday schedule should be loaded properly.');
        System.assertEquals(false, actualPageStateMap.get('scanScheduledTuesday'), 'The SCAN Tuesday schedule should be loaded properly.');
        System.assertEquals(true, actualPageStateMap.get('scanScheduledWednesday'), 'The SCAN Wednesday schedule should be loaded properly.');
        System.assertEquals(false, actualPageStateMap.get('scanScheduledThursday'), 'The SCAN Thursday schedule should be loaded properly.');
        System.assertEquals(true, actualPageStateMap.get('scanScheduledFriday'), 'The SCAN Friday schedule should be loaded properly.');
        System.assertEquals(false, actualPageStateMap.get('scanScheduledSaturday'), 'The SCAN Saturday schedule should be loaded properly.');
        System.assertEquals(true, actualPageStateMap.get('scanScheduledSunday'), 'The SCAN Sunday schedule should be loaded properly.');
        System.assertEquals(testInstanceJobFrequency, actualPageStateMap.get('scanFrequency'), 'The SCAN frequency should be loaded properly.');
        System.assertEquals(testInstanceJobStartTime, actualPageStateMap.get('scanStartTime'), 'The SCAN start time should be loaded properly.');
        System.assertEquals(testInstanceJobEndTime, actualPageStateMap.get('scanEndTime'), 'The SCAN end time should be loaded properly.');

        System.assertEquals(false, actualPageStateMap.get('isButrActivated'), 'The BUTR activation status should be loaded properly.');
        System.assertEquals(testInstanceJobEmail, actualPageStateMap.get('butrEmail'), 'The BUTR email should be loaded properly.');
        System.assertEquals(testInstanceJobStatus, actualPageStateMap.get('butrStatus'), 'The BUTR status should be loaded properly.');
        System.assertEquals(false, actualPageStateMap.get('butrScheduledMonday'), 'The BUTR Monday schedule should be loaded properly.');
        System.assertEquals(false, actualPageStateMap.get('butrScheduledTuesday'), 'The BUTR Tuesday schedule should be loaded properly.');
        System.assertEquals(false, actualPageStateMap.get('butrScheduledWednesday'), 'The BUTR Wednesday schedule should be loaded properly.');
        System.assertEquals(false, actualPageStateMap.get('butrScheduledThursday'), 'The BUTR Thursday schedule should be loaded properly.');
        System.assertEquals(false, actualPageStateMap.get('butrScheduledFriday'), 'The BUTR Friday schedule should be loaded properly.');
        System.assertEquals(true, actualPageStateMap.get('butrScheduledSaturday'), 'The BUTR Saturday schedule should be loaded properly.');
        System.assertEquals(true, actualPageStateMap.get('butrScheduledSunday'), 'The BUTR Sunday schedule should be loaded properly.');
        System.assertEquals(testInstanceJobFrequency, actualPageStateMap.get('butrFrequency'), 'The BUTR frequency should be loaded properly.');
        System.assertEquals(testInstanceJobStartTime, actualPageStateMap.get('butrStartTime'), 'The BUTR start time should be loaded properly.');
        System.assertEquals(testInstanceJobEndTime, actualPageStateMap.get('butrEndTime'), 'The BUTR end time should be loaded properly.');
    }

    private static testMethod void expirePageState() {
        PageState testPageState = new PageState(AdminInstanceManagementController.PAGE_STATE_TOKEN);

        State.store(testPageState);

        System.assertEquals(1, [SELECT Count() FROM State__c WHERE Token__c = :testPageState.getStateToken()], 'The page state should exist.');

        Test.startTest();

            new AdminInstanceManagementController().expirePageState();

        Test.stopTest();

        System.assertEquals(0, [SELECT Count() FROM State__c WHERE Token__c = :testPageState.getStateToken()], 'The page state should not exist.');
    }

    @isTest
    private static void validateAuth_invalidSightlineAuth_doNotCheck() {
        String instanceName = 'Test Instance Name';

        Instances__c instance = TestingUtils.createInstance(instanceName);
        Auth_User__c authUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id, true);

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.isScanActivated = true;
        controller.isButrActivated = true;
        controller.currentInstance = new InstanceModel(instance);

        Test.startTest();

            List<PageMessage> pageMessages = controller.validateAuth(false);

        Test.stopTest();

        System.assert(pageMessages.isEmpty(), 'No page messages should be returned.');
    }

    @isTest
    private static void validateAuth_invalidSightlineAuth_check() {
        String instanceName = 'Test Instance Name';

        Instances__c instance = TestingUtils.createInstance(instanceName);
        Auth_User__c authUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id, true);

        AdminInstanceManagementController controller = new AdminInstanceManagementController();
        controller.isScanActivated = false;
        controller.isButrActivated = false;
        controller.currentInstance = new InstanceModel(instance);

        Test.startTest();

            List<PageMessage> pageMessages = controller.validateAuth(true);

        Test.stopTest();

        System.assertEquals(1, pageMessages.size(), 'A single page message should be returned.');
        System.assert(pageMessages[0].message.contains(System.Label.Scan_ALM_Settings_error), 'The proper page message should be returned.');
    }
}