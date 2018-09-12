@isTest
private class TestCIInstanceTrigger {

	private static final String TEST_JOB_PATH = 'test/job/path';
    private static final String TEST_JOB_TOKEN = 'test_job_token';
    
    static testMethod void testAutoStartValidJobs() {
    	Release__c release = new Release__c(Name='Test release');
        insert release;      
        
        Test.setMock(HttpCalloutMock.class, new MockJenkinsAPI(TEST_JOB_PATH, TEST_JOB_TOKEN));
        
        Instances__c Instances = TestingUtils.createInstance('TestTarget');
        CI_Instance__c ciInstance = new CI_Instance__c(Name ='Test Dev',Target_Instance__c = Instances.id, Release__c = release.id);
        insert ciInstance;
        
        Build_Rule__c bRule = new Build_Rule__c(Boolean_Criteria__c='Pre_Steps_Completed__c');
        insert bRule;

        VC_Repository__c vcRepo = new VC_Repository__c(Repository_URL__c = 'some-repo-URL' );
        insert vcRepo;
        
        Jenkins_Job__c jJob = new Jenkins_Job__c (
            Name='TestJob',
            path__c='job/JenkinsTestJob',
            Token__c='f7b94543c70b741nwwjw36498476ea66fdaab',
            CI_Instance__c=ciInstance.id,
            Release__c=release.id,
            Is_Validation__c=true,
            Build_Rule__c=bRule.Id,
            Trigger_Job_Automatically__c = true,
            Source_Repository_Location__c = 'some-branch-name',
             Source_Repository__c = vcRepo.Id
        );
        insert jJob;
                      
        Test.startTest();

            ciInstance.Pre_Steps_Completed__c = true;

            update ciInstance;
        
        Test.stopTest();  
        List<Jenkins_Build__c> builds = [SELECT Id from Jenkins_Build__c WHERE Jenkins_Job__c = : jJob.Id];
        System.assertEquals(builds.size(),1, 'Some Issue in creation of Jenkins Build object as part of start job automatically');
     
    }

}