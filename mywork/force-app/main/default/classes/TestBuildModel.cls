@isTest
private class TestBuildModel {
    
    static Release__c release;

    static void setup() {
        release = new Release__c(Name='Sprint 15');
        insert release;
    }
    static testMethod void testNullBuildRecord() {
        
        Test.startTest();
            BuildModel bModel = new BuildModel(null);
        Test.stopTest();
        
        System.assertNotEquals(null, bModel, 'We expect to get back a Build Model');
        System.assertEquals(null, bModel.record, 'We expect the build model record to be null.');
        System.assertEquals(null, bModel.buildStatus, 'We expect the build model status to be null.');
        System.assertEquals(null, bModel.webAssemblerFailureMessage, 'We expect the build model web assembler failure message to be null.');
        
    }
    
    static testMethod void testValidBuildRecord() {
        setup();
        
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        
        Test.startTest();
            BuildModel bModel = new BuildModel(build);
        Test.stopTest();
        
        System.assertNotEquals(null, bModel, 'We expect to get back a Build Model');
        System.assertNotEquals(null, bModel.record, 'We expect to get back a Build Model with the record populated.');
        System.assertEquals(build.Id, bModel.record.Id, 'We expect the build model record id to match input.');
        System.assertEquals(build.Status__c, bModel.buildStatus, 'We expect to get back the correct Build Status');
        System.assertEquals(null, bModel.webAssemblerFailureMessage, 'This build should NOT have a web assembler error message.');
        
    }
    
    static testMethod void testValidBuildRecord_withWebAssembleFailure() {
        setup();
        
        final String EXPECTED_WEB_ASSEMBLER_MSG = 'Web Assembler Failed.';
        
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        
        Deployment_Attempt__c deploymentAttempt = new Deployment_Attempt__c(
            Build__c = build.Id,
            Status__c = DeploymentServices.STATUS_SUCCESS,
            Assemble_Request_Error__c = EXPECTED_WEB_ASSEMBLER_MSG
        );
        insert deploymentAttempt;
        
        build = [Select Id, Status__c, (Select Id, Assemble_Request_Error__c From Deployment_Attempts__r) from Build__c
                    Where Id = :build.Id];
        
        Test.startTest();
            BuildModel bModel = new BuildModel(build);
        Test.stopTest();
        
        System.assertNotEquals(null, bModel, 'We expect to get back a Build Model');
        System.assertNotEquals(null, bModel.record, 'We expect to get back a Build Model with the record populated.');
        System.assertEquals(build.Id, bModel.record.Id, 'We expect the build model record id to match input.');
        System.assertEquals(build.Status__c, bModel.buildStatus, 'We expect to get back the correct Build Status');
        System.assertEquals(EXPECTED_WEB_ASSEMBLER_MSG, bModel.webAssemblerFailureMessage, 'This build should have a web assembler error message.');
        
    }
    
    static testMethod void testValidBuildRecord_withNoWebAssembleFailure() {
        setup();
        
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        
        Deployment_Attempt__c deploymentAttempt = new Deployment_Attempt__c(
            Build__c = build.Id,
            Status__c = DeploymentServices.STATUS_SUCCESS
        );
        insert deploymentAttempt;
        
        Test.startTest();
            BuildModel bModel = new BuildModel(build);
        Test.stopTest();
        
        System.assertNotEquals(null, bModel, 'We expect to get back a Build Model');
        System.assertNotEquals(null, bModel.record, 'We expect to get back a Build Model with the record populated.');
        System.assertEquals(build.Id, bModel.record.Id, 'We expect the build model record id to match input.');
        System.assertEquals(build.Status__c, bModel.buildStatus, 'We expect to get back the correct Build Status');
        System.assertEquals(null, bModel.webAssemblerFailureMessage, 'This build should NOT have a web assembler error message.');
        
    }
}