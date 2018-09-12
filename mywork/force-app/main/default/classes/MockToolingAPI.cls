@isTest
public class MockToolingAPI implements HttpCalloutMock {
    public enum Action {
        RunTestsAsynchronous,
        QueryCodeCoverage,
        QueryTestSummaries,
        QueryTestResults
    }

    public static final String RETURN_ASYNC_JOB_STRING = '"7073600002PbkPH"';
    public static final Id RETURN_ASYNC_JOB_ID = '7073600002PbkPHAAZ';
    public static final Integer RETURN_TEST_SIZE = 1;
    public static final String RETURN_TEST_NAME = 'Test Name';
    public static final String RETURN_ERROR = 'Error!';
    public static final String RETURN_UNAUTHORIZED_ENDPOINT_ERROR = 'Unauthorized endpoint, please check Setup->Security->Remote site settings.';

    private Action mockAction;
    private Integer mockStatusCode;
    private String mockResponseBody;
    private Boolean remoteSiteSettingsTest;

    public MockToolingAPI(Action mockAction, Integer mockStatusCode) {
        this(mockAction, mockStatusCode, null);
    }

    public MockToolingAPI(Action mockAction, Integer mockStatusCode, String mockResponseBody) {
        this.mockAction = mockAction;
        this.mockStatusCode = mockStatusCode;
        this.mockResponseBody = mockResponseBody;
        this.remoteSiteSettingsTest = false;
    }

    public MockToolingAPI(Boolean remoteSiteSettingsTest) {
        this.remoteSiteSettingsTest = remoteSiteSettingsTest;
    }

    public HttpResponse respond(HttpRequest request) {
        if (this.remoteSiteSettingsTest) {
           CalloutException e = (CalloutException)CalloutException.class.newInstance();
           e.setMessage(RETURN_UNAUTHORIZED_ENDPOINT_ERROR);
           throw e;
        }
        HttpResponse response = new HttpResponse();

        response.setStatusCode(this.mockStatusCode);
        response.setStatus(ALMRestServices.HTTP_CODES_TO_STATUSES.get(this.mockStatusCode));
        if (mockResponseBody != null) {
            response.setBody(mockResponseBody);
        }

        if (mockStatusCode == ALMRestServices.HTTP_OK) {
            if (mockAction == Action.RunTestsAsynchronous) {
                response.setBody(RETURN_ASYNC_JOB_STRING);
            } else if (mockAction == Action.QueryCodeCoverage) {
                response.setBody(JSON.serialize(getCodeCoverageAggregate()));
            } else if (mockAction == Action.QueryTestSummaries) {
                CodeTestRunSummary runResult = new CodeTestRunSummary();
                runResult.size = RETURN_TEST_SIZE;

                CodeTestRunSummary.Records record = new CodeTestRunSummary.Records();
                record.AsyncApexJobId = RETURN_ASYNC_JOB_ID;

                runResult.records = new List<CodeTestRunSummary.Records>{record};

                response.setBody(JSON.serialize(runResult));
            } else if (mockAction == Action.QueryTestResults) {
                response.setBody(JSON.serialize(getCodeTestResult()));
            }
        } else if (mockStatusCode == ALMRestServices.HTTP_UNAUTHORIZED) {
            response.setBody(RETURN_ERROR);
        } else if (mockStatusCode == ALMRestServices.HTTP_FORBIDDEN) {
            response.setBody(ALMJobServices.RESPONSE_MISSING_PROPERTY);
        }

        return response;
    }

    public static CodeTestRunResult getCodeTestResult(){
        CodeTestRunResult runResult = new CodeTestRunResult();
        runResult.size = RETURN_TEST_SIZE;

        CodeTestRunResult.Records record = new CodeTestRunResult.Records();
        record.ApexClass = new CodeTestRunResult.ApexClass();
        record.ApexClass.Name = RETURN_TEST_NAME;

        runResult.records = new List<CodeTestRunResult.Records>{record};
        return runResult;
    }

    public static CodeCoverageAggregate getCodeCoverageAggregate(){
        CodeCoverageAggregate coverageResult = new CodeCoverageAggregate();
        coverageResult.size = RETURN_TEST_SIZE;

        CodeCoverageAggregate.Records record = new CodeCoverageAggregate.Records();
        record.ApexClassOrTrigger = new CodeCoverageAggregate.ApexClassOrTrigger();
        record.ApexClassOrTrigger.Name = RETURN_TEST_NAME;
        record.numLinesCovered = RETURN_TEST_SIZE;
        record.numLinesUnCovered = RETURN_TEST_SIZE;

        coverageResult.records = new List<CodeCoverageAggregate.Records>{record};
        return coverageResult;
    }
}