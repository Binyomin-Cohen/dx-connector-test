@isTest
global class MockWebAssemblerAPI implements HttpCalloutMock {

    public static final Integer REVISION_NUMBER = 1;
    public static final String COMMIT_DATE = '2014-06-26T16:05:37+0000';
    public static final Datetime COMMIT_DATE_AS_DATETIME = DateTime.newInstance(2014, 6, 26, 12, 5, 37);
    public static final String FAILURE_REASON = 'fatal error';
    public static final String INSTANCE_1 = 'dev';
    public static final String INSTANCE_2 = 'QA';
    public static final String STATUS_RESULT = 'Pending';
    public static final String STATUS_SUCCESS = 'Success';
    public static final String LONG_EXCEPTION_MESSAGE = 'a'.repeat(260);

    public static final String JOB_ID = '395f2eaa-9137-4faa-a1cd-3bc140e5edc2';
    public static final String ASYNC_ID = '0Afi000000JqpL1CAJ';

    public static final String ASSEMBLE_EXCEPTION_ACTION = 'assembler-exception-action';
    public static final String ASSEMBLE_GET_ACTION = '/assemble/' + JOB_ID;
    public static final String ASSEMBLE_GET_FAILED_ACTION = '/assemble/fail' + JOB_ID;
    public static final String ASSEMBLE_GET_RESPONSE = '\'{\' "status" : "{0}", "jobId": "{1}", "failureReason" : {2} \'}\'';
    public static final String ASSEMBLE_GET_SUCCESS_RESPONSE
        = String.format(ASSEMBLE_GET_RESPONSE, new List<String>{STATUS_RESULT, JOB_ID, 'null'});
    public static final String ASSEMBLE_GET_FAILED_RESPONSE
        = String.format(ASSEMBLE_GET_RESPONSE, new List<String>{STATUS_RESULT, JOB_ID, '"' + FAILURE_REASON + '"'});
    public static final String ASSEMBLE_ACTION = '/assemble';
    public static final String VC_ASSEMBLE_ACTION = '/assembler/assembleFromGit';
    public static final String ASSEMBLE_FAILURE_ACTION = '/assemblefail';

    public static final String DEPLOYMENTS_ACTION = '/deployments/new';
    public static final String DEPLOYMENTS_SUCCESS_RESPONSE = String.format('\'{\' "result" : "{0}", "jobId": "{1}" \'}\'', new List<String>{STATUS_RESULT, JOB_ID});

    public static final String GET_DEPLOYMENT_ACTION = '/deployments/' + JOB_ID;
    public static final String DEPLOY_RESULT_SUCCESS_STATUS = 'Succeeded';
    public static final Integer COMPONENT_COUNT = 2;

    public static final String PARSE_BUILD_PACKAGE_ACTION = '/assembler/parsePackage';
    public static final String PARSE_BUILD_PACKAGE_FAIL_ACTION = '/assembler/fail/parsePackage';
    public static final String PARSE_BUILD_PACKAGE_BAD_RESPONSE = '/assembler/bad/parsePackage';
    public static final List<List<String>> BUILD_PACKAGE_COMPONENTS = new List<List<String>>{
            new List<String> { 'Admin', 'Profile', '' },
            new List<String> { 'VCServices', 'Apex Class', '' },
            new List<String> { 'VCServices', 'Apex Trigger', '' },
            new List<String> { 'TestVCServices', 'Apex Class', '' },
            new List<String> { 'FieldComponent', 'Field', 'ParentComponent'},
            new List<String> { 'FieldComponent', 'Field', 'SecondParentComponent'},
            new List<String> { 'NonExistent', 'WorkFlow', ''} };

    public static final String GIT_COMMIT_SUCCESS_ACTION = '/git-commit/success';

    public static final String INSTANCES_ACTION = '/instances';
    public static final String INSTANCES_SUCCESS_RESPONSE = String.format('["{0}","{1}"]', new List<String>{INSTANCE_1, INSTANCE_2});
    public static final String SNAPSHOTS_ACTION = '/snapshots';
    public static final String SNAPSHOTS_SUCCESS_RESPONSE =
        String.format('\'{\' "hasMore" : true, "lastRevision": 1, "revisions" : [\'{\'"revision":{0},"commitDate":"2014-06-24T00:16:46+0000", "notes":""\'}\',' +
                      '\'{\'"revision":1,"commitDate":"{1}","notes":""\'}\']\'}\'',
        new List<String>{String.valueOf(REVISION_NUMBER), COMMIT_DATE});
    public static final String DEPLOYMENTS_CANCEL_ACTION = '/deployments/cancel';
    public static final String LOG_ACTION = '/alm-log';

    public static final String JENKINS_DEPLOY_ACTION = '/jenkins/deployment';
    public static final String JENKINS_DEPLOY_FAILURE_ACTION = '/jenkinsfail/deployment';

    public static Boolean jenkinsDeployRequestWasMade = false;
    public static Boolean assembleRequestWasMade = false;
    public String requestBody;

    private String action;

    public MockWebAssemblerAPI(String action) {
        this.action = action;
    }

    global HttpResponse respond(HttpRequest request) {
        this.requestBody = request.getBody();

        HttpResponse response = new HttpResponse();

        if (action == DEPLOYMENTS_ACTION || action == ASSEMBLE_ACTION) {
            assembleRequestWasMade = true;
            response = getSuccessfulResponse( DEPLOYMENTS_SUCCESS_RESPONSE );
        } else if (action == ASSEMBLE_GET_ACTION) {
            response = getSuccessfulResponse( ASSEMBLE_GET_SUCCESS_RESPONSE );
        } else if (action == ASSEMBLE_GET_FAILED_ACTION) {
            response = getSuccessfulResponse( ASSEMBLE_GET_FAILED_RESPONSE );
        } else if (action == ASSEMBLE_FAILURE_ACTION) {
            response = new HttpResponse();
            response.setBody('<html fail');
            response.setStatusCode(500);
            response.setHeader('Content-Type', 'application/json');
        } else if (action == GET_DEPLOYMENT_ACTION) {
            response = getSuccessfulResponse( getDeploymentSuccessResponse() );
        } else if (action == PARSE_BUILD_PACKAGE_ACTION) {
            response = getSuccessfulResponse( getParsePackageSuccessResponse() );
        } else if (action == PARSE_BUILD_PACKAGE_FAIL_ACTION) {
            response = getBadRequestResponse(FAILURE_REASON);
        } else if (action == PARSE_BUILD_PACKAGE_BAD_RESPONSE) {
            response = getSuccessfulResponse('{\"fail\"}');
        } else if (action == GIT_COMMIT_SUCCESS_ACTION) {
            response = getSuccessfulResponse(getGitCommitSuccessResponse( request ));
        } else if (action == JENKINS_DEPLOY_ACTION) {
            // After a successful Deploy, Monitor batch schedule will run and ping the Jenkins Server.
            if (request.getEndpoint().contains(JenkinsBuildBatchJob.JENKINS_ULR_PARAMTER)) {
                response = getSuccessfulResponse('<xml></xml>');
            } else if (request.getEndpoint().contains(JenkinsServices.DEPLOY_ENDPOINT)) {
                jenkinsDeployRequestWasMade = true;
                response = getSuccessfulResponse(getJenkinsDeploySuccessResponse( request ));
            } else {
                response = getBadRequestResponse('Unexpected Endpoint');
            }
        } else if (action == JENKINS_DEPLOY_FAILURE_ACTION) {
            response = getBadRequestResponse(FAILURE_REASON);
        } else if (action == INSTANCES_ACTION) {
            response = getSuccessfulResponse( INSTANCES_SUCCESS_RESPONSE );
        } else if (action == SNAPSHOTS_ACTION) {
            response = getSuccessfulResponse( SNAPSHOTS_SUCCESS_RESPONSE );
        } else if (action == DEPLOYMENTS_CANCEL_ACTION) {
            // No response body required
            response.setStatusCode(ALMRestServices.HTTP_OK);
            response.setBody('');
        } else if (action == LOG_ACTION) {
            response.setStatusCode(ALMRestServices.HTTP_OK);
            response.setBody('');
        } else if (action == VC_ASSEMBLE_ACTION) {
            response = getSuccessfulResponse( DEPLOYMENTS_SUCCESS_RESPONSE );
        } else if (action == ASSEMBLE_EXCEPTION_ACTION) {
            throw new AssemblerException(LONG_EXCEPTION_MESSAGE);
        }

        String status = ALMRestServices.HTTP_CODES_TO_STATUSES.get(response.getStatusCode());
        response.setStatus(status != null ? status : '');
        return response;
    }

    private HttpResponse getSuccessfulResponse(String body) {
        HttpResponse response = new HttpResponse();
        response.setBody(body);
        response.setStatusCode(ALMRestServices.HTTP_OK);
        response.setHeader('Content-Type', 'application/json');

        return response;
    }

    private HttpResponse getBadRequestResponse(String body) {
        HttpResponse response = new HttpResponse();
        response.setBody(body);
        response.setStatusCode(ALMRestServices.HTTP_BAD_REQUEST);
        response.setHeader('Content-Type', 'application/json');

        return response;
    }


    private String getDeploymentSuccessResponse() {

        return  String.format('\'{\' "id" :13,' +
            '"jobId":"{0}",' +
            '"asyncRequestId":"{3}",' +
            '"buildId":"a09o00000082DUSAA2",' +
            '"status":"{1}",' +
            '"packageURL":"https://c.na17.visual.force.com/servlet/servlet.FileDownload?file=00Po0000002AaxuEAC",' +
            '"startTime":1428950870000,' +
            '"endTime":1428950884000,' +
            '"isValidation":true,' +
            '"runTests":false,' +
            '"runManagedTests":false,' +
            '"numberComponentsDeployed": {2},' +
            '"numberComponentsTotal": {2},' +
            '"numberComponentErrors":0,' +
            '"numberTestErrors":0,' +
            '"numberTestsCompleted":0,' +
            '"numberTestsTotal":0,' +
            '"runTestsEnabled":false,' +
            '"stateDetail":null \'}\' ',
              new List<String>{JOB_ID, DEPLOY_RESULT_SUCCESS_STATUS, String.valueOf(COMPONENT_COUNT), ASYNC_ID});
    }

    private String getGitCommitSuccessResponse(HttpRequest request) {
        if (request.getEndpoint().equals(VCServices.GIT_COMMIT_ENDPOINT)) {

            return String.format('\'{\' "result" : "{0}", "jobId": "{1}" \'}\'',
                                 new List<String>{STATUS_RESULT, JOB_ID});

        } else {
            // generic response for non-git-related callouts
            return String.format('\'{\' "result" : "{0}" \'}\'',
                    new List<String>{STATUS_RESULT});
        }
    }

    private String getJenkinsDeploySuccessResponse(HttpRequest request) {
        if (request.getEndpoint().equals(JENKINS_DEPLOY_ACTION)) {
            return String.format('\'{\' "result" : "{0}" \'}\'',
                    new List<String>{JenkinsServices.JENKINS_BUILD_SUCCESS_STATUS});
        } else {
            return '';
        }
    }

    private String getParsePackageSuccessResponse() {
        String componentDetails = '';
        for (Integer k = 0; k < BUILD_PACKAGE_COMPONENTS.size(); k++) {
            componentDetails += '[\"' + BUILD_PACKAGE_COMPONENTS[k][0] + '\",\"' + 
                                        BUILD_PACKAGE_COMPONENTS[k][1] + '\",\"' + 
                                        BUILD_PACKAGE_COMPONENTS[k][2] + '\"]';
            if ( k != (BUILD_PACKAGE_COMPONENTS.size() - 1) ) {
                componentDetails += ',';
            }
        }
        return '{\"isSuccess\" : true,' +
                '\"failureReason\" : \"\",' +
                '\"components\": [' +
                    componentDetails + 
                ']}';
    }
    public Boolean shouldSkipTargetBackup() {
        return this.requestBody.contains('"skipTargetBackup":true');
    } 
}
