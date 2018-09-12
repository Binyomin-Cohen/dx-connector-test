@isTest
private class TestApplicationResultCleanerServices {
    private static final Integer SCHEDULE_ERROR_MARGIN = 1000;

    /*private static void setup() {
        TestingUtils.deleteExistingJobs(new List<String>{
            InstanceApplicationResultCleaner.CLEANER_NAME,
            VCRepoSyncApplicationResultCleaner.CLEANER_NAME
        });
    }

    private static testMethod void scheduleCleaning_allCleaners_defaultDelay_notAlreadyRunning() {
        setup();

        Test.startTest();

            DateTime now = DateTime.now();
            ApplicationResultCleanerServices.scheduleCleaning();
            List<CronTrigger> actualScheduledInstanceJobs = [
                SELECT NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name = :InstanceApplicationResultCleaner.CLEANER_NAME
            ];
            List<CronTrigger> actualScheduledVCRepoSyncJobs = [
                SELECT NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name = :VCRepoSyncApplicationResultCleaner.CLEANER_NAME
            ];

        Test.stopTest();

        System.assertEquals(1, actualScheduledInstanceJobs.size(), 'A single matching job should be scheduled.');
        System.assert(Math.abs(now.addMinutes(ApplicationResultCleanerServices.SCHEDULE_DELAY_DEFAULT).getTime() - (actualScheduledInstanceJobs[0].NextFireTime).getTime()) < SCHEDULE_ERROR_MARGIN, 'The matching job should be scheduled for the proper time.');

        System.assertEquals(1, actualScheduledVCRepoSyncJobs.size(), 'A single matching job should be scheduled.');
        System.assert(Math.abs(now.addMinutes(ApplicationResultCleanerServices.SCHEDULE_DELAY_DEFAULT).getTime() - (actualScheduledVCRepoSyncJobs[0].NextFireTime).getTime()) < SCHEDULE_ERROR_MARGIN, 'The matching job should be scheduled for the proper time.');
    }

    private static testMethod void scheduleCleaning_allCleaners_defaultDelay_alreadyRunning() {
        Integer existingDelay = 10;

        setup();

        DateTime nowInstanceApplicationResultCleaner = DateTime.now();
        System.scheduleBatch(new InstanceApplicationResultCleaner(), InstanceApplicationResultCleaner.CLEANER_NAME, existingDelay);
        DateTime nowVCRepoSyncApplicationResultCleaner = DateTime.now();
        System.scheduleBatch(new VCRepoSyncApplicationResultCleaner(), VCRepoSyncApplicationResultCleaner.CLEANER_NAME, existingDelay);

        System.assertEquals(2, [
            SELECT Count()
            FROM CronTrigger
            WHERE CronJobDetail.Name = :InstanceApplicationResultCleaner.CLEANER_NAME OR CronJobDetail.Name = :VCRepoSyncApplicationResultCleaner.CLEANER_NAME
        ], 'A single matching job should be scheduled.');

        Test.startTest();

            try {
                ApplicationResultCleanerServices.scheduleCleaning();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<CronTrigger> actualScheduledInstanceJobs = [
            SELECT NextFireTime
            FROM CronTrigger
            WHERE CronJobDetail.Name = :InstanceApplicationResultCleaner.CLEANER_NAME
        ];
        List<CronTrigger> actualScheduledVCRepoSyncJobs = [
            SELECT NextFireTime
            FROM CronTrigger
            WHERE CronJobDetail.Name = :VCRepoSyncApplicationResultCleaner.CLEANER_NAME
        ];

        System.assertEquals(1, actualScheduledInstanceJobs.size(), 'A single matching job should be scheduled.');
        System.assert(Math.abs(nowInstanceApplicationResultCleaner.addMinutes(existingDelay).getTime() - (actualScheduledInstanceJobs[0].NextFireTime).getTime()) < SCHEDULE_ERROR_MARGIN, 'The matching job should be scheduled for the proper time.');

        System.assertEquals(1, actualScheduledVCRepoSyncJobs.size(), 'A single matching job should be scheduled.');
        System.assert(Math.abs(nowVCRepoSyncApplicationResultCleaner.addMinutes(existingDelay).getTime() - (actualScheduledVCRepoSyncJobs[0].NextFireTime).getTime()) < SCHEDULE_ERROR_MARGIN, 'The matching job should be scheduled for the proper time.');
    }

    private static testMethod void scheduleCleaning_specificCleaners_defaultDelay_notAlreadyRunning() {
        setup();

        Test.startTest();

            DateTime now = DateTime.now();
            ApplicationResultCleanerServices.scheduleCleaning(new Set<ALMJobServices.ToolType>{ ALMJobServices.ToolType.SCAN, ALMJobServices.ToolType.AUTOMATED_TESTING });
            List<CronTrigger> actualScheduledJobs = [SELECT NextFireTime FROM CronTrigger WHERE CronJobDetail.Name = :InstanceApplicationResultCleaner.CLEANER_NAME];

        Test.stopTest();

        System.assertEquals(1, actualScheduledJobs.size(), 'A single matching job should be scheduled.');
        System.assert(Math.abs(now.addMinutes(ApplicationResultCleanerServices.SCHEDULE_DELAY_DEFAULT).getTime() - (actualScheduledJobs[0].NextFireTime).getTime()) < SCHEDULE_ERROR_MARGIN, 'The matching job should be scheduled for the proper time.');
    }

    private static testMethod void scheduleCleaning_specificCleaners_defaultDelay_alreadyRunning() {
        Integer existingDelay = 10;

        setup();

        DateTime now = DateTime.now();
        System.scheduleBatch(new InstanceApplicationResultCleaner(), InstanceApplicationResultCleaner.CLEANER_NAME, existingDelay);

        System.assertEquals(1, [SELECT Count() FROM CronTrigger WHERE CronJobDetail.Name = :InstanceApplicationResultCleaner.CLEANER_NAME], 'A single matching job should be scheduled.');

        Test.startTest();

            try {
                ApplicationResultCleanerServices.scheduleCleaning(new Set<ALMJobServices.ToolType>{ ALMJobServices.ToolType.SCAN, ALMJobServices.ToolType.AUTOMATED_TESTING });
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<CronTrigger> actualScheduledJobs = [SELECT NextFireTime FROM CronTrigger WHERE CronJobDetail.Name = :InstanceApplicationResultCleaner.CLEANER_NAME];
        System.assertEquals(1, actualScheduledJobs.size(), 'A single matching job should be scheduled.');
        System.assert(Math.abs(now.addMinutes(existingDelay).getTime() - (actualScheduledJobs[0].NextFireTime).getTime()) < SCHEDULE_ERROR_MARGIN, 'The matching job should be scheduled for the proper time.');
    }

    private static testMethod void scheduleCleaning_specificCleaners_customDelay_notAlreadyRunning() {
        Integer testDelay = 3;

        setup();

        Test.startTest();

            DateTime now = DateTime.now();
            ApplicationResultCleanerServices.scheduleCleaning(new Set<ALMJobServices.ToolType>{ ALMJobServices.ToolType.SCAN, ALMJobServices.ToolType.AUTOMATED_TESTING }, testDelay);
            List<CronTrigger> actualScheduledJobs = [SELECT NextFireTime FROM CronTrigger WHERE CronJobDetail.Name = :InstanceApplicationResultCleaner.CLEANER_NAME];

        Test.stopTest();

        System.assertEquals(1, actualScheduledJobs.size(), 'A single matching job should be scheduled.');
        System.assert(Math.abs(now.addMinutes(testDelay).getTime() - (actualScheduledJobs[0].NextFireTime).getTime()) < SCHEDULE_ERROR_MARGIN, 'The matching job should be scheduled for the proper time.');
    }

    private static testMethod void scheduleCleaning_specificCleaners_customDelay_alreadyRunning() {
        Integer existingDelay = 10;
        Integer testDelay = 3;

        setup();

        DateTime now = DateTime.now();
        System.scheduleBatch(new InstanceApplicationResultCleaner(), InstanceApplicationResultCleaner.CLEANER_NAME, existingDelay);

        System.assertEquals(1, [SELECT Count() FROM CronTrigger WHERE CronJobDetail.Name = :InstanceApplicationResultCleaner.CLEANER_NAME], 'A single matching job should be scheduled.');

        Test.startTest();

            try {
                ApplicationResultCleanerServices.scheduleCleaning(new Set<ALMJobServices.ToolType>{ ALMJobServices.ToolType.SCAN, ALMJobServices.ToolType.AUTOMATED_TESTING }, testDelay);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<CronTrigger> actualScheduledJobs = [SELECT NextFireTime FROM CronTrigger WHERE CronJobDetail.Name = :InstanceApplicationResultCleaner.CLEANER_NAME];
        System.assertEquals(1, actualScheduledJobs.size(), 'A single matching job should be scheduled.');
        System.assert(Math.abs(now.addMinutes(existingDelay).getTime() - (actualScheduledJobs[0].NextFireTime).getTime()) < SCHEDULE_ERROR_MARGIN, 'The matching job should be scheduled for the proper time.');
    }

    private static testMethod void executeCleaning_notAlreadyRunning() {
        System.assertEquals(0, [SELECT Count() FROM AsyncApexJob WHERE ApexClass.Name = 'InstanceApplicationResultCleaner'], 'No matching jobs should exist.');

        Test.startTest();

            ApplicationResultCleanerServices.executeCleaning(new Set<ALMJobServices.ToolType>{ ALMJobServices.ToolType.SCAN, ALMJobServices.ToolType.AUTOMATED_TESTING });

        Test.stopTest();

        System.assertEquals(1, [SELECT Count() FROM AsyncApexJob WHERE ApexClass.Name = 'InstanceApplicationResultCleaner'], 'A single matching job should exist.');
    }


    private static testMethod void executeCleaning_alreadyRunning() {
        System.assertEquals(0, [SELECT Count() FROM AsyncApexJob WHERE ApexClass.Name = 'InstanceApplicationResultCleaner'], 'No matching jobs should exist.');

        Database.executeBatch(new InstanceApplicationResultCleaner());

        System.assertEquals(1, [SELECT Count() FROM AsyncApexJob WHERE ApexClass.Name = 'InstanceApplicationResultCleaner'], 'A single matching job should exist.');

        Test.startTest();

            try {
                ApplicationResultCleanerServices.executeCleaning(new Set<ALMJobServices.ToolType>{ ALMJobServices.ToolType.SCAN, ALMJobServices.ToolType.AUTOMATED_TESTING });
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(1, [SELECT Count() FROM AsyncApexJob WHERE ApexClass.Name = 'InstanceApplicationResultCleaner'], 'A single matching job should exist.');
    }

    private static testMethod void isCleanerRunning_notRunning_noneRunning() {
        Test.startTest();

            Boolean isCleanerRunning = ApplicationResultCleanerServices.isCleanerRunning(ALMJobServices.ToolType.SCAN);

        Test.stopTest();

        System.assertEquals(false, isCleanerRunning, 'The batch should not be determined to be running.');
    }

    private static testMethod void isCleanerRunning_notRunning_otherRunning() {
        Test.startTest();

            Database.executeBatch(new VCRepoSyncApplicationResultCleaner());
            Boolean isCleanerRunning = ApplicationResultCleanerServices.isCleanerRunning(ALMJobServices.ToolType.SCAN);

        Test.stopTest();

        System.assertEquals(false, isCleanerRunning, 'The batch should not be determined to be running.');
    }

    private static testMethod void isCleanerRunning_running() {        
        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());
            Boolean isCleanerRunning = ApplicationResultCleanerServices.isCleanerRunning(ALMJobServices.ToolType.SCAN);

        Test.stopTest();

        System.assertEquals(true, isCleanerRunning, 'The batch should be determined to be running.');
    }

    private static testMethod void getRetentionBoundary_noCustomSetting() {
        Test.startTest();

            DateTime retentionBoundary = ApplicationResultCleanerServices.getRetentionBoundary();

        Test.stopTest();

        System.assertEquals(null, retentionBoundary, 'The retention boundary should be null.');
    }

    private static testMethod void getRetentionBoundary_customSetting_noRetentionValue() {
        insert new ALMSettings__c();

        Test.startTest();

            DateTime retentionBoundary = ApplicationResultCleanerServices.getRetentionBoundary();

        Test.stopTest();

        System.assertEquals(null, retentionBoundary, 'The retention boundary should be null.');
    }

    private static testMethod void getRetentionBoundary_customSetting_negativeRetentionValue() {
        Integer retentionValue = -3;

        insert new ALMSettings__c(Sync_History_Retention__c = retentionValue);
        
        Test.startTest();

            DateTime retentionBoundary = ApplicationResultCleanerServices.getRetentionBoundary();

        Test.stopTest();

        System.assertEquals(null, retentionBoundary, 'The retention boundary should be null.');
    }

    private static testMethod void getRetentionBoundary_customSetting_validRetentionValue() {
        Integer retentionValue = 5;

        insert new ALMSettings__c(Sync_History_Retention__c = retentionValue);
        
        Test.startTest();

            DateTime now = DateTime.now();
            DateTime retentionBoundary = ApplicationResultCleanerServices.getRetentionBoundary();

        Test.stopTest();

        System.assert(Math.abs((now.addDays(-1 * retentionValue)).getTime() - retentionBoundary.getTime()) < SCHEDULE_ERROR_MARGIN, 'The retention boundary should be set to the proper datetime.');
    }*/
}