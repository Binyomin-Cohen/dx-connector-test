@isTest
public class MockScanAPI implements HttpCalloutMock {

    protected Integer code;
    protected String status;
    protected String body;
    protected Map<String, String> responseHeaders;

    public static final String SUCCESS_SCAN_JOB_REQUEST = 'SUCCESS_SCAN_JOB_REQUEST';
    public static final String UNAUTHORIZED_ENDPOINT_SCAN_JOB_REQUEST = 'UNAUTHORIZED_ENDPOINT_SCAN_JOB_REQUEST';

    public MockScanAPI(String action) {
        this(200, 'OK', '{"result": "success"}', new Map<String, String>());

        if(action == SUCCESS_SCAN_JOB_REQUEST) {
            body = '{}';
        } else if (action == UNAUTHORIZED_ENDPOINT_SCAN_JOB_REQUEST) {
            body = action;
        }
    }

    public MockScanAPI(Integer code, String status, String body, Map<String, String> responseHeaders) {
        this.code = code;
        this.status = status;
        this.body = body;
        this.responseHeaders = responseHeaders;
    }

    public HTTPResponse respond(HTTPRequest req) {
        if(body == UNAUTHORIZED_ENDPOINT_SCAN_JOB_REQUEST) {
            throw new ALMException('HTTP callout not allowed for this endpoint, please add the site to the remote site settings.');
        }
        HttpResponse res = new HttpResponse();
        for (String key : this.responseHeaders.keySet()) {
            res.setHeader(key, this.responseHeaders.get(key));
        }
        res.setBody(this.body);
        res.setStatusCode(this.code);
        res.setStatus(this.status);
        return res;
    }

}