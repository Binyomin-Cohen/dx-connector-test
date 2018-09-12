@isTest
private class TestDeploymentRequest {
    static Release__c testRelease;
    static Instances__c testInstance;
    static Auth_User__c testAuthUser;
    static Backlog__c testBacklog;
    static Build__c testBuild;

    static void setup() {
        System.runAs(TestingUtils.ADMIN_USER) {
            testRelease = new Release__c(Name='Summer 14');
            insert testRelease;

            testInstance = new Instances__c(Name='dev');
            insert testInstance;

            testAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), testInstance.Id);

            testBacklog = new Backlog__c(Release__c=testRelease.Id, Status__c='Complete');
            insert testBacklog;

            testBuild = TestingUtils.createBuild(testRelease.Id, BuildServices.STATUS_SUCCESS);
        }
    }

    static Deployment_Attempt__c getDeploymentAttempt(String deploymentAttemptId) {
        return [
            SELECT CreatedById, UUID__c, SF_Deployment_Id__c,
                Test_Level__c, Ignore_Deployment_Warnings__c, Is_Validation__c,
                Is_Quick_Deploy__c, Target_Instance__c, Specified_Tests__c
            FROM Deployment_Attempt__c
            WHERE Id=:deploymentAttemptId
            LIMIT 1
        ];
    }

    static testMethod void deploymentRequest_constructor() {
        String testPackageURL = 'Test Package URL';
        String testUUID = 'Test UUID';
        String testSFDeploymentId = 'Test SF Deployment ID';
        String testSpecifiedTests = 'TestAssembler,TestRevisions';

        setup();
        OAuthServices.AppSettings testPrivateSettings = new OAuthServices.AppSettings(TestingUtils.createOAuthSettings());
        Auth_User__c testSightlineAuthUser = TestingUtils.setupSightlineAuth();

        testBuild.Package_URL__c = testPackageURL;

        Deployment_Attempt__c testAttempt = new Deployment_Attempt__c(
            UUID__c = testUUID,
            SF_Deployment_Id__c = testSFDeploymentId,
            Ignore_Deployment_Warnings__c = true,
            Is_Validation__c = true,
            Is_Quick_Deploy__c = true,
            Specified_Tests__c = testSpecifiedTests,
            Target_Instance__c = testInstance.Id
        );
        System.runAs(TestingUtils.ADMIN_USER) {
            insert testAttempt;
        }
        testAttempt = [
            SELECT CreatedById, UUID__c, SF_Deployment_Id__c,
                Test_Level__c, Ignore_Deployment_Warnings__c,
                Is_Validation__c, Is_Quick_Deploy__c, Target_Instance__c, Specified_Tests__c
            FROM Deployment_Attempt__c
            WHERE Id=:testAttempt.Id
            LIMIT 1
        ];

        Test.startTest();

            DeploymentRequest testRequest = new DeploymentRequest(testBuild, testAttempt);

        Test.stopTest();

        System.assertEquals(testBuild.Id, testRequest.buildId, 'The build ID should match.');
        System.assertEquals(testPackageURL, testRequest.packageURL, 'The package URL should match.');
        System.assertEquals(testSpecifiedTests, testRequest.deploymentOptions.get('specifiedTests'), 'The target specified tests should match.');
        System.assertEquals(testSightlineAuthUser.Refresh_Token__c, testRequest.sightlineRefreshToken, 'The Sightline refresh token should match.');
        System.assertEquals(testPrivateSettings.consumerKey, testRequest.clientId, 'The client ID should match.');
        System.assertEquals(testPrivateSettings.consumerSecret, testRequest.clientSecret, 'The client secret should match.');
        System.assertEquals(testAuthUser.Refresh_Token__c, testRequest.targetInstance.get('refreshToken'), 'The target refresh token should match.');
        System.assertEquals(testAuthUser.Instance_URL__c, testRequest.targetInstance.get('serverURL'), 'The target server URL should match.');
        System.assertEquals(testAttempt.Ignore_Deployment_Warnings__c, Boolean.valueOf(testRequest.deploymentOptions.get('ignoreDeploymentWarnings')), 'The ignoreWarnings option should be true.');
    }

    static testMethod void getJobStatus() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.GET_DEPLOYMENT_ACTION));

        Test.startTest();

            Deployment_Attempt__c deployment = DeploymentRequest.getJobStatus(MockWebAssemblerAPI.JOB_ID);

        Test.stopTest();

        System.assertEquals(MockWebAssemblerAPI.DEPLOY_RESULT_SUCCESS_STATUS, deployment.Status__c, 'The status should be set to the success response');
        System.assertEquals(MockWebAssemblerAPI.JOB_ID, deployment.UUID__c, 'The uuid should be set to the job Id');
        System.assertEquals(MockWebAssemblerAPI.COMPONENT_COUNT, deployment.Number_Components_Total__c, 'The Number_Components_Total__c should be set from the numberComponentsTotal in the response');
        System.assertEquals(MockWebAssemblerAPI.COMPONENT_COUNT, deployment.Number_Components_Deployed__c, 'The Number_Components_Deployed__c should be set from the numberComponentsDeployed in the response');
        System.assertEquals(MockWebAssemblerAPI.ASYNC_ID, deployment.SF_Deployment_Id__c, 'The SF deployment Id should be set from the asyncId in the response');
    }

    static testMethod void sendCancelRequest_validParams() {
        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();
        TestingUtils.createAuthUser(UserInfo.getUserId(), InstanceServices.almInstance.Id, false);

        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.DEPLOYMENTS_CANCEL_ACTION));

        Build__c build = TestingUtils.createBuild(null, BuildServices.STATUS_SUCCESS);
        Deployment_Attempt__c deploymentAttempt = new Deployment_Attempt__c(UUID__c = 'someBogusUUID', Target_Instance__c=InstanceServices.almInstance.Id, Build__c=build.Id);
        insert deploymentAttempt;
        deploymentAttempt = getDeploymentAttempt(deploymentAttempt.Id);

        DeploymentRequest request = new DeploymentRequest(build, deploymentAttempt);
        request.deployment = deploymentAttempt;

        Boolean success = true;

        Test.startTest();
            try {
                request.sendCancelRequest();
            } catch(ALMException e) {
                System.debug('=============> ' + e.getMessage());
                success = false;
            }
        Test.stopTest();

        System.assert(success, 'The request should be successfull (no exceptions)');
    }

    static testMethod void setTargetInstanceAuthInfo_noAuthExists() {
        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();

        Instances__c instance = TestingUtils.createInstance('dev');
        Release__c release = new Release__c(Name='v1');
        insert release;

        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id, 0, 0, 0, false);

        Test.startTest();
            try {
                DeploymentRequest request = new DeploymentRequest(new Build__c(), attempt);
                System.assert(false, 'Creating a deployment request when an auth user does not exist for an instance and user should throw an exception');
            } catch (Exception ae) {
                System.assert(ae instanceof ALMException, 'Creating a deployment request when an auth user does not exist for an instance and user should throw an ALM exception');
                System.assert(ae.getMessage().startsWith(System.Label.Generic_Error), 'Creating a deployment request when an auth user does not exist for an instance and user should throw an ALM exception');
            }
        Test.stopTest();
    }

    static testMethod void setTargetInstanceAuthInfo() {
        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();

        Instances__c instance = TestingUtils.createInstance('dev');
        Release__c release = new Release__c(Name='v1');
        insert release;

        User otherUser = TestingUtils.createUser([SELECT Id FROM Profile WHERE Name = :TestingUtils.SYSADMIN_PROFILE_NAME].Id);

        Auth_User__c authUser;
        Deployment_Attempt__c attempt;

        System.runAs(otherUser) {
            authUser = TestingUtils.createAuthUser(otherUser.Id, instance.Id);
            attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id, 0, 0, 0, false);
        }

        Test.startTest();
            DeploymentRequest request = new DeploymentRequest(new Build__c(), attempt);
        Test.stopTest();

        System.assertEquals(authUser.Refresh_Token__c, request.targetInstance.get('refreshToken'), 'The refresh token should be set on the target from the user who created the deployment');
    }

    static testMethod void setTargetInstanceAuthInfo_authUserIsForTools() {
        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();

        Instances__c testInstance = TestingUtils.createInstance('Test Instance');
        Release__c testRelease = new Release__c(Name = 'Test Release');
        insert testRelease;

        TestingUtils.createAuthUser(UserInfo.getUserId(), testInstance.Id, true);
        Deployment_Attempt__c testAttempt = TestingUtils.createDeploymentAttempt(testRelease.Id, testInstance.Id, 0, 0, 0, false);

        Test.startTest();

            try {
                new DeploymentRequest(new Build__c(), testAttempt);

                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains('No Auth User found for instance'), 'The proper exception should be thrown.');
            }

        Test.stopTest();
    }

    static testMethod void setTargetInstanceAuthInfo_authUserIsNotForTools() {
        String testInstanceURL = 'https://www.example.com';
        String testRefreshToken = 'Test Refresh Token';

        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();

        Instances__c testInstance = TestingUtils.createInstance('Test Instance');
        Release__c testRelease = new Release__c(Name = 'Test Release');
        insert testRelease;

        Auth_User__c testAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), testInstance.Id, false);
        testAuthUser.Instance_URL__c = testInstanceURL;
        testAuthUser.Refresh_Token__c = testRefreshToken;
        update testAuthUser;

        Auth_User__c otherAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), testInstance.Id, true);
        otherAuthUser.Instance_URL__c = 'https://www.wrong.com';
        otherAuthUser.Refresh_Token__c = 'Some Wrong Refresh Token';
        update otherAuthUser;

        Test.startTest();

            DeploymentRequest actualDeploymentRequest;
            try {
                actualDeploymentRequest = new DeploymentRequest(new Build__c(), TestingUtils.createDeploymentAttempt(testRelease.Id, testInstance.Id, 0, 0, 0, false));
            } catch (Exception e) {
                System.assert(false, 'No exception should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(testInstanceURL, actualDeploymentRequest.targetInstance.get('serverURL'), 'The instance URL should match.');
        System.assertEquals(testRefreshToken, actualDeploymentRequest.targetInstance.get('refreshToken'), 'The refresh token should match.');
    }
}