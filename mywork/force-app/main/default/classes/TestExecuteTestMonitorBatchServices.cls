@isTest
private class TestExecuteTestMonitorBatchServices {
    static List<ALM_Job__c> jobs;
    static final Integer NUM_JOBS = 6;

    static void setupDataForCallouts() {
        Instances__c testSourceInstance = new Instances__c(Name='Test Source Instance');
        insert testSourceInstance;

        Auth_User__c testSourceAuth = TestingUtils.createAuthUser(UserInfo.getUserId(), testSourceInstance.Id, true);
        Auth_User__c testSightlineAuth = TestingUtils.setupSightlineAuth();

        Instances__c instance1 = TestingUtils.createInstance('Test Instance 1');
        Instances__c instance2 = TestingUtils.createInstance('Test Instance 2');
        Instances__c instance3 = TestingUtils.createInstance('Test Instance 3');
        List<Instances__c> testInstances = new List<Instances__c>{instance1,instance2,instance3};

        for (Instances__c instance : testInstances) {
            TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id, true);
        }

        jobs = new List<ALM_Job__c>();

        for (Integer i = 0; i < NUM_JOBS; i++) {
            jobs.add(TestingUtils.buildAlmJob(null, null, null, null));
        }

        UnitTest.addData(jobs).tag('All Jobs');

        UnitTest.get('All Jobs')
        .divide(3)
        .part('Instance1 jobs')
        .part('Instance2 jobs')
        .part('Instance3 jobs');

        UnitTest.get('Instance1 jobs')
        .property('Source_Instance__c').assign(instance1.Id);

        UnitTest.get('Instance2 jobs')
        .property('Source_Instance__c').assign(instance2.Id);

        UnitTest.get('Instance3 jobs')
        .property('Source_Instance__c').assign(instance3.Id);

        UnitTest.get('All Jobs')
        .property('Async_Apex_Job_Id__c').assign(MockToolingAPI.RETURN_ASYNC_JOB_ID);

        UnitTest.get('All Jobs').insertAll();
    }

    static CodeCoverageAggregate.Records buildCodeCoverageAggregateRecord(String apexClassOrTriggerId, String apexClassOrTriggerName, Integer numLinesCovered, Integer numLinesUncovered) {
        CodeCoverageAggregate.ApexClassOrTrigger testCodeCoverageAggregateApexClassOrTrigger = 
            new CodeCoverageAggregate.ApexClassOrTrigger();
        testCodeCoverageAggregateApexClassOrTrigger.id = apexClassOrTriggerId;
        testCodeCoverageAggregateApexClassOrTrigger.name = apexClassOrTriggerName;

        CodeCoverageAggregate.Records testCodeCoverageAggregateRecord = new CodeCoverageAggregate.Records();
        testCodeCoverageAggregateRecord.apexClassOrTrigger = testCodeCoverageAggregateApexClassOrTrigger;
        testCodeCoverageAggregateRecord.numLinesCovered = numLinesCovered;
        testCodeCoverageAggregateRecord.numLinesUncovered = numLinesUncovered;

        return testCodeCoverageAggregateRecord;
    }

    static CodeTestRunResult.Records buildCodeTestRunResultRecord(String outcome, String apexClassName, String methodName, String message, Integer runTime, String stackTrace, String apexLogId) {
        CodeTestRunResult.ApexClass testCodeTestRunResultApexClass = new CodeTestRunResult.ApexClass();
        testCodeTestRunResultApexClass.name = apexClassName;

        CodeTestRunResult.Records testCodeTestRunResultRecord = new CodeTestRunResult.Records();
        testCodeTestRunResultRecord.outcome = outcome;
        testCodeTestRunResultRecord.apexClass = testCodeTestRunResultApexClass;
        testCodeTestRunResultRecord.methodName = methodName;
        testCodeTestRunResultRecord.message = message;
        testCodeTestRunResultRecord.runTime = runTime;
        testCodeTestRunResultRecord.stackTrace = stackTrace;
        testCodeTestRunResultRecord.apexLogId = apexLogId;

        return testCodeTestRunResultRecord;
    }

    static testMethod void isMonitorBatchNotScheduled() {
        TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });

        Boolean isBatchScheduled;

        Test.startTest();
        isBatchScheduled = ExecuteTestMonitorBatchServices.isMonitorBatchScheduledOrRunning();
        Test.StopTest();

        System.assertEquals(false, isBatchScheduled, 'The Services Class Should have detected that the monitor batch has not been scheduled');

    }

    static testMethod void isMonitorBatchScheduledOrRunning() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPIForBatch(ALMRestServices.HTTP_OK));

        TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });

        System.ScheduleBatch(new ExecuteTestMonitorBatch(), ExecuteTestMonitorBatch.BATCH_JOB_TITLE, 2);

        Boolean isBatchScheduled;

        Test.startTest();
        isBatchScheduled = ExecuteTestMonitorBatchServices.isMonitorBatchScheduledOrRunning();
        Test.StopTest();

        System.assertEquals(true, isBatchScheduled, 'The Services Class Should have detected that the monitor batch has already been scheduled');

    }

    static testMethod void isMonitorBatchAlreadyRunning() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPIForBatch(ALMRestServices.HTTP_OK));

        TestingUtils.deleteExistingJobs(new List<String>{ ExecuteTestMonitorBatch.BATCH_JOB_TITLE });

        Database.executeBatch(new ExecuteTestMonitorBatch());

        Boolean isBatchScheduled;

        Test.startTest();
        isBatchScheduled = ExecuteTestMonitorBatchServices.isMonitorBatchScheduledOrRunning();
        Test.StopTest();

        System.assertEquals(true, isBatchScheduled, 'The Services Class Should have detected that the monitor batch has already been scheduled');

    }

    static testMethod void checkForCompletedJobs_mixGoodAuthAndBadAuth() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.QueryTestSummaries, ALMRestServices.HTTP_OK));

        Instances__c testInstance = new Instances__c(Name = 'Test Instance');
        insert testInstance;
        TestingUtils.createAuthUser(UserInfo.getUserId(), testInstance.Id, true);

        Instances__c testOtherInstance = new Instances__c(Name = 'Test Other Instance');
        insert testOtherInstance;

        ALM_Job__c testCompletedJob = TestingUtils.buildDefaultButrJob(testInstance, testInstance);
        ALM_Job__c testFailedJob = TestingUtils.buildDefaultButrJob(testOtherInstance, testOtherInstance);
        testCompletedJob.Async_Apex_Job_Id__c = MockToolingAPI.RETURN_ASYNC_JOB_ID;
        testFailedJob.Async_Apex_Job_Id__c = 'Incomplete Job ID';
        jobs = new List<ALM_Job__c>{testCompletedJob, testFailedJob};
        insert jobs;

        Test.startTest();

            Map<Id, Unit_Test_Summary__c> resultsMap = ExecuteTestMonitorBatchServices.checkForCompletedJobs(jobs);

        Test.StopTest();

        System.assertEquals(2, resultsMap.size(), 'Both jobs should be completed.');
        System.assertEquals(null, resultsMap.get(testCompletedJob.Id).Error_Details__c, 'There should no error details on the successful job.');
        System.assertEquals(ExecuteTestMonitorBatchServices.ERROR_RETRIEVAL_AUTH, resultsMap.get(testFailedJob.Id).Error_Details__c, 'There should be proper error details on the failed job.');
    }

    static testMethod void checkForCompletedJobs_mixCompleteAndIncomplete() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.QueryTestSummaries, ALMRestServices.HTTP_OK));

        Instances__c testInstance = new Instances__c(Name = 'Test Instance');
        insert testInstance;
        TestingUtils.createAuthUser(UserInfo.getUserId(), testInstance.Id, true);

        ALM_Job__c testCompletedJob = TestingUtils.buildDefaultButrJob(testInstance, testInstance);
        ALM_Job__c testIncompleteJob = TestingUtils.buildDefaultButrJob(testInstance, testInstance);
        testCompletedJob.Async_Apex_Job_Id__c = MockToolingAPI.RETURN_ASYNC_JOB_ID;
        testIncompleteJob.Async_Apex_Job_Id__c = 'Incomplete Job ID';
        jobs = new List<ALM_Job__c>{testCompletedJob, testIncompleteJob};
        insert jobs;

        Test.startTest();

            Map<Id, Unit_Test_Summary__c> resultsMap = ExecuteTestMonitorBatchServices.checkForCompletedJobs(jobs);

        Test.StopTest();

        System.assertEquals(1, resultsMap.size(), 'There should be one completed job.');
        System.assert(resultsMap.containsKey(testCompletedJob.Id), 'The correct job should be completed.');
    }

    static testMethod void TestGetCodeCoverageForJobs() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.QueryCodeCoverage, ALMRestServices.HTTP_OK));

        setupDataForCallouts();

        Map<Id, CodeCoverageAggregate> actualCoverageMap;

        Test.startTest();
        actualCoverageMap = ExecuteTestMonitorBatchServices.getCodeCoverageForJobs(jobs);
        Test.StopTest();

        System.assertNotEquals(null, actualCoverageMap, 'The coverage map should be instantiated');
        System.assertEquals(NUM_JOBS, actualCoverageMap.size(), 'The coverage map should be the correct size');
        System.assert(actualCoverageMap.keySet().containsAll(UnitTest.getIds('All Jobs')),'The correct jobIds should be returned');

        for (CodeCoverageAggregate coverage : actualCoverageMap.values()) {
            System.assertEquals(MockToolingAPI.RETURN_TEST_SIZE, coverage.size, 'The correct coverage size should be returned');
            List<CodeCoverageAggregate.Records> records = coverage.records;
            System.assertEquals(1, records.size(), 'Only one coverage record should be returned');
            System.assertEquals(MockToolingAPI.RETURN_TEST_NAME, records[0].ApexClassOrTrigger.Name, 'The correct apex class name should be detected');
        }
    }

    static testMethod void TestGetCodeTestResultsForJobs() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.QueryTestResults, ALMRestServices.HTTP_OK));

        setupDataForCallouts();

        Map<Id, CodeTestRunResult> actualTestRunMap;

        Test.startTest();
        actualTestRunMap = ExecuteTestMonitorBatchServices.getCodeTestResultsForJobs(jobs);
        Test.StopTest();

        System.assertNotEquals(null, actualTestRunMap, 'The coverage map should be instantiated');
        System.assertEquals(NUM_JOBS, actualTestRunMap.size(), 'The coverage map should be the correct size');
        System.assert(actualTestRunMap.keySet().containsAll(UnitTest.getIds('All Jobs')),'The correct jobIds should be returned');

        for (CodeTestRunResult codeTestRun : actualTestRunMap.values()) {
            System.assertEquals(MockToolingAPI.RETURN_TEST_SIZE, codeTestRun.size, 'The correct testRunSize should be returned');
            List<CodeTestRunResult.Records> records = codeTestRun.records;
            System.assertEquals(1, records.size(), 'Only one coverage record should be returned');
            System.assertEquals(MockToolingAPI.RETURN_TEST_NAME, records[0].ApexClass.Name, 'The correct apex class name should be detected');
        }
    }

    static testMethod void createCoverageObjectsForJob_failure_nullCodeCoverageAggregate() {
        ALM_Job__c testJob = new ALM_Job__c();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();

        Test.startTest();

            try {
                List<Code_Coverage__c> actualCoverageResults = 
                    ExecuteTestMonitorBatchServices.createCoverageObjectsForJob(null, testJob, testApplicationResult, testUnitTestSummary);
                System.assertEquals(null, actualCoverageResults, 'The code coverage results list should be null.');
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();
    }

    static testMethod void createCoverageObjectsForJob_failure_nullJob() {
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();
        CodeCoverageAggregate testCodeCoverageAggregate = new CodeCoverageAggregate();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();

        Test.startTest();

            try {
                List<Code_Coverage__c> actualCoverageResults = 
                    ExecuteTestMonitorBatchServices.createCoverageObjectsForJob(testCodeCoverageAggregate, null, testApplicationResult, testUnitTestSummary);
                System.assertEquals(null, actualCoverageResults, 'The code coverage results list should be null.');
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();
    }

    static testMethod void createCoverageObjectsForJob_failure_nullApplicationResult() {
        ALM_Job__c testJob = new ALM_Job__c();
        CodeCoverageAggregate testCodeCoverageAggregate = new CodeCoverageAggregate();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();

        Test.startTest();

            try {
                List<Code_Coverage__c> actualCoverageResults = 
                    ExecuteTestMonitorBatchServices.createCoverageObjectsForJob(testCodeCoverageAggregate, testJob, null, testUnitTestSummary);
                System.assertEquals(null, actualCoverageResults, 'The code coverage results list should be null.');
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();
    }

    static testMethod void createCoverageObjectsForJob_failure_nullUnitTestSummary() {
        ALM_Job__c testJob = new ALM_Job__c();
        CodeCoverageAggregate testCodeCoverageAggregate = new CodeCoverageAggregate();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();

        Test.startTest();

            try {
                List<Code_Coverage__c> actualCoverageResults = 
                    ExecuteTestMonitorBatchServices.createCoverageObjectsForJob(testCodeCoverageAggregate, testJob, testApplicationResult, null);
                System.assertEquals(null, actualCoverageResults, 'The code coverage results list should be null.');
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();
    }

    static testMethod void createCoverageObjectsForJob_failure_errorResult() {
        String testErrorMessage = 'Error!';

        CodeCoverageAggregate testCodeCoverageAggregate = new CodeCoverageAggregate();
        testCodeCoverageAggregate.records = new List<CodeCoverageAggregate.Records>();
        testCodeCoverageAggregate.error = new ALMException(testErrorMessage);

        ALM_Job__c testJob = new ALM_Job__c();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();
        insert testUnitTestSummary;

        Test.startTest();

            List<Code_Coverage__c> actualCoverageResults = 
                ExecuteTestMonitorBatchServices.createCoverageObjectsForJob(testCodeCoverageAggregate, testJob, testApplicationResult, testUnitTestSummary);

        Test.stopTest();

        System.assertEquals(0, actualCoverageResults.size(), 'There should be no code coverage results.');
        System.assertEquals(SCANServices.FAILURE_STATUS, testApplicationResult.Result__c, 'The result should be a failure.');
        System.assert(testUnitTestSummary.System_Error__c, 'There should be a system error.');
        System.assertEquals(ExecuteTestMonitorBatchServices.ERROR_RETRIEVAL_COVERAGE, testJob.Errors__c, 'There should be a proper job error message.');
        System.assertEquals(ExecuteTestMonitorBatchServices.ERROR_RETRIEVAL_COVERAGE, testApplicationResult.Error_Message__c, 'There should be a proper application result error message.');
        System.assert(testApplicationResult.Warnings__c.contains(testErrorMessage), 'There should be a proper warning.');
    }

    static testMethod void createCoverageObjectsForJob_success() {
        String testApexClassOrTriggerId = 'Test Apex Class Or Trigger ID';
        String testApexClassOrTriggerName = 'Test Apex Class Or Trigger Name';
        Integer testNumLinesCovered = 15;
        Integer testNumLinesUncovered = 5;

        CodeCoverageAggregate testCodeCoverageAggregate = new CodeCoverageAggregate();
        testCodeCoverageAggregate.records = new List<CodeCoverageAggregate.Records>();
        testCodeCoverageAggregate.records.add(
            buildCodeCoverageAggregateRecord(
                testApexClassOrTriggerId,
                testApexClassOrTriggerName,
                testNumLinesCovered,
                testNumLinesUncovered
            )
        );

        ALM_Job__c testJob = new ALM_Job__c();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();
        insert testUnitTestSummary;

        Test.startTest();

            List<Code_Coverage__c> actualCoverageResults = 
                ExecuteTestMonitorBatchServices.createCoverageObjectsForJob(testCodeCoverageAggregate, testJob, testApplicationResult, testUnitTestSummary);

        Test.stopTest();

        System.assertEquals(1, actualCoverageResults.size(), 'There should be one code coverage result.');
        System.assertEquals(SCANServices.SUCCESS_STATUS, testApplicationResult.Result__c, 'The result should be successful.');
        System.assertEquals(false, testUnitTestSummary.System_Error__c, 'There should be no system error.');
        System.assertEquals(null, testUnitTestSummary.Error_Details__c, 'There should be no error details.');
        System.assertEquals(null, testApplicationResult.Warnings__c, 'There should be no warnings.');
        System.assertEquals(testUnitTestSummary.Id, actualCoverageResults[0].Unit_Test_Summary__c, 'The unit test summary lookup should be populated correctly.');
        System.assertEquals(testNumLinesCovered, testUnitTestSummary.Apex_Lines_Covered__c, 'The unit test summary "lines covered" metric should be set properly.');
        System.assertEquals(testNumLinesCovered + testNumLinesUncovered, testUnitTestSummary.Apex_Total_LOC__c, 'The unit test summary "total lines" metric should be set properly.');
    }

    static testMethod void createUnitTestFailureObjectsForJob_failure_nullCodeTestRunResult() {
        ALM_Job__c testJob = new ALM_Job__c();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();

        Test.startTest();

            try {
                List<Unit_Test_Failure__c> actualUnitTestFailureResults = 
                    ExecuteTestMonitorBatchServices.createUnitTestFailureObjectsForJob(null, testJob, testApplicationResult, testUnitTestSummary);
                System.assertEquals(null, actualUnitTestFailureResults, 'The unit test failure results list should be null.');
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();
    }

    static testMethod void createUnitTestFailureObjectsForJob_failure_nullJob() {
        CodeTestRunResult testCodeTestRunResult = new CodeTestRunResult();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();

        Test.startTest();

            try {
                List<Unit_Test_Failure__c> actualUnitTestFailureResults = 
                    ExecuteTestMonitorBatchServices.createUnitTestFailureObjectsForJob(testCodeTestRunResult, null, testApplicationResult, testUnitTestSummary);
                System.assertEquals(null, actualUnitTestFailureResults, 'The unit test failure results list should be null.');
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();
    }

    static testMethod void createUnitTestFailureObjectsForJob_failure_nullApplicationResult() {
        CodeTestRunResult testCodeTestRunResult = new CodeTestRunResult();
        ALM_Job__c testJob = new ALM_Job__c();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();

        Test.startTest();

            try {
                List<Unit_Test_Failure__c> actualUnitTestFailureResults = 
                    ExecuteTestMonitorBatchServices.createUnitTestFailureObjectsForJob(testCodeTestRunResult, testJob, null, testUnitTestSummary);
                System.assertEquals(null, actualUnitTestFailureResults, 'The unit test failure results list should be null.');
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();
    }

    static testMethod void createUnitTestFailureObjectsForJob_failure_nullUnitTestSummary() {
        CodeTestRunResult testCodeTestRunResult = new CodeTestRunResult();
        ALM_Job__c testJob = new ALM_Job__c();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();

        Test.startTest();

            try {
                List<Unit_Test_Failure__c> actualUnitTestFailureResults = 
                    ExecuteTestMonitorBatchServices.createUnitTestFailureObjectsForJob(testCodeTestRunResult, testJob, testApplicationResult, null);
                System.assertEquals(null, actualUnitTestFailureResults, 'The unit test failure results list should be null.');
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();
    }

    static testMethod void createUnitTestFailureObjectsForJob_failure_errorResult() {
        String testErrorMessage = 'Error!';

        CodeTestRunResult testCodeTestRunResult = new CodeTestRunResult();
        testCodeTestRunResult.records = new List<CodeTestRunResult.Records>();
        testCodeTestRunResult.error = new ALMException(testErrorMessage);

        ALM_Job__c testJob = new ALM_Job__c();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();
        insert testUnitTestSummary;

        Test.startTest();

            List<Unit_Test_Failure__c> actualUnitTestFailureResults = 
                ExecuteTestMonitorBatchServices.createUnitTestFailureObjectsForJob(testCodeTestRunResult, testJob, testApplicationResult, testUnitTestSummary);

        Test.stopTest();

        System.assertEquals(0, actualUnitTestFailureResults.size(), 'There should be no unit test failure results.');
        System.assertEquals(SCANServices.FAILURE_STATUS, testApplicationResult.Result__c, 'The result should be a failure.');
        System.assert(testUnitTestSummary.System_Error__c, 'There should be a system error.');
        System.assertEquals(ExecuteTestMonitorBatchServices.ERROR_RETRIEVAL_FAILURES, testJob.Errors__c, 'There should be proper error details.');
        System.assertEquals(ExecuteTestMonitorBatchServices.ERROR_RETRIEVAL_FAILURES, testApplicationResult.Error_Message__c, 'There should be proper error details.');
        System.assert(testApplicationResult.Warnings__c.contains(testErrorMessage), 'There should be a proper warning.');
    }

    static testMethod void createUnitTestFailureObjectsForJob_success_noFailures() {
        CodeTestRunResult testCodeTestRunResult = new CodeTestRunResult();
        testCodeTestRunResult.records = new List<CodeTestRunResult.Records>();

        ALM_Job__c testJob = new ALM_Job__c();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();
        insert testUnitTestSummary;

        Test.startTest();

            List<Unit_Test_Failure__c> actualUnitTestFailureResults = 
                ExecuteTestMonitorBatchServices.createUnitTestFailureObjectsForJob(testCodeTestRunResult, testJob, testApplicationResult, testUnitTestSummary);

        Test.stopTest();

        System.assertEquals(0, actualUnitTestFailureResults.size(), 'There should be no unit test failure results.');
        System.assertEquals(SCANServices.SUCCESS_STATUS, testApplicationResult.Result__c, 'The result should be a failure.');
        System.assertEquals(false, testUnitTestSummary.System_Error__c, 'There should be no system error.');
        System.assertEquals(null, testUnitTestSummary.Error_Details__c, 'There should be no error details.');
        System.assertEquals(null, testApplicationResult.Warnings__c, 'There should be no warnings.');
    }

    static testMethod void createUnitTestFailureObjectsForJob_success_someFailures() {
        String testFailedApexClassName = 'Test Failed Apex Class Name';
        String testFailedApexMethodName = 'Test Failed Apex Method Name';
        String testFailedMessage = 'Test Failed Message';
        Integer testFailedRunTime = 1000;
        String testFailedStackTrace = 'Test Failed Stack Trace';
        String testFailedApexLogId = 'Test Failed Apex Log ID';
        String testFailedOutcome = CodeTestRunResult.OUTCOME_FAIL;

        String testPassedApexClassName = 'Test Passed Apex Class Name';
        String testPassedApexMethodName = 'Test Passed Apex Method Name';
        String testPassedMessage = 'Test Passed Message';
        Integer testPassedRunTime = 1000;
        String testPassedStackTrace = 'Test Passed Stack Trace';
        String testPassedApexLogId = 'Test Passed Apex Log ID';
        String testPassedOutcome = CodeTestRunResult.OUTCOME_PASS;

        CodeTestRunResult testCodeRunTestResult = new CodeTestRunResult();
        testCodeRunTestResult.records = new List<CodeTestRunResult.Records>();
        testCodeRunTestResult.records.add(
            buildCodeTestRunResultRecord(
                testFailedOutcome,
                testFailedApexClassName,
                testFailedApexMethodName,
                testFailedMessage,
                testFailedRunTime,
                testFailedStackTrace,
                testFailedApexLogId
            )
        );
        testCodeRunTestResult.records.add(
            buildCodeTestRunResultRecord(
                testPassedOutcome,
                testPassedApexClassName,
                testPassedApexMethodName,
                testPassedMessage,
                testPassedRunTime,
                testPassedStackTrace,
                testPassedApexLogId
            )
        );

        ALM_Job__c testJob = new ALM_Job__c();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();
        insert testUnitTestSummary;

        Test.startTest();

            List<Unit_Test_Failure__c> actualUnitTestFailureResults = 
                ExecuteTestMonitorBatchServices.createUnitTestFailureObjectsForJob(testCodeRunTestResult, testJob, testApplicationResult, testUnitTestSummary);

        Test.stopTest();

        System.assertEquals(1, actualUnitTestFailureResults.size(), 'There should be one unit test failure result.');
        System.assertEquals(SCANServices.SUCCESS_STATUS, testApplicationResult.Result__c, 'The result should be a success.');
        System.assertEquals(false, testUnitTestSummary.System_Error__c, 'There should be no system error.');
        System.assert(testUnitTestSummary.Error_Details__c.contains(testFailedApexClassName), 'The error details should contain the failed test class.');
        System.assert(testUnitTestSummary.Error_Details__c.contains(testFailedApexMethodName), 'The error details should contain the failed test method.');
        System.assert(testUnitTestSummary.Error_Details__c.contains(testFailedMessage), 'The error details should contain the failed test message.');
        System.assert(!testUnitTestSummary.Error_Details__c.endsWith(ExecuteTestMonitorBatchServices.SUMMARY_FAILURES_TRUNCATED), 'The error details should not be truncated.');
        System.assertEquals(testUnitTestSummary.Id, actualUnitTestFailureResults[0].Unit_Test_Summary__c, 'The unit test summary lookup should be populated correctly.');
        System.assertEquals(testFailedApexClassName, actualUnitTestFailureResults[0].Class_Name__c, 'The correct test run result should be returned as a failure.');
    }

    static testMethod void createUnitTestFailureObjectsForJob_success_longFailure() {
        String testFailedApexClassName = 'Test Failed Apex Class Name';
        String testFailedApexMethodName = 'Test Failed Apex Method Name';
        Integer testFailedRunTime = 1000;
        String testFailedStackTrace = 'Test Failed Stack Trace';
        String testFailedApexLogId = 'Test Failed Apex Log ID';
        String testFailedOutcome = CodeTestRunResult.OUTCOME_FAIL;

        String testMessageFragment = 'Error!';
        String testFailedMessageLong = 
            testMessageFragment.repeat(Unit_Test_Summary__c.Error_Details__c.getDescribe().getLength() / (testMessageFragment.length() - 1));

        CodeTestRunResult testCodeTestRunResult = new CodeTestRunResult();
        testCodeTestRunResult.records = new List<CodeTestRunResult.Records>();
        testCodeTestRunResult.records.add(
            buildCodeTestRunResultRecord(
                testFailedOutcome,
                testFailedApexClassName,
                testFailedApexMethodName,
                testFailedMessageLong,
                testFailedRunTime,
                testFailedStackTrace,
                testFailedApexLogId
            )
        );

        ALM_Job__c testJob = new ALM_Job__c();
        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();
        Unit_Test_Summary__c testUnitTestSummary = new Unit_Test_Summary__c();
        insert testUnitTestSummary;

        Test.startTest();

            List<Unit_Test_Failure__c> actualUnitTestFailureResults = 
                ExecuteTestMonitorBatchServices.createUnitTestFailureObjectsForJob(testCodeTestRunResult, testJob, testApplicationResult, testUnitTestSummary);

        Test.stopTest();

        System.assertEquals(1, actualUnitTestFailureResults.size(), 'There should be one unit test failure result.');
        System.assertEquals(SCANServices.SUCCESS_STATUS, testApplicationResult.Result__c, 'The result should be a success.');
        System.assertEquals(false, testUnitTestSummary.System_Error__c, 'There should be no system error.');
        System.assertEquals(Unit_Test_Summary__c.Error_Details__c.getDescribe().getLength(), testUnitTestSummary.Error_Details__c.length(), 'The error details should fill the field.');
        System.assert(testUnitTestSummary.Error_Details__c.contains(testFailedApexClassName), 'The error details should contain the failed test class.');
        System.assert(testUnitTestSummary.Error_Details__c.contains(testFailedApexMethodName), 'The error details should contain the failed test method.');
        System.assert(testUnitTestSummary.Error_Details__c.contains(testMessageFragment), 'The error details should contain part of the error message.');
        System.assert(testUnitTestSummary.Error_Details__c.endsWith(ExecuteTestMonitorBatchServices.SUMMARY_FAILURES_TRUNCATED), 'The error details should be truncated.');
        System.assertEquals(testUnitTestSummary.Id, actualUnitTestFailureResults[0].Unit_Test_Summary__c, 'The unit test summary lookup should be populated correctly.');
        System.assertEquals(testFailedApexClassName, actualUnitTestFailureResults[0].Class_Name__c, 'The correct test run result should be returned as a failure.');
    }
}