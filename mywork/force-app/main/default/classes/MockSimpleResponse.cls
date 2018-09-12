public class MockSimpleResponse implements HttpCalloutMock {
    private Integer mockResponseStatusCode;
    private String mockResponseBody;

    public MockSimpleResponse(Integer mockResponseStatusCode, String mockResponseBody) {
        this.mockResponseStatusCode = mockResponseStatusCode;
        this.mockResponseBody = mockResponseBody;
    }

    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setBody(this.mockResponseBody);
        response.setStatusCode(this.mockResponseStatusCode);

        String status = ALMRestServices.HTTP_CODES_TO_STATUSES.get(response.getStatusCode());
        response.setStatus(status != null ? status : '');

        return response;
    }
}