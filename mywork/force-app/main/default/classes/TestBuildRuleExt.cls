@isTest
private with sharing class TestBuildRuleExt {

    static Instances__c testInstance;
    static Release__c  testRelease;

    static final String VALID_FIELD_NAME = SObjectServices.getFullyQualifiedName('Pre_Steps_Completed__c');

    private static void setup() {
        testRelease = new Release__c(Name = 'Test Release Name');
        insert testRelease;

        testInstance = TestingUtils.createInstance('Test Instance Name');
    }

    private static testMethod void getAvailableOptions() {
        setup();
        Jenkins_Job__c job = TestingUtils.createJenkinsJob(testInstance.Id, testRelease.Id);

        Test.startTest();
            List<BuildRuleExt.Option> options = BuildRuleExt.getAvailableOptions(job.Id);
        Test.stopTest();

        Map<String, BuildRuleExt.Option> apiNameToOption = new Map<String, BuildRuleExt.Option>();

        for (BuildRuleExt.Option option : options) {
            apiNameToOption.put(option.value, option);
        }

        System.assertEquals(true, apiNameToOption.containsKey(VALID_FIELD_NAME),
            'The returned option list should contain the api name of the known checkbox field');

        System.assertEquals('Pre-Steps Completed', apiNameToOption.get(VALID_FIELD_NAME).label,
            'The returned list should contain the label of the known checkbox field');

        System.assertEquals(false, apiNameToOption.get(VALID_FIELD_NAME).isSelected,
            'The returned option list should mark the selected fields');

        System.assertEquals(false, apiNameToOption.containsKey('IsDeleted'),
            'Standard fields should not be returned');
    }

   private static testMethod void getAvailableOptions_markOptionSelected() {
        setup();
        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);
        Build_Rule__c rule = new Build_Rule__c();
        rule.Boolean_Criteria__c = VALID_FIELD_NAME;
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        Test.startTest();
            List<BuildRuleExt.Option> options = BuildRuleExt.getAvailableOptions(job.Id);
        Test.stopTest();

        Map<String, BuildRuleExt.Option> apiNameToOption = new Map<String, BuildRuleExt.Option>();

        for (BuildRuleExt.Option option : options) {
            apiNameToOption.put(option.value, option);
        }

        System.assertEquals(true, apiNameToOption.containsKey(VALID_FIELD_NAME),
            'The returned option list should contain the api name of the known checkbox field');

        System.assertEquals(true, apiNameToOption.get(VALID_FIELD_NAME).isSelected,
            'The returned option list should mark the selected fields');
    }

    private static testMethod void removeFromBuildRule_noMatchingValue() {
        setup();
        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);
        Build_Rule__c rule = new Build_Rule__c();
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        Test.startTest();
            BuildRuleExt.removeFromBuildRule(job.Id, VALID_FIELD_NAME);
        Test.stopTest();

        job = [SELECT Build_Rule__c, Build_Rule__r.Boolean_Criteria__c 
            FROM Jenkins_Job__c WHERE Id = :job.Id];
        
        System.assertEquals(rule.Id, job.Build_Rule__c,
             'The build rule should still be populated on the jenkins job');
        System.assertEquals(true, String.isEmpty(job.Build_Rule__r.Boolean_Criteria__c),
            'The build rule should be unchanged');
    }

    private static testMethod void removeFromBuildRule_singleExistingValue() {
        setup();
        Jenkins_Job__c job = TestingUtils.createJenkinsJob(testInstance.Id, testRelease.Id);
        Build_Rule__c rule = new Build_Rule__c();
        rule.Boolean_Criteria__c = VALID_FIELD_NAME;
        insert rule;

        job.Build_Rule__c = rule.Id;
        update job;

        Test.startTest();
            BuildRuleExt.removeFromBuildRule(job.Id, VALID_FIELD_NAME);
        Test.stopTest();

        job = [SELECT Build_Rule__c, Build_Rule__r.Boolean_Criteria__c 
            FROM Jenkins_Job__c WHERE Id = :job.Id];
        
        System.assertEquals(rule.Id, job.Build_Rule__c,
             'The build rule should still be populated on the jenkins job');
        System.assertEquals(true, String.isEmpty(job.Build_Rule__r.Boolean_Criteria__c),
            'The build rule should have the selected criteria removed');
    }

    private static testMethod void removeFromBuildRule_multipleExistingValues() {
        setup();

        final String OTHER_FIELD_NAME = 'some_other_field__c';

        Jenkins_Job__c job = TestingUtils.createJenkinsJob(testInstance.Id, testRelease.Id);
        Build_Rule__c rule = new Build_Rule__c();
        rule.Boolean_Criteria__c = VALID_FIELD_NAME + BuildRuleExt.CRITERIA_DELIMITER + OTHER_FIELD_NAME;
        insert rule;

        job.Build_Rule__c = rule.Id;
        update job;

        Test.startTest();
            BuildRuleExt.removeFromBuildRule(job.Id, VALID_FIELD_NAME);
        Test.stopTest();

        job = [SELECT Build_Rule__c, Build_Rule__r.Boolean_Criteria__c 
            FROM Jenkins_Job__c WHERE Id = :job.Id];
        
        System.assertEquals(rule.Id, job.Build_Rule__c,
             'The build rule should still be populated on the jenkins job');
        System.assertEquals(OTHER_FIELD_NAME, job.Build_Rule__r.Boolean_Criteria__c,
            'The build rule should have the selected criteria removed');
    }

    private static testMethod void saveBuildRule_newBuildRule() {
        setup();
        Jenkins_Job__c job = TestingUtils.createJenkinsJob(testInstance.Id, testRelease.Id);

        final String EXPECTED_FIELD = VALID_FIELD_NAME;

        Test.startTest();
            BuildRuleExt.saveBuildRule(job.Id, EXPECTED_FIELD);
        Test.stopTest();

        job = [SELECT Build_Rule__c, Build_Rule__r.Boolean_Criteria__c 
            FROM Jenkins_Job__c WHERE Id = :job.Id];
        
        System.assertNotEquals(null, job.Build_Rule__c,
             'A build rule should be created and populated on the Jenkins Job');
        System.assertEquals(EXPECTED_FIELD, job.Build_Rule__r.Boolean_Criteria__c,
            'The build rule should be populated with the expected criteria');
    }

    private static testMethod void saveBuildRule_existingBuildRule() {
        setup();

        final String EXPECTED_FIELD = VALID_FIELD_NAME;
        final String EXISTING_FIELD = 'Existing_Field__c';

        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);
        Build_Rule__c rule = new Build_Rule__c(Boolean_Criteria__c=EXISTING_FIELD);
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        Test.startTest();
            BuildRuleExt.saveBuildRule(job.Id, EXPECTED_FIELD);
        Test.stopTest();

        job = [SELECT Build_Rule__c, Build_Rule__r.Boolean_Criteria__c 
            FROM Jenkins_Job__c WHERE Id = :job.Id];
        
        System.assertEquals(rule.Id, job.Build_Rule__c, 'The build rule lookup should not be updated');
        System.assertEquals(EXISTING_FIELD + BuildRuleExt.CRITERIA_DELIMITER + EXPECTED_FIELD, job.Build_Rule__r.Boolean_Criteria__c,
            'The build rule should be populated with the expected criteria');
    }

    private static testMethod void saveBuildRule_existingBuildRule_withNoCriteria() {
        setup();

        final String EXPECTED_FIELD = VALID_FIELD_NAME;

        Jenkins_Job__c job = TestingUtils.buildJenkinsJob(testInstance.Id, testRelease.Id);
        Build_Rule__c rule = new Build_Rule__c();
        insert rule;

        job.Build_Rule__c = rule.Id;
        insert job;

        Test.startTest();
            BuildRuleExt.saveBuildRule(job.Id, EXPECTED_FIELD);
        Test.stopTest();

        job = [SELECT Build_Rule__c, Build_Rule__r.Boolean_Criteria__c 
            FROM Jenkins_Job__c WHERE Id = :job.Id];
        
        System.assertEquals(rule.Id, job.Build_Rule__c, 'The build rule lookup should not be updated');
        System.assertEquals(EXPECTED_FIELD, job.Build_Rule__r.Boolean_Criteria__c,
            'The build rule should be populated with the expected criteria');
    }

    private static testMethod void saveBuildRule_invalidField_throwsException() {
        setup();
        Jenkins_Job__c job = TestingUtils.createJenkinsJob(testInstance.Id, testRelease.Id);

        final String INVALID_FIELD = 'itz_no_good';
        
        Test.startTest();
            try {
                BuildRuleExt.saveBuildRule(job.Id, INVALID_FIELD);
                System.assert(false, 'An exception should be thrown');
            } catch(Exception ae) {
                System.assert(ae instanceof AuraHandledException, 'An Aura handled exception should be thrown.');
            }
            
        Test.stopTest();
    }
}