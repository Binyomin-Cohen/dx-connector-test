@isTest
private class TestToolingServices {
    public static Instances__c testSourceInstance;
    public static Auth_User__c testSourceAuth;
    public static Auth_User__c testSightlineAuth;

    private static void setup() {
        testSourceInstance = new Instances__c(Name='Test Source Instance');
        insert testSourceInstance;

        testSourceAuth = TestingUtils.createAuthUser(UserInfo.getUserId(), testSourceInstance.Id, true);
        testSightlineAuth = TestingUtils.setupSightlineAuth();
    }

    private static testMethod void runTestsAsynchronous_success() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.RunTestsAsynchronous, ALMRestServices.HTTP_OK));

        setup();

        Test.startTest();

            String actualAsyncJobId = ToolingServices.runTestsAsynchronous(testSourceAuth);

        Test.stopTest();

        System.assertEquals(MockToolingAPI.RETURN_ASYNC_JOB_ID, actualAsyncJobId, 'The async job ID should match.');
    }

    private static testMethod void runTestsAsynchronous_failure() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.RunTestsAsynchronous, ALMRestServices.HTTP_UNAUTHORIZED));

        setup();

        Test.startTest();

            try {
                ToolingServices.runTestsAsynchronous(testSourceAuth);
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains(String.valueOf(ALMRestServices.HTTP_UNAUTHORIZED)), 'The proper exception should be thrown.');
            }

        Test.stopTest();
    }

    private static testMethod void getCodeCoverage_success() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.QueryCodeCoverage, ALMRestServices.HTTP_OK));

        setup();

        Test.startTest();

            CodeCoverageAggregate actualQueryResult = ToolingServices.getCodeCoverage(testSourceAuth);

        Test.stopTest();

        System.assertEquals(MockToolingAPI.RETURN_TEST_SIZE, actualQueryResult.size, 'The code coverage query result should match.');
        System.assertEquals(MockToolingAPI.RETURN_TEST_NAME, actualQueryResult.records[0].ApexClassOrTrigger.Name, 'The apex class or trigger name should match.');
    }

    private static testMethod void getCodeCoverage_failure() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.QueryCodeCoverage, ALMRestServices.HTTP_UNAUTHORIZED));

        setup();

        Test.startTest();

            try {
                ToolingServices.getCodeCoverage(testSourceAuth);
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains(String.valueOf(ALMRestServices.HTTP_UNAUTHORIZED)), 'The proper exception should be thrown.');
            }

        Test.stopTest();
    }

    private static testMethod void getCompletedTestRunSummaries_success() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.QueryTestSummaries, ALMRestServices.HTTP_OK));

        setup();

        Test.startTest();

            CodeTestRunSummary actualQueryResult = ToolingServices.getCompletedTestRunSummaries(testSourceAuth, new Set<String>{'Test ID'});

        Test.stopTest();

        System.assertEquals(MockToolingAPI.RETURN_TEST_SIZE, actualQueryResult.size, 'The completed test run result should match.');
        System.assertEquals(MockToolingAPI.RETURN_ASYNC_JOB_ID, actualQueryResult.records[0].AsyncApexJobId, 'The async job ID should match.');
    }

    private static testMethod void getCompletedTestRunSummaries_failure() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.QueryTestSummaries, ALMRestServices.HTTP_UNAUTHORIZED));

        setup();

        Test.startTest();

            try {
                ToolingServices.getCompletedTestRunSummaries(testSourceAuth, new Set<String>{'Test ID'});
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains(String.valueOf(ALMRestServices.HTTP_UNAUTHORIZED)), 'The proper exception should be thrown.');
            }

        Test.stopTest();
    }

    private static testMethod void getTestResults_success() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.QueryTestResults, ALMRestServices.HTTP_OK));

        setup();

        Test.startTest();

            CodeTestRunResult actualQueryResult = ToolingServices.getTestResults(testSourceAuth, new Set<String>{'Test ID'});

        Test.stopTest();

        System.assertEquals(MockToolingAPI.RETURN_TEST_SIZE, actualQueryResult.size, 'The completed test run result should match.');
        System.assertEquals(MockToolingAPI.RETURN_TEST_NAME, actualQueryResult.records[0].ApexClass.Name, 'The apex class name should match.');
    }

    private static testMethod void getTestResults_failure() {
        Test.setMock(HttpCalloutMock.class, new MockToolingAPI(MockToolingAPI.Action.QueryTestResults, ALMRestServices.HTTP_UNAUTHORIZED));

        setup();

        Test.startTest();

            try {
                ToolingServices.getTestResults(testSourceAuth, new Set<String>{'Test ID'});
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains(String.valueOf(ALMRestServices.HTTP_UNAUTHORIZED)), 'The proper exception should be thrown.');
            }

        Test.stopTest();
    }
}