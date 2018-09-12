public with sharing class DeploymentRequest {

    private static final String DEPLOYMENT_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + '/deployments';
    private static final String ERROR_CODE_404 = '404';

    private Build__c build;
    private String targetInstanceId;
    public String buildId;
    public String almServerURL;
    public Map<String, String> deploymentOptions {get; set;}
    public Map<String, String> targetInstance {get; set;}
    public String packageURL;
    public String sightlineRefreshToken;
    public String clientId;
    public String clientSecret;
    public String validationId;
    public Deployment_Attempt__c deployment {get; set;}

    public DeploymentRequest(Build__c build, Deployment_Attempt__c attempt) {
        this.build = build;
        this.buildId = build.Id;
        this.almServerURL = URL.getSalesforceBaseUrl().toExternalForm();
        this.packageURL = (String.isNotBlank(build.Package_URL__c) && build.Package_URL__c.startsWith('/')) ? this.almServerURL + build.Package_URL__c : build.Package_URL__c;

        Auth_User__c sightlineAuthUser = OAuthServices.getSightlineAuthUser();
        try {
            this.sightlineRefreshToken = sightlineAuthUser.Refresh_Token__c;
        } catch(Exception e) {
            throw new ALMException(System.Label.Sightline_Instance_Not_Authorized);
        }

        OAuthServices.AppSettings settings = OAuthServices.getAppSettings();
        this.clientId = settings.consumerKey;
        this.clientSecret = settings.consumerSecret;

        this.deploymentOptions = new Map<String, String>{
            'isQuickDeploy' => String.valueOf(attempt.Is_Quick_Deploy__c),
            'isValidation' => String.valueOf(attempt.Is_Validation__c),
            'ignoreDeploymentWarnings' => String.valueOf(attempt.Ignore_Deployment_Warnings__c),
            'singlePackage' => 'true',
            'specifiedTests' => attempt.Specified_Tests__c,
            'testLevel' => attempt.Test_Level__c
        };
        this.deployment = attempt;

        if (attempt.Is_Quick_Deploy__c) {
            this.validationId = attempt.SF_Deployment_Id__c;
        }

        setTargetInstanceAuthInfo(attempt.Target_Instance__c, attempt.CreatedById);
    }

    /**
    * @param instanceId     the target instance id
    * @param userId         the user to retrieve the auth info for
    * @throws ALMException
    */
    public void setTargetInstanceAuthInfo(String instanceId, String userId) {
        targetInstanceId = instanceId;
        Instances__c instance = InstanceServices.getInstance(instanceId);

        if (instance == null) {
            throw new ALMException('Unable to find instance with Id: ' + instanceId);
        } else {
            Auth_User__c auth = OAuthServices.getAuthUser(instanceId, false, userId);
            if (auth == null) {
                throw new ALMException(System.Label.Generic_Error + '\nNo Auth User found for instance ['+ instanceId + '] and user [' + userId + ']');
            } else {
                this.targetInstance = new Map<String, String>{
                    'serverURL' => auth.Instance_URL__c,
                    'refreshToken' => auth.Refresh_Token__c
                };
            }
        }
    }

    /**
    * Make deployment request callout
    * @throws ALMException
    */
    public DeploymentCreateResponse send() {
        String endpoint = DEPLOYMENT_ENDPOINT + '/new';
        String body = JSON.serialize(this);

        String response;
        DeploymentCreateResponse deployResult;

        response = ALMRestServices.makePostRequest(endpoint, body);

        try {
            deployResult =
             (DeploymentCreateResponse) JSON.deserialize(response, DeploymentCreateResponse.class);
        }
        catch(JSONException je) {
            System.debug(je);
            throw new ALMException(je.getMessage());
        }

        return deployResult;
    }

    /**
    * @throws ALMException
    */
    public void sendCancelRequest() {
        String endpoint = DEPLOYMENT_ENDPOINT + '/cancel/' + deployment.UUID__c;
        String body = JSON.serialize(new CancelDeploymentRequest(almServerURL));

        // No need to handle response since we are just concerned with HTTP status
        ALMRestServices.makePostRequest(endpoint, body);
    }

    /**
    * Make deployment status callout and update SFDC record with result
    * @param jobUUID    The uuid of the deployment job
    * @return Deployment_Attempt__c  Deployment record with updated values - **note these values are not persisted.
    * @throws ALMException
    */
    public static Deployment_Attempt__c getJobStatus(String jobUUID) {
        String endpoint = DEPLOYMENT_ENDPOINT + '/' + jobUUID;

        String response;
        DeploymentStatusResponse parsedResponse;

        try {
            response = ALMRestServices.makeGetRequest(endpoint);
        } catch (AssemblerException e) {
          System.debug(e.getMessage());
          if (e.getMessage().contains(ERROR_CODE_404)) {
                throw new ALMException('Unable to get status for JOB UUID: ' + jobUUID);
            } else {
                throw new ALMException(e.getMessage());
            }
        }

        try {
            parsedResponse =
             (DeploymentStatusResponse) JSON.deserialize(response, DeploymentStatusResponse.class);
        }
        catch(JSONException je) {
            System.debug(je);
            throw new ALMException(je.getMessage());
        }

        return parsedResponse.getSObject();
    }

    private class CancelDeploymentRequest {
        public String sightlineRefreshToken;
        public String almServerURL;

        public CancelDeploymentRequest() {}

        public CancelDeploymentRequest(String url) {
            almServerURL = url;

            Auth_User__c sightlineAuthUser = OAuthServices.getSightlineAuthUser();
            try {
                this.sightlineRefreshToken = sightlineAuthUser.Refresh_Token__c;
            } catch(Exception e) {
                throw new ALMException(System.Label.Sightline_Instance_Not_Authorized);
            }
        }
    }

    public class DeploymentCreateResponse {
        public String result;
        public String jobId;
    }

    public class DeploymentStatusResponse {
        public String asyncRequestId;
        public String jobId;
        public String status;
        public String startTime;
        public String endTime;
        public Integer numberComponentsDeployed;
        public Integer numberComponentsTotal;
        public Integer numberComponentErrors;
        public Integer numberTestErrors;
        public Integer numberTestsCompleted;
        public Integer numberTestsTotal;
        public String stateDetail;

        public Deployment_Attempt__c getSObject() {
            Deployment_Attempt__c record = new Deployment_Attempt__c();

            record.SF_Deployment_Id__c = asyncRequestId;
            record.Status__c = status;
            record.State_Detail__c = stateDetail;
            record.UUID__c = jobId;
            record.Number_Components_Deployed__c = numberComponentsDeployed;
            record.Number_Components_Errors__c = numberComponentErrors;
            record.Number_Components_Total__c = numberComponentsTotal;
            record.Number_Test_Errors__c = numberTestErrors;
            record.Number_Tests_Completed__c = numberTestsCompleted;
            record.Number_Tests_Total__c = numberTestsTotal;

            return record;
        }
    }
}