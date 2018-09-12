@isTest
private class TestALMLogServices {

    static Exception getException() {
        try {
            throw new ALMException();
        } catch(Exception e) {
            return e;
        }
    }

    private static void setup() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.LOG_ACTION));
    }

    private static void deleteExistingJobs() {
        TestingUtils.deleteExistingJobs(new List<String>{ALMLogExportScheduler.SCHED_JOB_NAME});
    }

    static testMethod void export() {
        setup();

        ALMLogServices.error(getException(), ALMLogServices.Application.ADMIN_CONSOLE);
        ALMLogServices.error(getException(), ALMLogServices.Application.ADMIN_CONSOLE);
        List<Logged_Exception__c>  exceptions = [SELECT  CreatedDate FROM Logged_Exception__c];

        Test.startTest();
            ALMLogServices.export();
        Test.stopTest();

        System.assertEquals(exceptions[1].CreatedDate,  ALMSettings__c.getOrgDefaults().Last_Log_Export_Time__c, 'The last export time should be updated with the timestamp of the last error logged');
        System.assertEquals(2,  [SELECT count() FROM Logged_Exception__c], 'No new exceptions should be logged');
    }

    static testMethod void error_ensureExportIsScheduled() {
        setup();
        deleteExistingJobs();
        ALMLogExportScheduler.ALLOW_SCHEDULE_CREATION = true;

        Test.startTest();
            ALMLogServices.error(getException(), ALMLogServices.Application.ADMIN_CONSOLE);
        Test.stopTest();

        List<CronJobDetail> scheduledJobs = [
            SELECT Id
            FROM CronJobDetail
            WHERE Name IN (:ALMLogExportScheduler.SCHED_JOB_NAME)
        ];

        System.assertEquals(1, scheduledJobs.size(), 'Logging an error should ensure that the export job is scheduled');
    }

    static testMethod void error_existingSchedule_ensureExportScheduleNotDuplicated() {
        setup();
        deleteExistingJobs();
        ALMLogExportScheduler.ALLOW_SCHEDULE_CREATION = true;

        System.schedule(
            ALMLogExportScheduler.SCHED_JOB_NAME,
            ALMLogExportScheduler.SCHED_JOB_CRON_EXP,
            new ALMLogExportScheduler()
        );

        Test.startTest();
            ALMLogServices.error(getException(), ALMLogServices.Application.ADMIN_CONSOLE);
        Test.stopTest();

        List<CronJobDetail> scheduledJobs = [
            SELECT Id
            FROM CronJobDetail
            WHERE Name IN (:ALMLogExportScheduler.SCHED_JOB_NAME)
        ];

        System.assertEquals(1, scheduledJobs.size(), 'Scheduled job should only be scheduled once');
    }

    static testMethod void error() {
        setup();

        Test.startTest();
            ALMLogServices.error(getException(), ALMLogServices.Application.ADMIN_CONSOLE);
        Test.stopTest();

        List<Logged_Exception__c>  exceptions = [SELECT  Log_Level__c, Application__c FROM Logged_Exception__c];

        System.assertEquals(1, exceptions.size(), 'An exception should be logged');
        System.assertEquals('ADMIN_CONSOLE', exceptions[0].Application__c, 'The application should be logged');
        System.assertEquals('error', exceptions[0].Log_Level__c.toLowerCase(), 'The type should be set to ERROR');
    }

    static testMethod void warn() {
        setup();

        Test.startTest();
            ALMLogServices.warn(getException(), ALMLogServices.Application.ADMIN_CONSOLE);
        Test.stopTest();

        List<Logged_Exception__c>  exceptions = [SELECT  Log_Level__c, Application__c FROM Logged_Exception__c];

        System.assertEquals(1, exceptions.size(), 'An exception should be logged');
        System.assertEquals('ADMIN_CONSOLE', exceptions[0].Application__c, 'The application should be logged');
        System.assertEquals('warning', exceptions[0].Log_Level__c.toLowerCase(), 'The type should be set to warning');
    }
    
    static testMethod void errorAsync() {
        setup();
        
        Integer originalCount = [SELECT count() FROM AsyncApexJob Where JobType = 'Queueable'];
        
        Test.startTest();
            ALMLogServices.errorAsync(getException(), ALMLogServices.Application.ADMIN_CONSOLE);
            System.assertEquals(originalCount+1, [SELECT count() FROM AsyncApexJob Where JobType = 'Queueable'], 'We expect a queueable job to be created.');
        Test.stopTest();

        List<Logged_Exception__c>  exceptions = [SELECT  Log_Level__c, Application__c FROM Logged_Exception__c];

        System.assertEquals(1, exceptions.size(), 'An exception should be logged');
        System.assertEquals('ADMIN_CONSOLE', exceptions[0].Application__c, 'The application should be logged');
        System.assertEquals('error', exceptions[0].Log_Level__c.toLowerCase(), 'The type should be set to ERROR');
    }

    static testMethod void warnAsync() {
        setup();
        
        Integer originalCount = [SELECT count() FROM AsyncApexJob Where JobType = 'Queueable'];
        
        Test.startTest();
            ALMLogServices.warnAsync(getException(), ALMLogServices.Application.ADMIN_CONSOLE);
            System.assertEquals(originalCount+1, [SELECT count() FROM AsyncApexJob Where JobType = 'Queueable'], 'We expect a queueable job to be created.');
        Test.stopTest();

        List<Logged_Exception__c>  exceptions = [SELECT  Log_Level__c, Application__c FROM Logged_Exception__c];

        System.assertEquals(1, exceptions.size(), 'An exception should be logged');
        System.assertEquals('ADMIN_CONSOLE', exceptions[0].Application__c, 'The application should be logged');
        System.assertEquals('warning', exceptions[0].Log_Level__c.toLowerCase(), 'The type should be set to warning');
    }

}