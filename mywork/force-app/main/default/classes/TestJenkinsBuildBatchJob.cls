/**
* @author Vivek
* @date 8th Sep, 2017
*
* @group <Salesforce Garage>
*
* @description Test class for JenkinsBuildBatchJob
*/

@isTest
private class TestJenkinsBuildBatchJob {
    
    private static Release__c testRelease;
    private static Instances__c testInstance;
    private static Jenkins_Job__c jenkinsJob;
    private static CI_Instance__c ciInstance;
    private static String CRON_EXP = '0 0 0 15 3 ? 2022';
    private static final String TEST_ENDPOINT = 'http://www.example.com';
    private static final String TEST_USER_ID = 'TestUserID';
    private static final String TEST_USER_API_TOKEN = 'test_user_api_token';
    private static final String TEST_JOB_PATH = 'test/job/path';
    private static final String TEST_JOB_TOKEN = 'test_job_token';
    private static Jenkins_Config__c jenkinsConfig;
   
    /**
    Create custom setting data to be used for authorization in test class 
    **/
    private static void setupJenkinsConfig() {
        jenkinsConfig = new Jenkins_Config__c(
            Endpoint__c = TEST_ENDPOINT,
            User_ID__c = TEST_USER_ID,
            User_API_Token__c = TEST_USER_API_TOKEN
        );
        insert jenkinsConfig;
    }
    
    /**
    Create setup data to be used in test class 
    **/
    private static void setup() {
        testRelease = new Release__c(Name = 'Test Release Name');
        insert testRelease;

        testInstance = TestingUtils.createInstance('Test Instance Name');
        ciInstance = new CI_Instance__c(Name='test', Target_Instance__c = testInstance.Id, Release__c = testRelease.Id);
        insert ciInstance;

        jenkinsJob = new Jenkins_Job__c(
           Path__c = 'job/JenkinsTestJob',
           Token__c = 'f7b94543c70b741nwwjw36498476ea66fdaab',
           CI_Instance__c = ciInstance.Id
        );
        insert jenkinsJob;
    }
    
    /**
    Test Method for Success Response from jenkins
    **/
    static testMethod void testJenkinsBuildStatusSuccess(){
       setup();
       setupJenkinsConfig();
        
       Jenkins_Build__c jb= new Jenkins_Build__c();
       jb.Jenkins_Job__c=jenkinsJob.Id;
       jb.Status__c='PENDING';
       jb.CI_Instance__c=ciInstance.Id;
       insert jb;
       
       Test.startTest();
       Test.setMock(HttpCalloutMock.class, new MockJenkinsAPI('SUCCESS'));
       JenkinsBuildBatchJob b = new JenkinsBuildBatchJob();
       Database.executeBatch(b);
       Test.stopTest();   
       Jenkins_Build__c j=[Select id, Status__c from Jenkins_Build__c where id=:jb.Id Limit 1];
       System.assertEquals(j.Status__c,'SUCCESS','The Jenkins build status should be set to SUCCESS');
    }
    
    /**
    Test Method for Failure Response from jenkins
    **/
    static testMethod void testJenkinsBuildStatusFailure(){
       setup();
       setupJenkinsConfig();
        
       Jenkins_Build__c jb= new Jenkins_Build__c();
       jb.Jenkins_Job__c=jenkinsJob.Id;
       jb.Status__c='PENDING';
       jb.CI_Instance__c=ciInstance.Id;
       insert jb;
       
       Test.startTest();
       Test.setMock(HttpCalloutMock.class, new MockJenkinsAPI('FAILURE'));
       JenkinsBuildBatchJob b = new JenkinsBuildBatchJob();
       Database.executeBatch(b);
       Test.stopTest();   
       Jenkins_Build__c j=[Select id, Status__c from Jenkins_Build__c where id=:jb.Id Limit 1];
       System.assertEquals(j.Status__c,'FAILURE','The Jenkins build status should be set to FAILURE');
    }
}