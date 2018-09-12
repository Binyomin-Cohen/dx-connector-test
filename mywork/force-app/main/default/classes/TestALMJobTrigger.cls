@isTest
private class TestALMJobTrigger {

    @isTest
    static void updateMailToOnNonCompletedResults() {
        String SUCCESS = 'Success';
        String RUNNING = 'Running';
        String QUEUED = 'Queued';
        
        ALM_Job__c job = new ALM_Job__c(Status__c=QUEUED);
        insert job;
        
        ALM_Application_Result__c completedResult = new ALM_Application_Result__c(ALM_Job__c=job.Id, Result__c=SUCCESS);
        ALM_Application_Result__c runningResult = new ALM_Application_Result__c(ALM_Job__c=job.Id, Result__c=RUNNING);
        ALM_Application_Result__c queuedResult = new ALM_Application_Result__c(ALM_Job__c=job.Id, Result__c=QUEUED);
        
        insert new List<ALM_Application_Result__c> {completedResult, runningResult, queuedResult};
        
        String NEW_EMAIL = 'foo@bar.com';
        
        Test.startTest();
            job.Mail_To__c = NEW_EMAIL;
            update job;
        Test.stopTest();
        
        List<ALM_Application_Result__c> results = [SELECT Result__c, Mail_To__c 
                                                   FROM ALM_Application_Result__c 
                                                   WHERE ALM_Job__c=:job.Id];
        
        for (ALM_Application_Result__c result : results) {
            String expectedEmail = NEW_EMAIL;
            if (result.Result__c == SUCCESS) {
                expectedEmail = null;
            }
            System.assertEquals(expectedEmail, result.Mail_To__c, 
                'The email address on the ALM Job record should be copied to the ALM Application Result ' + 
                'record when the result record is Running or Queued');
        }
    }
}