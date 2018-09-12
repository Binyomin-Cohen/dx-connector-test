@isTest
private class TestExecuteTestMonitorBatch {
    static final Integer TEST_JOB_COUNT_SINGLE = 1;
    static final Integer TEST_JOB_COUNT_MULTIPLE = 4;
    static final String SCHEDULED_STATUS = SCANServices.TOOL_STATUS_SCHEDULED;
    static final String ON_HOLD_STATUS = SCANServices.TOOL_STATUS_ON_HOLD;
    static final String QUEUED_STATUS = SCANServices.TOOL_STATUS_QUEUED;

    static void basicSetup(Integer jobCount, Integer instanceCount) {
        Instances__c testSourceInstance = new Instances__c(Name='Test Source Instance');
        insert testSourceInstance;

        Auth_User__c testSourceAuth = TestingUtils.createAuthUser(UserInfo.getUserId(), testSourceInstance.Id, true);
        Auth_User__c testSightlineAuth = TestingUtils.setupSightlineAuth();

        TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });

        List<Instances__c> testInstances = new List<Instances__c>();
        List<ALM_Job__c> allTestJobs = new List<ALM_Job__c>();
        List<AsyncApexJob> allAsyncJobs = new List<AsyncApexJob>();

        for (Integer i = 0; i < jobCount; i++) {
            allTestJobs.add(TestingUtils.buildAlmJob(null, null, null, null));
            allAsyncJobs.add(new AsyncApexJob());
        }

        for (Integer i = 0; i < instanceCount; i++) {
            testInstances.add(TestingUtils.createInstance('Test Instance' + i));
        }

        UnitTest.addData(allTestJobs).tag('All Jobs');
        UnitTest.addData(allAsyncJobs).tag('All Async Jobs');
        UnitTest.addData(testInstances).tag('All Instances');
        UnitTest.get('All Async Jobs').dummyInsert();

        List<String>asyncJobIds = new List<String>();
        for (Id asyncId : UnitTest.getIds('All Async Jobs')) {
            asyncJobIds.add(asyncId);
        }

        for (Instances__c instance : testInstances) {
            TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id, true);
        }

        UnitTest.get('All Jobs')
        .property('Source_Instance__c').assignFrom('All Instances')
        .property('Tool__c').assign(ExecuteTestMonitorBatch.BUTR_TOOL_NAME)
        .property('Async_Apex_Job_Id__c').assignFrom('All Async Jobs')
        .property('Status__c').assign(ExecuteTestMonitorBatch.RUNNING_STATUS);

        UnitTest.get('All Jobs').insertAll();
        MockToolingAPIForBatch.EXPECTED_ASYNC_IDS = asyncJobIds;
        Test.setMock(HttpCalloutMock.class, new MockToolingAPIForBatch(ALMRestServices.HTTP_OK));
    }

    static testMethod void testRunBatchWithNoALMJobsRunning() {

        Test.setMock(HttpCalloutMock.class, new MockToolingAPIForBatch(ALMRestServices.HTTP_OK));

        TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });

        List<ALM_Job__c> allTestJobs = new List<ALM_Job__c>();

        for (Integer i = 0; i < TEST_JOB_COUNT_MULTIPLE; i++) {
            allTestJobs.add(TestingUtils.buildAlmJob(null, null, null, null));
        }

        UnitTest.addData(allTestJobs).tag('All Jobs');

        UnitTest.get('All Jobs')
        .divide(4)
        .part(ON_HOLD_STATUS)
        .part(QUEUED_STATUS)
        .part(SCHEDULED_STATUS)
        .part('Scan Job');

        UnitTest.get('All Jobs')
        .minus('Scan Job')
        .property('Tool__c').assign(ExecuteTestMonitorBatch.BUTR_TOOL_NAME);

        UnitTest.get(ON_HOLD_STATUS)
        .property('Status__c').assign(ON_HOLD_STATUS);

        UnitTest.get(QUEUED_STATUS)
        .property('Status__c').assign(QUEUED_STATUS);

        UnitTest.get(SCHEDULED_STATUS)
        .property('Status__c').assign(SCHEDULED_STATUS);

        UnitTest.get('Scan Job')
        .property('Status__c').assign(SCHEDULED_STATUS)
        .property('Tool__c').assign('Scan');

        //Adding to scheduled so that we can confirm the status doesnt change
        UnitTest.get('Scan Job').tag(SCHEDULED_STATUS);

        UnitTest.get('All Jobs').insertAll();

        Test.startTest();
            Database.executeBatch(new ExecuteTestMonitorBatch(), TEST_JOB_COUNT_SINGLE);
        Test.stopTest();

        List<ALM_Job__c> allResultingJobs = [Select Id, Status__c from ALM_Job__c];
        Map<String, List<ALM_Job__c>> jobsGroupedByStatus = GroupBy.Strings('Status__c', allResultingJobs);

        UnitTest.analyze('All Jobs').assertEquivalence(allResultingJobs,'No jobs should have been created or removed');

        List<ALM_Job__c>actualOnHoldJobs = jobsGroupedByStatus.get(ON_HOLD_STATUS);
        List<ALM_Job__c>actualPendingJobs = jobsGroupedByStatus.get(QUEUED_STATUS);
        List<ALM_Job__c>actualScheduledJobs = jobsGroupedByStatus.get(SCHEDULED_STATUS);

        System.assertNotEquals(null, actualPendingJobs, 'Pending jobs should be found');
        System.assertNotEquals(null, actualScheduledJobs, 'Scheduled jobs should be found');
        System.assertNotEquals(null, actualOnHoldJobs, 'On hold jobs should be found');
        System.assertEquals(0, MockToolingAPIForBatch.CALLOUT_COUNTER, 'No callouts should be made');

        UnitTest.analyze(ON_HOLD_STATUS).assertEquivalence(jobsGroupedByStatus.get(ON_HOLD_STATUS),'The on hold status should not have changed');
        UnitTest.analyze(QUEUED_STATUS).assertEquivalence(jobsGroupedByStatus.get(QUEUED_STATUS),'The queued status should not have changed');
        UnitTest.analyze(SCHEDULED_STATUS).assertEquivalence(jobsGroupedByStatus.get(SCHEDULED_STATUS),'The scheduled status should not have changed');
    }

    static testMethod void testRunBatchWithSomeALMJobsRunningFromOneInstance() {

        Test.setMock(HttpCalloutMock.class, new MockToolingAPIForBatch(ALMRestServices.HTTP_OK));
        Instances__c testSourceInstance = new Instances__c(Name='Test Source Instance');
        insert testSourceInstance;

        Auth_User__c testSourceAuth = TestingUtils.createAuthUser(UserInfo.getUserId(), testSourceInstance.Id, true);
        Auth_User__c testSightlineAuth = TestingUtils.setupSightlineAuth();

        TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });

        List<ALM_Job__c> allTestJobs = new List<ALM_Job__c>();

        for (Integer i = 0; i < TEST_JOB_COUNT_MULTIPLE; i++) {
            allTestJobs.add(TestingUtils.buildAlmJob(null, null, null, null));
        }

        UnitTest.addData(allTestJobs).tag('All Jobs');
        Instances__c testInstance = TestingUtils.createInstance('Test Instance');

        TestingUtils.createAuthUser(UserInfo.getUserId(), testInstance.Id, true);

        UnitTest.get('All Jobs')
        .property('Source_Instance__c').assign(testInstance.Id)
        .property('Tool__c').assign(ExecuteTestMonitorBatch.BUTR_TOOL_NAME);

        UnitTest.get('All Jobs')
        .divide(4)
        .part(ON_HOLD_STATUS)
        .part(QUEUED_STATUS)
        .part(ExecuteTestMonitorBatch.RUNNING_STATUS)
        .part(SCHEDULED_STATUS);

        UnitTest.get(ON_HOLD_STATUS)
        .property('Status__c').assign(ON_HOLD_STATUS);

        UnitTest.get(QUEUED_STATUS)
        .property('Status__c').assign(QUEUED_STATUS);

        UnitTest.get(SCHEDULED_STATUS)
        .property('Status__c').assign(SCHEDULED_STATUS);

        UnitTest.get(ExecuteTestMonitorBatch.RUNNING_STATUS)
        .property('Status__c').assign(ExecuteTestMonitorBatch.RUNNING_STATUS)
        .property('Async_Apex_Job_Id__c').assign(MockToolingAPI.RETURN_ASYNC_JOB_ID);

        UnitTest.get('All Jobs').insertAll();

        UnitTest.get(ExecuteTestMonitorBatch.RUNNING_STATUS).tag('Expected Scheduled');
        UnitTest.get(SCHEDULED_STATUS).tag('Expected Scheduled');

        Test.startTest();
            Database.executeBatch(new ExecuteTestMonitorBatch(), TEST_JOB_COUNT_SINGLE);
        Test.stopTest();

        List<ALM_Job__c> allResultingScheduledJobs = [Select Id, Status__c from ALM_Job__c where Status__c = :SCHEDULED_STATUS];
        UnitTest.analyze('Expected Scheduled').assertEquivalence(allResultingScheduledJobs,'The status of the running jobs should have changed to scheduled');
        System.assertEquals(3, MockToolingAPIForBatch.CALLOUT_COUNTER, 'The correct number of callouts should be made');
    }

    static testMethod void testRunBatchWithSomeALMJobsRunningJobsFromMultipleInstances() {
        final Integer NUM_INSTANCES = 2;

        basicSetup(TEST_JOB_COUNT_SINGLE, NUM_INSTANCES);

        Test.startTest();
            Database.executeBatch(new ExecuteTestMonitorBatch(), TEST_JOB_COUNT_SINGLE);
        Test.stopTest();

        List<ALM_Job__c> allResultingScheduledJobs = [Select Id, Status__c from ALM_Job__c where Status__c = :SCHEDULED_STATUS];
        UnitTest.analyze('All Jobs').assertEquivalence(allResultingScheduledJobs,'The status of the running jobs should have changed to scheduled');
        System.assertEquals(3, MockToolingAPIForBatch.CALLOUT_COUNTER, 'The correct number of callouts should be made');
    }

    static testMethod void testRunBatchWithSomeALMJobsRunningJobsFromMultipleInstances_bulk() {
        final Integer NUM_INSTANCES = 2;
        final Integer TEST_JOB_COUNT_BULK = 30;

        basicSetup(TEST_JOB_COUNT_BULK, NUM_INSTANCES);

        Test.startTest();
            Database.executeBatch(new ExecuteTestMonitorBatch(), TEST_JOB_COUNT_BULK);
        Test.stopTest();

        List<ALM_Job__c> allResultingScheduledJobs = [Select Id, Status__c from ALM_Job__c where Status__c = :SCHEDULED_STATUS];
        UnitTest.analyze('All Jobs').assertEquivalence(allResultingScheduledJobs,'The status of the running jobs should have changed to scheduled');
        System.assertEquals(6, MockToolingAPIForBatch.CALLOUT_COUNTER, 'The correct number of callouts should be made');
    }

    static testMethod void testBatchRepeatFunctionality() {
        DateTime scheduleTime = DateTime.now().addMinutes(1);
        final Integer NUM_INSTANCES = 2;

        basicSetup(TEST_JOB_COUNT_SINGLE, NUM_INSTANCES);

        ExecuteTestMonitorBatch testBatch = new ExecuteTestMonitorBatch();

        System.assertEquals(false, ExecuteTestMonitorBatchServices.isMonitorBatchScheduledOrRunning(), 'The batch shuold not be scheduled yet');

        Test.startTest();
            testBatch.finish(null);
        Test.stopTest();

        List<CronTrigger> cronTriggers = [SELECT Id, CronJobDetail.Name, CronExpression, TimesTriggered, NextFireTime
                                          FROM CronTrigger
                                          WHERE CronJobDetail.Name = :ExecuteTestMonitorBatch.BATCH_JOB_TITLE];

        System.assertEquals(1, cronTriggers.size(), 'Only one Scheduled Job Should be found');
        System.assertEquals(0, cronTriggers[0].TimesTriggered, 'The scheduled job should not have fired yet');
        System.assertEquals(1, (Integer) testBatch.delayInMinutes.DelayInMinutes__c, 'The delay should be increased by one');
        System.assertEquals(true, ExecuteTestMonitorBatchServices.isMonitorBatchScheduledOrRunning(), 'The batch should be scheduled to run');
    }

    static testMethod void testBatchRepeatFunctionality_onlyRepeatsOnce() {
        DateTime scheduleTime = DateTime.now().addMinutes(1);
        final Integer NUM_INSTANCES = 2;

        basicSetup(TEST_JOB_COUNT_SINGLE, NUM_INSTANCES);

        ExecuteTestMonitorBatch testBatch = new ExecuteTestMonitorBatch();

        Test.startTest();
            try{
                testBatch.finish(null);
                testBatch.finish(null);
                testBatch.finish(null);
                testBatch.finish(null);
            }
            catch (Exception ex) {
                System.assert(false, 'No exceptions should be thrown ' + ex.getMessage());
            }
        Test.stopTest();

        List<CronTrigger> cronTriggers = [SELECT Id, CronJobDetail.Name, CronExpression, TimesTriggered, NextFireTime
                                          FROM CronTrigger
                                          WHERE CronJobDetail.Name = :ExecuteTestMonitorBatch.BATCH_JOB_TITLE];

        System.assertEquals(1, cronTriggers.size(), 'Only one Scheduled Job Should be found');
        System.assertEquals(0, cronTriggers[0].TimesTriggered, 'The scheduled job should not have fired yet');
        System.assertEquals(1, (Integer) testBatch.delayInMinutes.DelayInMinutes__c, 'The delay should be increased by one');
    }

    static testMethod void testBatchRepeatBackOffFunctionality() {
        final Integer NUM_INSTANCES = 2;

        basicSetup(TEST_JOB_COUNT_SINGLE, NUM_INSTANCES);

        ExecuteTestMonitorBatch testBatch = new ExecuteTestMonitorBatch();
        Integer originalDelay = (Integer) testBatch.delayInMinutes.DelayInMinutes__c;

        Test.startTest();
            testBatch.finish(null);
            TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });
            testBatch.finish(null);
            TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });
            testBatch.finish(null);
        Test.stopTest();

        System.assertEquals((ExecuteTestMonitorBatch.POLL_INTERVAL_INCREMENT * 3) + originalDelay, (Integer) testBatch.delayInMinutes.DelayInMinutes__c, 'The delay should be increased by three times the backoff step');

    }

    static testMethod void testBatchRepeatBackOffFunctionality_noMoreThan15Mins() {
        final Integer NUM_INSTANCES = 2;
        final Integer ORIGINAL_DELAY = 14;

        ExecuteTestMonitorDelay__c testSetting = new ExecuteTestMonitorDelay__c(DelayInMinutes__c = ORIGINAL_DELAY);
        insert testSetting;

        basicSetup(TEST_JOB_COUNT_SINGLE, NUM_INSTANCES);

        ExecuteTestMonitorBatch testBatch = new ExecuteTestMonitorBatch();
        Integer originalDelay = (Integer) testBatch.delayInMinutes.DelayInMinutes__c;

        Test.startTest();
            testBatch.finish(null);
            TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });
            testBatch.finish(null);
            TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });
            testBatch.finish(null);
        Test.stopTest();

        System.assertEquals(15, testBatch.delayInMinutes.DelayInMinutes__c, 'The delay should not go past 15 mins');
        System.assertEquals(15, (Integer) ExecuteTestMonitorDelay__c.getInstance().DelayInMinutes__c, 'The delay should be stored correctly');
    }

    static testMethod void testBatchRepeatBackOffFunctionality_backOffReset() {
        final Integer NUM_INSTANCES = 2;
        final Integer ORIGINAL_DELAY = 10;

        ExecuteTestMonitorDelay__c testSetting = new ExecuteTestMonitorDelay__c(DelayInMinutes__c = ORIGINAL_DELAY);
        insert testSetting;

        basicSetup(TEST_JOB_COUNT_SINGLE, NUM_INSTANCES);

        ExecuteTestMonitorBatch testBatch = new ExecuteTestMonitorBatch();
        Integer originalDelay = (Integer) testBatch.delayInMinutes.DelayInMinutes__c;

        Test.startTest();
            testBatch.finish(null);
            TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });
            testBatch.finish(null);
            System.assertEquals(12, (Integer) ExecuteTestMonitorDelay__c.getInstance().DelayInMinutes__c, 'The delay should be increased');
            Database.executeBatch(testBatch, TEST_JOB_COUNT_SINGLE);
        Test.stopTest();

        System.assertEquals(1, (Integer) ExecuteTestMonitorDelay__c.getInstance().DelayInMinutes__c, 'The delay should be reset correctly');
    }
}