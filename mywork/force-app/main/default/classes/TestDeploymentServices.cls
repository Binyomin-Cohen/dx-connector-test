@isTest
private class TestDeploymentServices {

    private static Release__c release;
    private static Instances__c instance;

    private static void setup() {
        release = new Release__c(Name='Test release');
        insert release;

        instance = new Instances__c(Name = 'dev');
        insert instance;
    }

    static testMethod void updateOngoingDeployments() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.GET_DEPLOYMENT_ACTION));

        setup();

        Build__c build = new Build__c(Release__c = release.Id);
        insert build;

        Deployment_Attempt__c deployment = new Deployment_Attempt__c(Build__c = build.Id);
        deployment.UUID__c = MockWebAssemblerAPI.JOB_ID;
        deployment.Status__c = 'Pending';
        insert deployment;

        Test.startTest();

            List<Deployment_Attempt__c> deployments = DeploymentServices.updateOngoingDeployments(build.Id);

        Test.stopTest();

        System.assertEquals(1, deployments.size(), 'The pending deployment should be treated as ongoing');

        Deployment_Attempt__c returnedDeployment = deployments[0];

        System.assertEquals(deployment.Id, returnedDeployment.Id, 'The created pending deployment should be returned');
        System.assertEquals(MockWebAssemblerAPI.JOB_ID, returnedDeployment.UUID__c, 'The UUID should remain unchanged');
        System.assertEquals(MockWebAssemblerAPI.DEPLOY_RESULT_SUCCESS_STATUS, returnedDeployment.Status__c, 'The status should be updated from the deployment status response');
        System.assertEquals(MockWebAssemblerAPI.COMPONENT_COUNT, returnedDeployment.Number_Components_Total__c, 'The Number_Components_Total__c should be set from the deployment status response');
        System.assertEquals(MockWebAssemblerAPI.COMPONENT_COUNT, returnedDeployment.Number_Components_Deployed__c, 'The Number_Components_Deployed__c should be set from deployment status response');

        Deployment_Attempt__c updatedDeployment = [SELECT Id, UUID__c, Status__c, Number_Components_Total__c, Number_Components_Deployed__c FROM Deployment_Attempt__c WHERE Id = :deployment.Id];

        System.assertEquals(MockWebAssemblerAPI.JOB_ID, updatedDeployment.UUID__c, 'The UUID should remain unchanged');
        System.assertEquals(MockWebAssemblerAPI.DEPLOY_RESULT_SUCCESS_STATUS, updatedDeployment.Status__c, 'The status should be updated from the deployment status response');
        System.assertEquals(MockWebAssemblerAPI.COMPONENT_COUNT, updatedDeployment.Number_Components_Total__c, 'The Number_Components_Total__c should be updated from the deployment status response');
        System.assertEquals(MockWebAssemblerAPI.COMPONENT_COUNT, updatedDeployment.Number_Components_Deployed__c, 'The Number_Components_Deployed__c should be updated from deployment status response');
    }

    static testMethod void startAttempts() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.DEPLOYMENTS_ACTION));
        TestingUtils.createOAuthSettings();
        TestingUtils.setupSightlineAuth();

        setup();

        Auth_User__c authUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        Build__c build =  TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Deployment_Attempt__c attempt = new Deployment_Attempt__c(Build__c = build.Id, Status__c = DeploymentServices.STATUS_NOT_STARTED);
        attempt.Target_Instance__c = instance.Id;
        insert attempt;

        Test.startTest();

            DeploymentServices.startAttempts(new Set<Id>{attempt.Id});

        Test.stopTest();

        Deployment_Attempt__c updatedAttempt = [SELECT Id, UUID__c, Status__c FROM Deployment_Attempt__c WHERE Id = :attempt.Id];
        System.assertEquals(MockWebAssemblerAPI.JOB_ID, updatedAttempt.UUID__c, 'The deploy job should be kicked off and the attempt record updated with the job Id');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, updatedAttempt.Status__c, 'The deploy job should be kicked off and the attempt record updated with the job Id');
    }

    static testMethod void startAttempts_failureCreatesAlmErrors() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_FAILURE_ACTION));

        setup();

        Build__c build =  TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Deployment_Attempt__c attempt = new Deployment_Attempt__c(Build__c = build.Id, Status__c = DeploymentServices.STATUS_NOT_STARTED);
        attempt.Target_Instance__c = instance.Id;
        insert attempt;

        Test.startTest();

            DeploymentServices.startAttempts(new Set<Id>{attempt.Id});

        Test.stopTest();

        Deployment_Attempt__c updatedAttempt = [SELECT Id, UUID__c, Status__c, Assemble_Request_Error__c FROM Deployment_Attempt__c WHERE Id = :attempt.Id];
        System.assertEquals(null, updatedAttempt.UUID__c, 'Failures when kicking off the deployment should result in a blank UUID');
        System.assertEquals(DeploymentServices.STATUS_FAILED, updatedAttempt.Status__c, 'The deployment attempt should be marked as a failure');
        System.assertNotEquals(null, updatedAttempt.Assemble_Request_Error__c, 'The deployment attempt should hold an assemble request error.');
    }

}