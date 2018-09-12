@isTest
private class TestALMErrorServices {
    static Deployment_Attempt__c deployment;

    static void setup() {
        deployment = new Deployment_Attempt__c();
        insert deployment;
    }

    static testMethod void getApexErrors() {
        setup();

        Schema.RecordTypeInfo info = ALM_Error__c.sObjectType.getDescribe().getRecordTypeInfosByName().get(ALMErrorServices.APEX_RECORD_TYPE);
        String recordTypeId = info.getRecordTypeId();

        ALM_Error__c error = new ALM_Error__c(Deployment_Attempt__c=deployment.Id, RecordTypeId=recordTypeId);
        insert error;

        Test.startTest();
            List<ALM_Error__c> results = ALMErrorServices.getApexErrors(deployment.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'All errors with Apex record type should be returned.');
    }


    static testMethod void getComponentErrors_Component() {
        setup();

        Schema.RecordTypeInfo info = ALM_Error__c.sObjectType.getDescribe().getRecordTypeInfosByName().get(ALMErrorServices.COMPONENT_RECORD_TYPE);
        String recordTypeId = info.getRecordTypeId();

        ALM_Error__c error = new ALM_Error__c(Deployment_Attempt__c=deployment.Id, RecordTypeId=recordTypeId);
        insert error;

        Test.startTest();
            List<ALM_Error__c> results = ALMErrorServices.getComponentErrors(deployment.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'All errors with Component reocrd type should be returned.');
    }

    static testMethod void getErrorCountsByBuild() {

        Release__c release = new Release__c(Name='Number 7 release');
        insert release;
        Build__c build1 = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        Build__c build2 = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        ALM_Error__c error = new ALM_Error__c(Build__c=build1.Id);
        insert error;

        Test.startTest();
            Map<Id, Integer> errorCount = ALMErrorServices.getErrorCountsByBuild(new Set<Id>{build1.Id, build2.Id});
        Test.stopTest();

        System.assertEquals(1, errorCount.get(build1.Id), 'The error count should be recorded for the build with errors');
        System.assertEquals(false, errorCount.containsKey(build2.Id), 'The build without errors should not be in the results');
    }

    static testMethod void getComponentErrors_Other() {
        setup();

        Schema.RecordTypeInfo info = ALM_Error__c.sObjectType.getDescribe().getRecordTypeInfosByName().get(ALMErrorServices.OTHER_RECORD_TYPE);
        String recordTypeId = info.getRecordTypeId();

        ALM_Error__c error = new ALM_Error__c(Deployment_Attempt__c=deployment.Id, RecordTypeId=recordTypeId);
        insert error;

        Test.startTest();
            List<ALM_Error__c> results = ALMErrorServices.getComponentErrors(deployment.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'All errors with Other record type should be returned.');
    }

    static testMethod void getBuildErrors() {
        setup();

        Build__c build = new Build__c();
        insert build;

        Schema.RecordTypeInfo info = ALM_Error__c.sObjectType.getDescribe().getRecordTypeInfosByName().get(ALMErrorServices.COMPONENT_RECORD_TYPE);
        String recordTypeId = info.getRecordTypeId();

        ALM_Error__c error = new ALM_Error__c(Build__c=build.Id, RecordTypeId=recordTypeId);
        insert error;

        Test.startTest();
            List<ALM_Error__c> results = ALMErrorServices.getBuildErrors(build.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'All build errors should be returned.');
    }

    static testMethod void buildALMError() {
        String testRecordTypeId = ALM_Error__c.sObjectType.getDescribe().getRecordTypeInfosByName().get('Apex').getRecordTypeId();
        String testType = 'Test Type';
        String testDescription = 'Test Description';
        String testCause = 'Test Cause';

        Build__c build = new Build__c();
        insert build;

        Test.startTest();

            ALM_Error__c almError = ALMErrorServices.createALMError(testRecordTypeId, testType, build.Id, testDescription, testCause);

        Test.stopTest();

        System.assertNotEquals(null, almError, 'The ALM Error record should exist.');
        System.assertEquals(testRecordTypeId, almError.RecordTypeId, 'The record type IDs should match.');
        System.assertEquals(testType, almError.Type__c, 'The types should match.');
        System.assertEquals(build.Id, almError.Build__c, 'The build IDs should match.');
        System.assertEquals(testDescription, almError.Description__c, 'The descriptions should match.');
        System.assertEquals(testCause, almError.Error_Cause__c, 'The causes should match.');
    }

    static testMethod void createALMError() {
        String testRecordTypeId = ALM_Error__c.sObjectType.getDescribe().getRecordTypeInfosByName().get('Apex').getRecordTypeId();
        String testType = 'Test Type';
        String testDescription = 'Test Description';
        String testCause = 'Test Cause';

        Build__c build = new Build__c();
        insert build;

        Test.startTest();

            ALMErrorServices.createALMError(testRecordTypeId, testType, build.Id, testDescription, testCause);

        Test.stopTest();

        ALM_Error__c almError = [SELECT RecordTypeId, Type__c, Build__c, Description__c, Error_Cause__c FROM ALM_Error__c LIMIT 1][0];

        System.assertNotEquals(null, almError, 'The ALM Error record should exist.');
        System.assertEquals(testRecordTypeId, almError.RecordTypeId, 'The record type IDs should match.');
        System.assertEquals(testType, almError.Type__c, 'The types should match.');
        System.assertEquals(build.Id, almError.Build__c, 'The build IDs should match.');
        System.assertEquals(testDescription, almError.Description__c, 'The descriptions should match.');
        System.assertEquals(testCause, almError.Error_Cause__c, 'The causes should match.');
    }
    
    static testMethod void getCodeCoverageErrors() {
        setup();
        
        List<ALM_Error__c> errorRecords = new List<ALM_Error__c>();
        errorRecords.add(new ALM_Error__c(Deployment_Attempt__c=deployment.Id,
            RecordTypeId=ALMErrorServices.getCodeCoverageRecordTypeId()));
        errorRecords.add(new ALM_Error__c(Deployment_Attempt__c=deployment.Id,
            RecordTypeId=ALMErrorServices.getApexRecordTypeId()));
        
        insert errorRecords;

        Test.startTest();
            List<ALM_Error__c> results = ALMErrorServices.getCodeCoverageErrors(deployment.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'All errors with Code Coverage record type should be returned.');
        System.assertEquals(ALMErrorServices.getCodeCoverageRecordTypeId(),
            results.get(0).RecordTypeId, 'Errors with code coverage record type should be returned');
    }

    static testMethod void getDeploymentAttemptIdsToCodeCoverageErrorCounts() {
        setup();

        List<ALM_Error__c> errorRecords = new List<ALM_Error__c>();
        errorRecords.add(new ALM_Error__c(Deployment_Attempt__c=deployment.Id, 
            RecordTypeId=ALMErrorServices.getCodeCoverageRecordTypeId()));
        errorRecords.add(new ALM_Error__c(Deployment_Attempt__c=deployment.Id,
            RecordTypeId=ALMErrorServices.getApexRecordTypeId() ));
        
        insert errorRecords;

        Test.startTest();
            Map<Id, Integer> results = ALMErrorServices.getDeploymentAttemptIdsToCodeCoverageErrorCounts(new Set<Id>{deployment.Id});
        Test.stopTest();

        System.assertEquals(1, results.get(deployment.Id), 'All errors with Code Coverage record type should be returned.');
    }

    static testMethod void getValidationRuleMessage() {
        String CUSTOM_MESSAGE = 'The message the user supplied when creating validation rule'; 
        String msg = 'blablabla FIELD_CUSTOM_VALIDATION_EXCEPTION, ' + CUSTOM_MESSAGE + ': []';
        String parsedMsg = ALMErrorServices.getValidationRuleMessage(msg);
        String expectedMessage = System.Label.Custom_Validation_Rule_Error + ' ' + CUSTOM_MESSAGE;
        System.assertEquals(expectedMessage, parsedMsg, 'The message should be parsed properly');
    }
    
}