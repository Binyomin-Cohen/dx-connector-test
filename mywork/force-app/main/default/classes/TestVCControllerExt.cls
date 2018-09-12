@isTest
private class TestVCControllerExt {
    private static final String TEST_REPOSITORY_URL = 'https://www.example.com/test-repository';
    private static final String TEST_REPOSITORY_HOST = 'GitHub';
    private static final String TEST_REPOSITORY_ORG_NAME = 'test-repository';
    private static VC_Repository__c testRepo;
    static {
        testRepo = TestingUtils.createVcRepository('git-repo', TEST_REPOSITORY_URL, TEST_REPOSITORY_HOST, TEST_REPOSITORY_ORG_NAME);
    }
    static testMethod void loadVCValidationsForUser_recordsFound() {
        DateTime currentTime = DateTime.Now();
        VC_Repository_Validation__c testValidationAttempt;
        //Create a validation attempt for the current user
        System.runAs(TestingUtils.ADMIN_USER){
            Boolean doInsert = false;
            testValidationAttempt = TestingUtils.createVcRepositoryValidation(testRepo, doInsert);
            testValidationAttempt.ValidationDate__c = currentTime;
            testValidationAttempt.SuccessfulValidation__c = true;
            insert testValidationAttempt;
        }

        List<VCRepository> actualReposWithValidations = new List<VCRepository>();
        Test.startTest();
            System.runAs(TestingUtils.ADMIN_USER){
                actualReposWithValidations = VCControllerExt.loadVCReposWithValidationsForUser();
            }
        Test.stopTest();

        System.assertEquals(1, actualReposWithValidations.size(),'One validation attempt, grouped by repo, should exist');
        VCRepository actualRepoRecord = actualReposWithValidations[0];
        System.assertEquals(testRepo.Id, actualRepoRecord.id, 'One validation attempt should exist for this repo');
        System.assertNotEquals(null, actualRepoRecord.validation, 'A validation record should exist for this repo');

        System.assertEquals(testValidationAttempt.ValidationDate__c, actualRepoRecord.validation.validationDate,
            'The validation date should be populated on the validation');
        System.assertEquals(testValidationAttempt.SuccessfulValidation__c, actualRepoRecord.validation.isSuccessful,
            'The successful validation field should be populated on the validation');
        System.assertEquals(testValidationAttempt.ValidationError__c, actualRepoRecord.validation.error,
            'The error field should be populated on the validation');
        System.assertEquals(testValidationAttempt.VC_Repository__c, actualRepoRecord.Id,
             'The repo validation repo id should match the repo id');
        System.assertEquals(testValidationAttempt.ExternalID__c, actualRepoRecord.validation.externalId,
             'The repo validation external id field should be populated');
    }

    static testMethod void loadVCValidationsForUser_noRecordsFound() {
        List<VCRepository> actualReposWithValidations = new List<VCRepository>();
        Test.startTest();
            System.runAs(TestingUtils.ADMIN_USER){
                actualReposWithValidations = VCControllerExt.loadVCReposWithValidationsForUser();
            }
        Test.stopTest();
        System.assertEquals(1, actualReposWithValidations.size(),'One repo should be found for the current user');
        System.assertEquals(null, actualReposWithValidations[0].validation, 'No validations should be found for the current user');
    }
}