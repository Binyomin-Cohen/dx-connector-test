public with sharing class ToolingServices {
    public static final String API_VERSION = 'v39.0';
    public static final String TOOLING_PATH = '/services/data/' + API_VERSION + '/tooling/';
    public static final String RUN_TESTS_ASYNCHRONOUS_ENDPOINT = 'runTestsAsynchronous';
    public static final String QUERY_ENDPOINT = 'query?q=';

    /**
    * Runs Apex unit tests asynchronously.
    * @param authUser: The user authorization information for the org from which coverage information should be retrieved.
    * @return The new Apex unit test async job ID.
    * @throws ALMException
    */
    public static Id runTestsAsynchronous(Auth_User__c authUser) {
        return ALMRestServices.makePostRequest(
            authUser.Instance_URL__c + TOOLING_PATH + RUN_TESTS_ASYNCHRONOUS_ENDPOINT, 
            JSON.serialize(new ApexTestRequest()), 
            authUser.Access_Token__c
        ).replace('"', '');
    }

    /**
    * Retrieves completed Apex unit test code coverage.
    * @param authUser: The user authorization information for the org from which coverage information should be retrieved.
    * @return A code coverage aggregate model for the completed test run.
    * @throws ALMException
    */
    public static CodeCoverageAggregate getCodeCoverage(Auth_User__c authUser) {
        final String QUERY_STRING = 
            'SELECT ApexClassOrTrigger.Id, ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered FROM ApexCodeCoverageAggregate';

        return (CodeCoverageAggregate)JSON.deserialize(query(authUser, QUERY_STRING), CodeCoverageAggregate.class);
    }

    /**
    * Retrieves completed Apex unit test run summaries.
    * @param authUser: The user authorization information for the org from which coverage information should be retrieved.
    * @param asyncJobIds: A set of Apex unit test async job IDs.
    * @return A test run result model for the completed summaries.
    * @throws ALMException
    */
    public static CodeTestRunSummary getCompletedTestRunSummaries(Auth_User__c authUser, Set<String> asyncJobIds) {
        final String QUERY_STRING = 
            'SELECT AsyncApexJobId, StartTime, EndTime, MethodsFailed, MethodsCompleted ' + 
            'FROM ApexTestRunResult ' + 
            'WHERE AsyncApexJobId IN ' + BluewolfDevUtils.flattenListForQuery(new List<String>(asyncJobIds)) + 
                ' AND Status = \'Completed\'';

        return (CodeTestRunSummary)JSON.deserialize(query(authUser, QUERY_STRING), CodeTestRunSummary.class);
    }

    /**
    * Retrieves Apex unit test results.
    * @param authUser: The user authorization information for the org from which coverage information should be retrieved.
    * @param asyncJobIds: A set of Apex unit test async job IDs.
    * @return A test result model for the tests.
    * @throws ALMException
    */
    public static CodeTestRunResult getTestResults(Auth_User__c authUser, Set<String> asyncJobIds) {
        final String QUERY_STRING = 
            'SELECT AsyncApexJobId, MethodName, Message, Outcome, StackTrace, RunTime, ApexLogId, ApexClass.Name ' + 
            'FROM ApexTestResult ' + 
            'WHERE AsyncApexJobId IN ' + BluewolfDevUtils.flattenListForQuery(new List<String>(asyncJobIds));

        return (CodeTestRunResult)JSON.deserialize(query(authUser, QUERY_STRING), CodeTestRunResult.class);
    } 

    /**
    * @throws ALMException
    */
    private static String query(Auth_User__c authUser, String queryString) {
        return ALMRestServices.makeGetRequest(
            authUser.Instance_URL__c + TOOLING_PATH + QUERY_ENDPOINT + EncodingUtil.urlEncode(queryString, 'UTF-8'), 
            authUser.Access_Token__c
        );
    }
}