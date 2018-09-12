@isTest
public class MockJenkinsAPI implements HttpCalloutMock {
    public Boolean generatePackageEndpointWasCalled = false;

    public final String JENKINS_JOB_STATUS_SUCCESS = 'SUCCESS';
    public final String JENKINS_JOB_STATUS_FAILURE = 'FAILURE';
    public final String JENKINS_JOB_PATH_NOT_FOUND_ERROR = 'HTTP 404 (Not Found) Problem accessing';

    public final String expectedJobPath;
    public final String actualJobPath;
    public final String expectedJobToken;
    public final String expectedPackageContent;
    public final String expectedPackageJson;
    public final String expectedJenkinsJobStatus;

    public HttpResponse response;

    public MockJenkinsAPI(String expectedJobPath, String expectedJobToken) {
        this.response = new HttpResponse();
        this.expectedJobPath = expectedJobPath;
        this.expectedJobToken = expectedJobToken;
        this.expectedJenkinsJobStatus = JENKINS_JOB_STATUS_SUCCESS;
    }

    public MockJenkinsAPI(String expectedJobPath, String expectedJobToken, String actualJobPath) {
        this(expectedJobPath, expectedJobToken);
        this.actualJobPath = actualJobPath;
    }

    public MockJenkinsAPI(String expectedJobPath, String expectedJobToken, String expectedPackageContent, String expectedPackageJson) {
        this(expectedJobPath, expectedJobToken);
        this.response = new HttpResponse();
        this.expectedPackageContent = expectedPackageContent;
        this.expectedPackageJson = expectedPackageJson;
    }
    //Constructor to create appropriate Jenkins Response for build
    public MockJenkinsAPI(String expectedJenkinsJobStatus ){
        this.response = new HttpResponse();
    	this.expectedJenkinsJobStatus=expectedJenkinsJobStatus;
    }

    public HttpResponse respond(HttpRequest request) {
        String endpoint = request.getEndpoint();
        if (endpoint.contains(JenkinsServices.BUILD_PATH)) {
            // Request is building a job.
            if (!endpoint.contains(this.expectedJobPath)) {
                // Request contains an invalid job path.
                response.setStatusCode(ALMRestServices.HTTP_NOT_FOUND);
                response.setBody(JENKINS_JOB_PATH_NOT_FOUND_ERROR
                 + (actualJobPath != null? actualJobPath: '') );
            } else if (!endpoint.contains(this.expectedJobToken)) {
                // Request contains an invalid job token.
                response.setStatusCode(ALMRestServices.HTTP_FORBIDDEN);
                response.setBody('HTTP 403 (Forbidden) Invalid token provided');
            } else {
                // Request is routed properly.
                String contentType = request.getHeader('Content-Type');
                if (!String.isBlank(contentType) && contentType.startsWith('multipart/form-data;')) {
                    // Request is a form containing a package for a parameterized build.

                    // Split request body on the randomly-generated boundaries.
                    String boundaryRegex = contentType.substringAfterLast('boundary=').replace('*', '\\*');
                    List<String> splitBody = request.getBody().split('--' + boundaryRegex);

                    // Ensure that the proper pieces of content exist within the request body.
                    Boolean foundPackageContent = false;
                    Boolean foundPackageJson = false;
                    Boolean foundOther = false;
                    for (String bodyPart : splitBody) {
                        if (!String.isBlank(bodyPart) && !bodyPart.equals('--')) {
                            if (bodyPart.equals(expectedPackageContent)) {
                                foundPackageContent = true;
                            } else if (bodyPart.equals(expectedPackageJson)) {
                                foundPackageJson = true;
                            } else {
                                foundOther = true;
                            }
                        }
                    }

                    if (foundPackageContent && foundPackageJson && !foundOther) {
                        response.setStatusCode(ALMRestServices.HTTP_CREATED);
                    } else {
                        response.setStatusCode(ALMRestServices.HTTP_BAD_REQUEST);
                    }
                } else {
                    response.setStatusCode(ALMRestServices.HTTP_CREATED);
                }
            }
        } else if (endpoint.contains(JenkinsServices.GENERATE_PACKAGE_ENDPOINT)) {
            generatePackageEndpointWasCalled = true;
            GeneratePackageRequest packageRequest =
                (GeneratePackageRequest)JSON.deserialize(request.getBody(), GeneratePackageRequest.class);

            List<String> componentNames = new List<String>();
            for (Integer i = 1; i < packageRequest.components.size(); ++i) {
                componentNames.add(packageRequest.components[i][0]);
            }

            response.setStatusCode(ALMRestServices.HTTP_OK);
            response.setBody(String.join(componentNames, ','));
        } else if(endpoint.contains(System.label.Jenkins_Build_Status_URL)){
        	response.setStatusCode(ALMRestServices.HTTP_OK);
        	response.setBody((expectedJenkinsJobStatus == JENKINS_JOB_STATUS_SUCCESS) ?
                                    '<parametername><build><result>SUCCESS</result></build></parametername>' :
                                    '<parametername><build><result>FAILURE</result></build></parametername>');
        }

        String status = ALMRestServices.HTTP_CODES_TO_STATUSES.get(response.getStatusCode());
        response.setStatus(status != null ? status : '');

        return response;
    }
}
