@isTest
private class TestInstanceTrigger {
    static testMethod void scheduleComponentCleaningForDeletedInstances_deletionDetected() {
        TestingUtils.deleteExistingJobs(new List<String>{
            ComponentSourceInstanceCleaner.SOURCE_INSTANCE_CLEANER_NAME
        });

        final String ACTIVE_INSTANCE_NAME = 'testActive1';
        final String ACTIVE_INSTANCE_NAME_2 = 'testActive2';
        final String DELETED_INSTANCE_NAME = 'test2';

        Instances__c activeInstance = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME);
        Instances__c activeInstance2 = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME_2);
        Instances__c deletedInstance = TestingUtils.createInstance(DELETED_INSTANCE_NAME);
        List<Instances__c> allInstances = new List<Instances__c>{activeInstance, activeInstance2, deletedInstance};

        activeInstance.Name = 'updatedName';
        activeInstance2.Is_Deleted__c = false;
        deletedInstance.Is_Deleted__c = true;

        Test.startTest();
            update allInstances;

            List<CronTrigger> actualScheduledCleaningJobs = [
                SELECT NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name = :ComponentSourceInstanceCleaner.SOURCE_INSTANCE_CLEANER_NAME
            ];
            System.assertEquals(1, actualScheduledCleaningJobs.size(), 'A single matching job should be scheduled.');
        Test.stopTest();
    }

    static testMethod void scheduleComponentCleaningForDeletedInstances_noDeletionDetected() {
        TestingUtils.deleteExistingJobs(new List<String>{
            ComponentSourceInstanceCleaner.SOURCE_INSTANCE_CLEANER_NAME
        });

        final String ACTIVE_INSTANCE_NAME = 'testActive1';
        final String ACTIVE_INSTANCE_NAME_2 = 'testActive2';
        final String DELETED_INSTANCE_NAME = 'test2';

        Instances__c activeInstance = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME);
        Instances__c activeInstance2 = TestingUtils.createInstance(ACTIVE_INSTANCE_NAME_2);
        List<Instances__c> allInstances = new List<Instances__c>{activeInstance, activeInstance2};

        activeInstance.Name = 'updatedName';
        activeInstance2.Is_Deleted__c = false;

        Test.startTest();
            update allInstances;
            List<CronTrigger> actualScheduledCleaningJobs = [
                SELECT NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name = :ComponentSourceInstanceCleaner.SOURCE_INSTANCE_CLEANER_NAME
            ];
            System.assertEquals(0, actualScheduledCleaningJobs.size(), 'No matching job should be scheduled.');
        Test.stopTest();

    }
}
