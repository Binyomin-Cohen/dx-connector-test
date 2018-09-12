@isTest
public class MockToolingAPIForBatch implements HttpCalloutMock {
    public static final String ACTION_QUERY_CODE_COVERAGE = 'ApexCodeCoverageAggregate';
    public static final String ACTION_QUERY_TEST_SUMMARIES = 'ApexTestRunResult';
    public static final String ACTION_QUERY_TEST_RESULTS = 'ApexTestResult';

    public Map<String, String> enumValueToToolingApiObject = new Map<String, String>{
        MockToolingAPI.Action.QueryCodeCoverage.name() => ACTION_QUERY_CODE_COVERAGE,
        MockToolingAPI.Action.QueryTestSummaries.name() => ACTION_QUERY_TEST_SUMMARIES,
        MockToolingAPI.Action.QueryTestResults.name() => ACTION_QUERY_TEST_RESULTS
    };

    @TestVisible
    private static Integer CALLOUT_COUNTER = 0;
    @TestVisible private static List<String> EXPECTED_ASYNC_IDS = new List<String>{MockToolingAPI.RETURN_ASYNC_JOB_ID};

    private Integer statusCode;

    public MockToolingAPIForBatch(Integer statusCode) {
        this.statusCode = statusCode;
    }

    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(this.statusCode);

        if (statusCode == ALMRestServices.HTTP_OK) {
            if (request.getendpoint().contains(enumValueToToolingApiObject.get( MockToolingAPI.Action.QueryCodeCoverage.name()))) {
                response.setBody(JSON.serialize(MockToolingAPI.getCodeCoverageAggregate()));
            } else if (request.getendpoint().contains(enumValueToToolingApiObject.get( MockToolingAPI.Action.QueryTestSummaries.name()))) {
                List<CodeTestRunSummary.Records> recordsToReturn = new List<CodeTestRunSummary.Records>();
                CodeTestRunSummary runResult = new CodeTestRunSummary();
                runResult.size = EXPECTED_ASYNC_IDS.size();

                for(String asyncId : EXPECTED_ASYNC_IDS){
                    CodeTestRunSummary.Records record = new CodeTestRunSummary.Records();
                    record.AsyncApexJobId = asyncId;
                    recordsToReturn.add(record);
                }
                runResult.records = recordsToReturn;

                response.setBody(JSON.serialize(runResult));
            } else if (request.getendpoint().contains(enumValueToToolingApiObject.get( MockToolingAPI.Action.QueryTestResults.name()))) {
                response.setBody(JSON.serialize(MockToolingAPI.getCodeTestResult()));
            }
        } else if (statusCode == ALMRestServices.HTTP_UNAUTHORIZED) {
            response.setBody(MockToolingAPI.RETURN_ERROR);
        }
        CALLOUT_COUNTER++;
        return response;
    }
}