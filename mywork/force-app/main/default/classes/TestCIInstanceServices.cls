@isTest
private class TestCIInstanceServices {
    
    private static final String TEST_JOB_PATH = 'test/job/path';
    private static final String TEST_JOB_TOKEN = 'test_job_token';
    /**
    * Test method to check auto start job for the matched build rule
    */ 
    static testMethod void testStartJobOfMatchedBuildRule() {
            
        Test.setMock(HttpCalloutMock.class, new MockJenkinsAPI(TEST_JOB_PATH, TEST_JOB_TOKEN));
        CI_Instance__c ciInstance = [SELECT Id from CI_Instance__c where Name ='Test Dev' LIMIT 1];
                      
        Test.startTest(); 
        String ruleValues = fetchFields(); 
        if(ruleValues  != null){
            for(string rule : ruleValues.split(';')){
                ciInstance.put(rule, true);    
            }            
            update ciInstance;
        }

        Test.stopTest();
        Jenkins_job__c jJob = [SELECT Id from Jenkins_job__c WHERE Name ='TestJob' LIMIT 1];   
        List<Jenkins_Build__c> builds = [SELECT Id from Jenkins_Build__c WHERE Jenkins_Job__c = : jJob.Id];
        System.assertEquals(builds.size(),1,'Some Issue in creation of Jenkins Build object as part of start job automatically');    
    }

    /**
    * Test method to check start valid job method for the matched build rule
    */     
    static testMethod void testExecuteValidJobOfMatchedBuildRule(){
        Test.setMock(HttpCalloutMock.class, new MockJenkinsAPI(TEST_JOB_PATH, TEST_JOB_TOKEN));
        
        Test.startTest();
            Jenkins_job__c jJob = [SELECT Id , Build_Rule__r.Boolean_Criteria__c , Build_Rule__c, CI_Instance__c from Jenkins_job__c WHERE Name = 'TestJob' LIMIT 1];    
            CI_Instance__c ciInstance = [SELECT Id from CI_Instance__c where Name ='Test Dev' LIMIT 1];
            String ruleValues = fetchFields(); 
            if (ruleValues  != null){
                for (string rule : ruleValues.split(';')) {
                    ciInstance.put(rule, true);    
                }            
                update ciInstance;
            }
            CIInstanceServices.executeValidJob(jJob);
        
        Test.stopTest();
        
        List<Jenkins_Build__c> builds = [SELECT Id from Jenkins_Build__c WHERE Jenkins_Job__c = : jJob.Id LIMIT 1];
        System.assertEquals(builds.size(),1,'Some Issue in creation of Jenkins Build object as part of start job automatically');
        
        
    }
    
    /**
    * Test method to check it does not auto start job for the unmatched build rule
    */ 
    static testMethod void testUnMatchedBuildRuleCriteria() {
        CI_Instance__c ciInstance = [SELECT Id from CI_Instance__c where Name ='Test Dev'];
        Test.startTest();
        String ruleValues = fetchFields();
        if(ruleValues  != null){
            for(string rule : ruleValues.split(';')){
                ciInstance.put(rule, false);                
        
            }            
            update ciInstance;
         }
        Test.stopTest();  
        Jenkins_job__c jJob = [SELECT Id from Jenkins_job__c WHERE Name ='TestJob' LIMIT 1];   
        List<Jenkins_Build__c> builds = [SELECT Id from Jenkins_Build__c WHERE Jenkins_Job__c = : jJob.Id];
        System.assertEquals(builds.size(),0, 'Unmatched rule criteria so it should not create jenkins build object');     
    }
    
    private static String fetchFields(){
        String SobjectApiName = SObjectServices.getFullyQualifiedName('CI_Instance__c');        
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map<String, Schema.SObjectField> fieldMap = schemaMap.get(SobjectApiName).getDescribe().fields.getMap();
        String commaSepratedFields = '';
        
        for (Schema.SObjectField field : FieldMap.values()) {
            Schema.DescribeFieldResult descField = field.getDescribe();
            if(descField.isAccessible() 
                && Schema.DisplayType.Boolean == descField.getType()
                && descField.getName().contains('__c')){
                if(commaSepratedFields == null || commaSepratedFields == ''){
                    commaSepratedFields = descField.getName();
                }else{
                    commaSepratedFields = commaSepratedFields + ';' + descField.getName();
                }
            }
        }
        
        return commaSepratedFields;
    }
    
     @testSetup 
     static void setup() {
        Release__c release = new Release__c(Name='Test release');
        insert release;  
        
        Instances__c Instances = TestingUtils.createInstance('TestTarget');
        CI_Instance__c ciInstance = new CI_Instance__c(Name ='Test Dev',Target_Instance__c = Instances.id, Release__c = release.id);
        insert ciInstance;
        String ruleValues = fetchFields();
        Build_Rule__c bRule = new Build_Rule__c(Boolean_Criteria__c=ruleValues );
        insert bRule;

        VC_Repository__c vcRepo = new VC_Repository__c(Repository_URL__c = 'some-repo-URL' );
        insert vcRepo;

        Jenkins_Job__c jJob = new Jenkins_Job__c (Name='TestJob',
            Path__c='job/JenkinsTestJob',
            Token__c='f7b94543c70b741nwwjw36498476ea66fdaab',
            CI_Instance__c=ciInstance.id,
            Release__c=release.id,
            Is_Validation__c=true,
            Build_Rule__c=bRule.Id,
            Trigger_Job_Automatically__c = true,
            Source_Repository_Location__c = 'some-branch-name',
            Source_Repository__c = vcRepo.Id);
        insert jJob;
     }

}