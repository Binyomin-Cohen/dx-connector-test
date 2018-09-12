@isTest
public class MockVCAPI implements HttpCalloutMock {
    public String mockResponseBody;
    public Integer mockResponseStatusCode;
    public String requestBody;

    public Set<Id> expectedIds;

    public MockVCAPI(String mockResponseBody) {
        this.mockResponseBody = mockResponseBody;
    }

    public MockVCAPI(String mockResponseBody, Integer mockResponseStatusCode) {
        this.mockResponseBody = mockResponseBody;
        this.mockResponseStatusCode = mockResponseStatusCode;
    }

    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();

        if (this.mockResponseStatusCode == null) {
            String endpoint = request.getEndpoint();
            if (endpoint.contains(SSHServices.KEYGEN_ENDPOINT)) {
                Map<String, Object> requestBody = (Map<String, Object>)JSON.deserializeUntyped(request.getBody());
                if (requestBody.containsKey('orgId')) {
                    response.setStatusCode(ALMRestServices.HTTP_OK);
                    response.setBody(this.mockResponseBody);
                } else {
                    response.setStatusCode(ALMRestServices.HTTP_BAD_REQUEST);
                }
            } else if (endpoint.contains(VCServices.GIT_LIST_ENDPOINT)) {
                Map<String, Object> requestBody = (Map<String, Object>)JSON.deserializeUntyped(request.getBody());
                if (requestBody.containsKey('orgId') &&
                    requestBody.containsKey('repoUrl') &&
                    requestBody.containsKey('publicKey') &&
                    requestBody.containsKey('privateKey') &&
                    requestBody.containsKey('passPhrase')) {

                    response.setStatusCode(ALMRestServices.HTTP_OK);
                    response.setBody(this.mockResponseBody);
                } else {
                    response.setStatusCode(ALMRestServices.HTTP_BAD_REQUEST);
                }
            } else if (endpoint.contains(VCServices.GIT_REPO_SYNC_ENDPOINT)) {
                mockResponseStatusCode = ALMRestServices.HTTP_OK;
                mockResponseBody = 'Success';
                requestBody = request.getBody();

                response.setStatusCode(mockResponseStatusCode);
                response.setBody(mockResponseBody);
            } else {
                response.setStatusCode(ALMRestServices.HTTP_NOT_FOUND);
            }
        } else {
            response.setStatusCode(this.mockResponseStatusCode);
            response.setBody(this.mockResponseBody);
        }

        String status = ALMRestServices.HTTP_CODES_TO_STATUSES.get(response.getStatusCode());
        response.setStatus(status != null ? status : '');

        return response;
    }

    public static String setupGitListSuccessResponse(List<String> branches) {
        VCServices.GitListResponse listResponse = new VCServices.GitListResponse();
        listResponse.isSuccess = true;
        listResponse.failureReason = null;
        listResponse.references = branches;
        listResponse.dateTimeEpoch = DateTime.now().getTime();

        return JSON.serialize(listResponse);
    }

    public static String setupGitListFailureResponse(String failureReason) {
        VCServices.GitListResponse listResponse = new VCServices.GitListResponse();
        listResponse.isSuccess = false;
        listResponse.failureReason = failureReason;
        listResponse.dateTimeEpoch = DateTime.now().getTime();
        return JSON.serialize(listResponse);
    }

}
