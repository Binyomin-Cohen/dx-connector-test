@isTest
private class TestBuildTrigger {

    static testMethod void updateDeploymentWithCompletedBuild() {
        Release__c release = new Release__c(Name='Test release');
        insert release;

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_IN_PROGRESS);

        Deployment__c deployment = new Deployment__c(Name='Background Build');
        deployment.Build__c = build.Id;
        insert deployment;

        Test.startTest();

            build.Status__c = BuildServices.STATUS_SUCCESS;
            update build;

        Test.stopTest();

        Deployment__c updatedDeployment = [SELECT Id, Completed_Build__c FROM Deployment__c];

        System.assertEquals(build.Id, updatedDeployment.Completed_Build__c, 'The deployment should be updated with the completed build');
    }
}