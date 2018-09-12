public with sharing class JenkinsServices {
    public static final String PATH_DELIMITER = '/';
    public static final String BUILD_PATH = 'build?token=';
    public static final String DEPLOY_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + '/jenkins/deployment';
    public static final String GENERATE_PACKAGE_PATH = 'assembler/generatePackage';
    public static final String GENERATE_PACKAGE_ENDPOINT = ALMRestServices.WEB_SERVICE_URL +
                                        ( ALMRestServices.WEB_SERVICE_URL.endsWith(PATH_DELIMITER) ?
                                          GENERATE_PACKAGE_PATH : PATH_DELIMITER + GENERATE_PACKAGE_PATH );

    public static final String CRUMB_PATH = 'crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)';

    public static final String CONFIG_ERROR = 'Invalid Jenkins configuration.';
    public static final String CRUMB_ERROR = 'Cannot retrieve valid CSRF crumb from Jenkins server.';
    public static final String PACKAGE_ERROR = 'Cannot find a valid build package.';

    public static final String JENKINS_BUILD_NEW_STATUS = 'NEW';
    public static final String JENKINS_BUILD_PENDING_STATUS = 'PENDING';
    public static final String JENKINS_BUILD_FAILURE_STATUS = 'FAILURE';
    public static final String JENKINS_BUILD_IN_PROGRESS_STATUS = 'IN PROGRESS';
    public static final String JENKINS_BUILD_SUCCESS_STATUS = 'SUCCESS';
    public static final String JENKINS_SF_BUILD_IN_PROGRESS_STATUS = 'Creating SF Build Package';

    // delete
    public static final String NO_PREVIOUS_SUCCESSFUL_PACKAGE_ERROR =
        'No package XML was found for the selected build. Please select a different build.';

    public static final String PACKAGE_FILE_NAME = 'package.zip';
    public static final String ATTACHMENT_FILE_PREFIX = 'package_';

    /**
    * Creates the required Jenkins_Build__c and Build__c records
    * @param jenkinsJobId
    * @param previousSuccessfulBuildId
    * @return Id of the created Jenkins_Build__c
    * @throws ALMException, DMLException
    */
    public static Id setupBuildRecords(String jenkinsJobId, String previousSuccessfulBuildId) {
        Jenkins_Job__c existingJob = getExistingJob(jenkinsJobId);

        // TODO: move into controller
        if (!evaluateBuildRule(existingJob)) {
            throw new ALMException(System.Label.Jenkins_Failing_Build_Rule_Msg);
        }

        Jenkins_Build__c jBuild = new Jenkins_Build__c(Jenkins_Job__c=jenkinsJobId,
                                                       CI_Instance__c = existingJob.CI_Instance__c,
                                                       Status__c=JENKINS_BUILD_NEW_STATUS);

        if (String.isNotBlank(previousSuccessfulBuildId)) {
            Jenkins_Build__c reusedBuild;
            try {
                // a QueryException will be thrown if no results are returned.
                reusedBuild = [SELECT Package_URL__c FROM Jenkins_Build__c WHERE Id=:previousSuccessfulBuildId];
            } catch (Exception e) {
                throw new ALMException(System.Label.Jenkins_Job_Error_Invalid_Reused_Build);
            }

            if (String.isBlank(reusedBuild.Package_URL__c)) {
                throw new ALMException(System.Label.Jenkins_Job_Error_Invalid_Reused_Build);
            }
            jBuild.Reused_Build__c = previousSuccessfulBuildId;
            jBuild.Package_URL__c = reusedBuild.Package_URL__c;
            insert jBuild;
        } else if (String.isNotBlank(existingJob.Source_Repository__c)) {
            if (String.isBlank(existingJob.Source_Repository_Location__c)) {
                throw new ALMException(System.Label.Jenkins_Job_Missing_Resource_Location_Error);
            }
            insert jBuild;
            insert new Build__c(Jenkins_Build__c=jBuild.Id,
                                Source_Repository__c=existingJob.Source_Repository__c,
                                Source_Repository_Location__c=existingJob.Source_Repository_Location__c,
                                Status__c=BuildServices.STATUS_NOT_STARTED,
                                Target__c=existingJob.CI_Instance__r.Target_Instance__c,
                                Release__c=existingJob.Release__c);
        } else {
            throw new ALMException(System.Label.Jenkins_Build_Error_No_Repo_Or_Reused_Build);
        }
        return jBuild.Id;
    }

    private static String delimitPath(String path) {
        return path.endsWith(PATH_DELIMITER) ? path : path + PATH_DELIMITER;
    }

    /**
    * Runs the Assembler Jenkins job corresponding to the provided job ID
    * @param jenkinsBuild: The jenkins build record to track the job. Must have the Jenkins_Job__c and Name defined
    * @throws ALMException
    */
    public static Jenkins_Build__c startAssemblerJob(Id jenkinsBuildId) {
        Jenkins_Build__c jBuild = getJenkinsBuild(jenkinsBuildId);
        if (jBuild == null) {
            throw new ALMException(System.Label.Generic_Error + ': Jenkins build is undefined');
        }

        Build__c build;
        if (jBuild.Builds__r.isEmpty()) {
            throw new ALMException(System.Label.Generic_Error + ': build is undefined');
        } else {
            build = jBuild.Builds__r[0];
        }

        // Verify Jenkins config is valid
        Jenkins_Config__c jenkinsConfig = Jenkins_Config__c.getInstance();
        if (jenkinsConfig == null || String.isBlank(jenkinsConfig.Endpoint__c)) {
            throw new ALMException(CONFIG_ERROR);
        }

        Id targetInstanceId = jBuild.Jenkins_Job__r.CI_Instance__r.Target_Instance__c;
        AssemblerServices.BuildResult buildResult;
        try {
            buildResult = AssemblerServices.makeJenkinsAssembleRequest(build, targetInstanceId, false);
            build.Status__c = buildResult.result;
            build.UUID__c = buildResult.jobId;
            jBuild.Status__c = JENKINS_SF_BUILD_IN_PROGRESS_STATUS;
        } catch (AssemblerException e) {
            String errorMessage;

            if (AssemblerServices.ERROR_MISSING_AUTH_USERS.equals(e.getMessage())) {
                errorMessage = System.Label.Sightline_Instance_Not_Authorized_For_Assembler;
            } else {
                ALMLogServices.error(e, ALMLogServices.Application.JENKINS);
                errorMessage = e.getMessage();
            }

            jBuild.Status_Details__c = errorMessage == null ? errorMessage : errorMessage.abbreviate(255);
            jBuild.Status__c = JENKINS_BUILD_FAILURE_STATUS;
            build.Status__c = BuildServices.STATUS_FAILURE;
        }

        try {
            update jBuild;
            update build;
        } catch (System.DmlException de) {
            ALMLogServices.error(de, ALMLogServices.Application.JENKINS);
            throw new ALMException(de.getMessage());
        }
        return jBuild;
    }

    @future(Callout=true)
    public static void deployBuildPackage(Id jenkinsBuildId) {
        Jenkins_Build__c jBuild = getJenkinsBuild(jenkinsBuildId);
        if (jBuild.Status__c == JENKINS_BUILD_FAILURE_STATUS) {
            //build has already been marked as a failure. Nothing to do.
            //TODO: should we prevent the future method from even being called?
            return;
        }

        try {
            Jenkins_Config__c jenkinsConfig = Jenkins_Config__c.getInstance();
            Map<String, String> headerMap = generateHeaderMap(jenkinsConfig);

            JenkinsStartJobRequest deployJenkinsJob = new JenkinsStartJobRequest(
                    jBuild.Name, jBuild.Jenkins_Job__r.Token__c,
                    jBuild.Jenkins_Job__r.Path__c, jBuild.Package_URL__c);

            String requestStatus = ALMRestServices.makePostRequest(DEPLOY_ENDPOINT, Json.serialize(deployJenkinsJob));

            updateJenkinsBuildStatuses(jBuild, JENKINS_BUILD_PENDING_STATUS, jBuild.Status_Details__c);
        } catch (Exception e) {
            updateJenkinsBuildStatuses(jBuild, JENKINS_BUILD_FAILURE_STATUS, e.getMessage());
            return;
        }

        if ( !ExecuteJenkinsBuildbatchServices.isMonitorBatchScheduledOrRunning() ) {
            scheduleJenkinsMonitorBatchJob();
        }

    }


    /**
    * Updates the statuses of the Jenkins Builds. Logs Errors instead of throwing an Exception
    */
    public static void updateJenkinsBuildStatuses(List<Jenkins_Build__c> jBuilds, String status, String statusDetails) {
        for (Jenkins_Build__c jbuild : jbuilds) {
            jBuild.Status__c = status;
            jBuild.Status_Details__c = statusDetails == null ? statusDetails : statusDetails.abbreviate(255);
        }

        try {
            SObjectServices.updateSObjectsAllowingPartialSuccess(jBuilds);
        } catch (ALMException e) {
            ALMLogServices.error(e, ALMLogServices.Application.JENKINS);
        }
    }

    /**
    * Updates the statuses of the Jenkins Build. Logs Errors instead of throwing an Exception
    */
    public static void updateJenkinsBuildStatuses(Jenkins_Build__c jBuild, String status, String statusDetails) {
        updateJenkinsBuildStatuses(new List<Jenkins_Build__c>{jbuild}, status, statusDetails);
    }

    /**
    * Returns the Jenkins Build for the provided Id, as well as the most recently created child Build__c
    * @param jenkinsBuildId     The Id of the Jenkins_Build__c record to query
    * @return Jenkins_Build__c with one child Build__c object.
    */
    public static Jenkins_Build__c getJenkinsBuild(Id jenkinsBuildId) {
        List<Jenkins_Build__c> jenkinsBuilds = [SELECT Jenkins_Job__r.Release__c, Jenkins_Job__r.Path__c,
                                                    Jenkins_Job__r.CI_Instance__c, Jenkins_Job__r.CI_Instance__r.Target_Instance__c,
                                                    Jenkins_Job__r.Id, Jenkins_Job__r.Token__c, Jenkins_Job__r.Name,
                                                    Name, Status__c, Status_Details__c, Package_URL__c,
                                                        (SELECT Id, Name, Status__c, UUID__c, Release__c, Package_URL__c, Manual_Upload__c,
                                                         Source_Repository__c, Source_Repository_Location__c, Jenkins_Build__c
                                                         FROM Builds__r ORDER BY createdDate DESC LIMIT 1)
                                                FROM Jenkins_Build__c WHERE Id = :jenkinsBuildId];
        // TODO: Should throw exception here.
        return jenkinsBuilds.isEmpty() ? null : jenkinsBuilds[0];
    }

    /**
    * Gets the build rule criteria as a set of field names
    * @param job     The job to find build rule criteria for. job.Build_Rule__r must be defined
    * @return a Set of field names from the CI_Instance__c that need to evaluate to true
    */
    public static Set<String> getExistingBuildRuleCriteria(Jenkins_Job__c job) {
        Set<String> existingCriteria =  new Set<String>();

        if (job.Build_Rule__c != null && String.isNotEmpty(job.Build_Rule__r.Boolean_Criteria__c)) {
            existingCriteria =  new Set<String>(
                job.Build_Rule__r.Boolean_Criteria__c.split(BuildRuleExt.CRITERIA_DELIMITER)
            );
        }

        return existingCriteria;
    }

    /**
    * @throws AuraHandledException
    */
    public static Jenkins_Job__c getExistingJob(String jenkinsJobId) {
        List<Jenkins_Job__c> existingJobs = [SELECT Build_Rule__c, CI_Instance__c, Build_Rule__r.Boolean_Criteria__c,
                                                Source_Repository__c, Source_Repository_Location__c,
                                                CI_Instance__r.Target_Instance__c, Release__c
                                             FROM Jenkins_Job__c WHERE Id = :jenkinsJobId];
        if (existingJobs.isEmpty()) {
            throw new AuraHandledException('Unable to find Jenkins Job with Id ' + jenkinsJobId);
        }

        return existingJobs[0];
    }

    /**
    * @param job     The job to evaluate the build rule criteria for. job.Build_Rule__r and
    *                job.CI_Instance__c must be defined
    * @return a map of criteria to their values. { CI_Instance__c field name => evaluation }
    */
    public static Map<String, Boolean> getBuildRuleCriteriaEvaluations(Jenkins_Job__c job) {
        Map<String, Boolean> criteriaEvaluation =  new Map<String, Boolean>();

        Set<String> existingCriteria = getExistingBuildRuleCriteria(job);

        if (existingCriteria.isEmpty()) {
            return criteriaEvaluation;
        }

        String instanceId = job.CI_Instance__c;

        String query = 'SELECT ' + String.join(new List<String>(existingCriteria), ', ');
        query += ' FROM ' + SObjectServices.getFullyQualifiedName('CI_Instance__c');
        query += ' WHERE Id = :instanceId';

        CI_Instance__c ciInstance;
        try {
            List<CI_Instance__c> instances = Database.query(query);
            if (!instances.isEmpty()) {
                ciInstance = instances[0];
            }
        } catch (Exception ex) {
            ALMLogServices.error(ex, ALMLogServices.Application.JENKINS);
        }

        if (ciInstance == null) {
            return criteriaEvaluation;
        }

        for (String criteria : existingCriteria) {
            try {
                criteriaEvaluation.put(criteria, (Boolean)ciInstance.get(criteria));
            } catch (Exception ex) {
                //skip any invalid fields
                ALMLogServices.error(ex, ALMLogServices.Application.JENKINS);
            }
        }

        return criteriaEvaluation;
    }

    /**
    * @param job     The job to evaluate the build rule criteria for. job.Build_Rule__r and
    *                job.CI_Instance__c must be defined
    * @return true if all criteria are met
    */
    public static Boolean evaluateBuildRule(Jenkins_Job__c job) {
        Boolean isBuildRuleSatisfied = true;
        for (Boolean evaluation : getBuildRuleCriteriaEvaluations(job).values()) {
            isBuildRuleSatisfied = (isBuildRuleSatisfied && evaluation);
        }

        return isBuildRuleSatisfied;
    }

    /**
    * Gets the manifest from the release with the given release ID.
    * @param releaseId: The ID of the release from which a manifest should be retrieved.
    * @return: A list of components in the manifest of the given release.
    */
    private static List<AssemblerManifestRecord> getManifest(Id releaseId) {
        List<AssemblerManifestRecord> releaseManifest = AssemblerServices.getManifest(releaseId);
        for (ProfileManifestRecord profile : AssemblerServices.getDocumentedProfiles(releaseId)) {
            releaseManifest.add((AssemblerManifestRecord)profile);
        }

        return releaseManifest;
    }

    /**
    * Initializes a header for a Jenkins server request, including CSRF crumb retrieval from the server for subsequent requests using the header.
    * @param jenkinsConfig: The configuration of the Jenkins server to initialize a header for.
    * @return: An HTTP header ready to be sent to the Jenkins server corresponding to the given configuration.
    * @throws ALMException
    */
    private static Map<String, String> initializeRequestHeader(Jenkins_Config__c jenkinsConfig) {
        if (jenkinsConfig == null) {
            throw new ALMException(CONFIG_ERROR);
        }

        Map<String, String> headerMap = generateHeaderMap(jenkinsConfig);
        String crumb = generateJenkinsCrumb(jenkinsConfig, headerMap);

        if (String.isBlank(crumb)) {
            throw new ALMException(CRUMB_ERROR);
        }

        List<String> splitCrumb = crumb.split(':');

        if (splitCrumb.size() != 2 || String.isBlank(splitCrumb[0]) || String.isBlank(splitCrumb[1])) {
            throw new ALMException(CRUMB_ERROR);
        }

        headerMap.put(splitCrumb[0], splitCrumb[1]);

        return headerMap;
    }

    private static Map<String, String> generateHeaderMap(Jenkins_Config__c jenkinsConfig) {
        Map<String, String> headerMap = new Map<String, String>();
        headerMap.put('Authorization', 'Basic ' + EncodingUtil.base64Encode(
                Blob.valueOf(jenkinsConfig.User_ID__c + ':' + jenkinsConfig.User_API_Token__c)));

        return headerMap;
    }

    private static String generateJenkinsCrumb(Jenkins_Config__c jenkinsConfig, Map<String, String> headerMap) {
        String endpoint =
            jenkinsConfig.Endpoint__c.endsWith(PATH_DELIMITER) ?
            jenkinsConfig.Endpoint__c :
            jenkinsConfig.Endpoint__c + PATH_DELIMITER;

        return ALMRestServices.makeGetRequest(endpoint + CRUMB_PATH, headerMap);
    }

    /**
    * Creates the body of a multipart/form-data media type (see IETF RFC 7578) HTTP request for a Jenkins build package.
    * @param headerMap: A map of request headers to be sent with the build package.
    * @param packageContent: The content of the build package to be sent to Jenkins.
    * @param buildName: a unique identifier for the build
    * @return: A Blob representing the content of the HTTP request containing the Jenkins build package.
    */
    private static Blob createMultipartForm(Map<String, String> headerMap, Blob packageContent, String buildName) {
        final String boundaryPaddingCharacter = '*';
        final Integer boundaryPaddingWidth = 12;
        final String boundary =
            boundaryPaddingCharacter.repeat(boundaryPaddingWidth) +
            String.valueOf(Crypto.getRandomLong()) +
            boundaryPaddingCharacter.repeat(boundaryPaddingWidth);

        headerMap.put('Content-Type', 'multipart/form-data; boundary=' + boundary);

        String buildIdParam = '{"name" :"buildId", "value" : "' +buildName + '"}';
        String body = '--' + boundary + '\r\n';

        // The package contents.
        body += 'Content-Disposition: form-data; name="package"; filename="' + PACKAGE_FILE_NAME + '"\r\n';

//TODO: jenkins seems to ignore the content transfer encoding
//          In this implementation, jenkins will store the base64 encoded file contents as the zip file which is not what we want
//        body += 'Content-Transfer-Encoding: base64\r\n';
        body += 'Content-Type: application/octet-stream\r\n';
        body += '\r\n' + EncodingUtil.base64Encode(packageContent) + '\r\n';

        body += '--' + boundary + '\r\n';

        // Mapping the package contents to the build parameter.
        body += 'Content-Disposition: form-data; name="json"\r\n';
        body += '\r\n{"parameter":[{"name":"packages/' + PACKAGE_FILE_NAME + '", "file":"package"}, ' + buildIdParam + ']}\r\n';

        body += '--' + boundary + '--';

        return Blob.valueOf(body);
    }

    private static void scheduleJenkinsMonitorBatchJob() {
        Integer minutesFromNow = 2;
        DateTime scheduledTime = DateTime.now().addMinutes(minutesFromNow);

        String cronExpression =
            scheduledTime.second() + ' ' +
            scheduledTime.minute() + ' ' +
            scheduledTime.hour() + ' ' +
            scheduledTime.day() + ' ' +
            scheduledTime.month() + ' ? ' +
            scheduledTime.year();

        System.schedule(JenkinsBuildBatchJob.BATCH_JOB_TITLE, cronExpression, new JenkinsBuildBatchJob());
    }

    /**
    * update the jenkins build status with the status value
    * @param jenkinsBuild: The jenkins build record to track the job.
    * @param status: The Status values whic needs to be updated.
    * @throws ALMException
    */
    public static void updateJenkinsBuildStatus(Jenkins_Build__c jenkinsBuild, String status){
        if(jenkinsBuild != null){
            jenkinsBuild.Status__c = status;
            try{
                update jenkinsBuild;
            } catch (DMLException de) {
                ALMLogServices.error(de, ALMLogServices.Application.JENKINS);
            }
        }
    }
}
