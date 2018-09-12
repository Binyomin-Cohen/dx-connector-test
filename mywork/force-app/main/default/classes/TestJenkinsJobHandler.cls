@isTest
private class TestJenkinsJobHandler {

     static testMethod void testExecuteDependentJenkinsJob() {
        Release__c release = new Release__c(Name='Test release');
        insert release;      
        
        Instances__c Instances = TestingUtils.createInstance('TestTarget');
        CI_Instance__c ciInstance = new CI_Instance__c(Name ='Test Dev',Target_Instance__c = Instances.id, Release__c = release.id);
        insert ciInstance;
        
        Build_Rule__c bRule = new Build_Rule__c(Boolean_Criteria__c='Pre_Steps_Completed__c;Trigger_Job_Automatically__c');
        insert bRule;
        
       
        Build_Rule__c bRule1 = new Build_Rule__c(Boolean_Criteria__c='Unit_Test_Done__c');
        insert bRule1;
        
        Jenkins_Job__c jJob1 = new Jenkins_Job__c (Name='TestJob',path__c='job/JenkinsTestJob',Token__c='f7b94543c70b741nwwjw36498476ea66fdaab',CI_Instance__c=ciInstance.id,Release__c=release.id,Is_Validation__c=true,Build_Rule__c=bRule1.Id);
        insert jJob1;
        
        Jenkins_Job__c jJob = new Jenkins_Job__c (Name='TestJob',path__c='job/JenkinsTestJob',Token__c='f7b94543c70b741nwwjw36498476ea66fdaab',CI_Instance__c=ciInstance.id,Release__c=release.id,Is_Validation__c=true,Build_Rule__c=bRule.Id
                                                    , Dependent_Jenkins_Job__c = jJob1.Id,  Last_Build_Status__c ='PENDING');
        insert jJob;
        
        Jenkins_Build__c jBuild = new Jenkins_Build__c(Jenkins_Job__c = jJob.Id, Status__c='PENDING');
        insert jBuild;
        
        List<Jenkins_Job__c> jobList = new List<Jenkins_Job__c>();
        jobList.add(jJob);        
              
        Test.startTest();
        jJob.Last_Build_Status__c = 'SUCCESS';
        update jJob;
       
        
        Test.stopTest();       
     }
}