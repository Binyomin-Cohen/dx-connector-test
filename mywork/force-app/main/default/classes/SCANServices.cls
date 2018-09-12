public with sharing class SCANServices {
    public static final String TOOL_STATUS_SCHEDULED = 'Scheduled';
    public static final String TOOL_STATUS_ON_HOLD = 'On Hold';
    public static final String TOOL_STATUS_RUNNING = 'Running';
    public static final String TOOL_STATUS_QUEUED = 'Queued';

    public static final String SCHED_JOB_NAME_1 = 'Scheduled ALM Instance SCAN 1';
    public static final String SCHED_JOB_NAME_2 = 'Scheduled ALM Instance SCAN 2';
    public static final String SCHED_JOB_CRON_EXP_1 = '0 0 * * * ?';
    public static final String SCHED_JOB_CRON_EXP_2 = '0 30 * * * ?';

    public static final String SCAN_JOB_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + '/scan-job';
    public static final String SOAP_ENDPOINT = '/services/Soap/u/34.0';

    public static final String SUCCESS_STATUS = 'Success';
    public static final String SUCCESS_WITH_WARNINGS_STATUS = 'Success With Warnings';
    public static final String FAILURE_STATUS = 'Failure';
    public static final Set<String> SUCCESS_STATUSES = new Set<String>{SUCCESS_STATUS.toLowerCase(), SUCCESS_WITH_WARNINGS_STATUS.toLowerCase()};

    public static SCANJobRequest createScanJobRequest(Set<Id> jobIds, Map<Id, Auth_User__c> authInfo, Map<Id, ALM_Application_Result__c> jobIdToLatestApplicationResult) {

        List<ALM_Job__c> jobsWithValidAuths = new List<ALM_Job__c>();

        for (ALM_Job__c job : getJobs(jobIds)) {
            if (authInfo.containsKey(job.Source_Instance__c)
                && authInfo.get(job.Source_Instance__c).Is_Refresh_Token_Valid__c
                && authInfo.containsKey(job.Target_Instance__c)
                && authInfo.get(job.Target_Instance__c).Is_Refresh_Token_Valid__c) {
                jobsWithValidAuths.add(job);
            }
        }

        return new SCANJobRequest(jobsWithValidAuths, authInfo, jobIdToLatestApplicationResult);
    }

    /**
    * Ensures that all access tokens are valid for the referenced jobs. If they are not
    * valid, they will be refreshed. NOTE - callouts will be made in order to do this.
    * @params jobIds -  Set of ALM_Job__c ids to reauthorize
    * @return Map<Id, Auth_User__c> -  Map of Instance Id => Auth_User__c
    * @throws ALMException, DMLException
    */
    public static Map<Id, Auth_User__c> reauthorizeJobs(Set<Id> jobIds) {

        Map<Id, Auth_User__c> authInfo = getAuthInfo( getJobs(jobIds) );
        Map<Id, Auth_User__c> uniqueAuths = new Map<Id, Auth_User__c>();

        for(Auth_User__c user : authInfo.values()) {
            uniqueAuths.put(user.Id, user);
        }

        OAuthRequest request = new OAuthRequest();
        List<Auth_User__c> refreshedAuths = request.reauthorize(uniqueAuths.values(), false);

        Map<Id, Auth_User__c> instanceIdToAuth = new Map<Id, Auth_User__c>();
        for (Auth_User__c auth : refreshedAuths) {
            instanceIdToAuth.put(auth.Instance__c, auth);
        }

        return instanceIdToAuth;
    }

    public static List<CronJobDetail> getCronJobDetails() {
        return [
            SELECT Id, Name
            FROM CronJobDetail
            WHERE Name IN (:SCHED_JOB_NAME_1, :SCHED_JOB_NAME_2)
        ];
    }
    /**
    * Ensures that a schedule exists for the SCAN batch jobs. Creates the schedules if
    * they are not found
    */
    public static void ensureScanJobSchedulesExist() {
        List<CronJobDetail> scheduledJobs = getCronJobDetails();

        if(scheduledJobs.size() != 2) {
            Set<String> schedNames = new Set<String>();
            for(CronJobDetail currSched : scheduledJobs) {
                schedNames.add(currSched.Name);
            }

            if(!schedNames.contains(SCHED_JOB_NAME_1)) {
                System.schedule(
                    SCHED_JOB_NAME_1,
                    SCHED_JOB_CRON_EXP_1,
                    new ScanScheduler()
                );
            }
            if(!schedNames.contains(SCHED_JOB_NAME_2)) {
                System.schedule(
                    SCHED_JOB_NAME_2,
                    SCHED_JOB_CRON_EXP_2,
                    new ScanScheduler()
                );
            }
        }
    }

    private static void failAllJobsAndResultsWithMessage(Map<Id, ALM_Application_Result__c> jobIdToLatestApplicationResult,
                                                         String message,
                                                         List<ALM_Job__c> jobsToFail,
                                                         List<ALM_Application_Result__c> resultsToFail) {
        for(Id jobId : jobIdToLatestApplicationResult.keySet()){
            ALM_Job__c job = new ALM_Job__c(Id = jobId);
            ALM_Application_Result__c resultToFail = jobIdToLatestApplicationResult.get(jobId);
            populateJobsAndResultsToFail(job, resultToFail, jobsToFail, resultsToFail, message);
        }
    }
    /**
    * Makes a SCAN job request to put the given job IDs into the queue
    * @param Set<Id> scanJobIds
    */
    @future(Callout=true)
    public static void sendScanJobRequest(Set<Id> scanJobIds) {
        List<ALM_Job__c> jobsToFail = new List<ALM_Job__c>();
        List<ALM_Application_Result__c> resultsToFail = new List<ALM_Application_Result__c>();
        OAuthRequest authRequest = new OAuthRequest();

        Auth_User__c sightlineAuthUser = OAuthServices.getSightlineAuthUser() == null
                                        ? null
                                        : authRequest.reauthorize(new List<Auth_User__c>{OAuthServices.getSightlineAuthUser()}, false)[0];

        Map<Id, Auth_User__c> instanceToAuthUser = reauthorizeJobs(scanJobIds);

        Map<Id, ALM_Application_Result__c> jobIdToLatestApplicationResult = ALMApplicationResultServices.getLatestInProgressApplicationResultForJobs(scanJobIds);
        if( sightlineAuthUser == null || sightlineAuthUser.Is_Refresh_Token_Valid__c == false ) {
            failAllJobsAndResultsWithMessage(jobIdToLatestApplicationResult, System.Label.Sightline_Instance_Not_Authorized, jobsToFail, resultsToFail);
        } else {
            SCANJobRequest request = createScanJobRequest(scanJobIds, instanceToAuthUser, jobIdToLatestApplicationResult);

            if (!request.jobs.isEmpty()) {
                String requestBody = JSON.serialize(request);
                try {
                    ALMRestServices.makePostRequest(SCAN_JOB_ENDPOINT, requestBody);
                } catch(Exception ex) {
                    ALMLogServices.error(ex, ALMLogServices.Application.SCAN);
                    failAllJobsAndResultsWithMessage(jobIdToLatestApplicationResult, System.Label.Unable_To_Connect_To_Sightline_Server_Error, jobsToFail, resultsToFail);
                }
            }

            List<ALM_Job__c> allJobsRequiredForInstanceId = [
                SELECT Id, Source_Instance__c
                FROM ALM_Job__c
                WHERE Id in :scanJobIds
            ];

            for(ALM_Job__c job : allJobsRequiredForInstanceId) {
                if(instanceToAuthUser.containsKey(job.Source_Instance__c)
                   && instanceToAuthUser.get(job.Source_Instance__c).Is_Refresh_Token_Valid__c == false) {
                        ALM_Application_Result__c resultToFail = jobIdToLatestApplicationResult.get(job.Id);
                        populateJobsAndResultsToFail(job, resultToFail, jobsToFail, resultsToFail, System.Label.Instance_Auth_Invalid);
                   }
            }
        }
        System.Savepoint sp = Database.setSavePoint();
        try{
            update resultsToFail;
            update jobsToFail;
            update instanceToAuthUser.values();
        } catch(DMLException de) {
            Database.rollBack(sp);
            ALMLogServices.error(de, ALMLogServices.Application.SCAN);
        }

    }

    /*
    *  Marks a job and an application result as failure and adds each to their corresponding list
    *  @param ALM_Job__c Job
    *  @param ALM_Application_Result__c resultToFail
    *  @param List<ALM_Job__c> jobsToFail
    *  @param List<ALM_Application_Result__c> resultsToFail
    *  @param String errorMessage
    */
    private static void populateJobsAndResultsToFail(ALM_Job__c job, ALM_Application_Result__c resultToFail,
                                                    List<ALM_Job__c> jobsToFail, List<ALM_Application_Result__c> resultsToFail,
                                                    String errorMessage){
        ALMJobServices.markJobAsFailure(job, errorMessage);
        jobsToFail.add(job);
        if(resultToFail != null) {
            ALMApplicationResultServices.markResultAsFailure(resultToFail, errorMessage);
            resultsToFail.add(resultToFail);
        }
    }
    /*
    *  @return Map instanceId => Auth_User__c
    */
    private static Map<Id, Auth_User__c> getAuthInfo(List<ALM_Job__c> jobs) {
        Set<String> instanceIds = Pluck.strings( ALM_Job__c.Source_Instance__c, jobs );
        instanceIds.addAll(Pluck.strings( ALM_Job__c.Target_Instance__c, jobs ) );

        return OAuthServices.getAuthUsersForTools(instanceIds);
    }

    private static List<ALM_Job__c> getJobs(Set<Id> jobIds) {
         return [
            SELECT Id, Components__c, Max_Package_Size__c, Sync_Descriptions__c, Include_Profiles__c, Excluded_Types__c,
             Include_Permission_Sets__c, Source_Instance__c, Target_Instance__c, Source_Instance__r.Name, Mail_To__c
            FROM ALM_Job__c
            WHERE Id IN :jobIds
        ];
    }

    /**
    * Returns the SCAN job for a given source instance
    * @param Id sourceInstanceId
    * @return ALM_Job__c
    * @throws ALMException
    */
    public static ALM_Job__c getScanJobForInstance(Id sourceInstanceId) {
        if(String.isBlank(sourceInstanceId)) {
            throw new ALMException('Instance ID cannot be empty.');
        }

        List<ALM_Job__c> scanJobs = [
            select  Id,
                    Status__c, Source_Instance__c, Target_Instance__c, Last_Queue_Time__c, Last_Run_Time__c,
                    Scheduled_On_Monday__c, Scheduled_On_Tuesday__c, Scheduled_On_Wednesday__c, Scheduled_On_Thursday__c,
                    Scheduled_On_Friday__c, Scheduled_On_Saturday__c, Scheduled_On_Sunday__c, Scheduled_Start_Time__c,
                    Scheduled_End_Time__c, Tool__c, Interval__c, Mail_To__c
            from ALM_Job__c
            where Source_Instance__c = :sourceInstanceId
            and Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN)
        ];

        // Verify there was only a single job for this instance
        if(scanJobs.size() > 1) {
            throw new ALMException('Multiple SCAN jobs found for this source instance ID.');
        }

        return scanJobs.isEmpty() ? null : scanJobs[0];
    }


    public class SCANJobRequest {

        public List<SCANJob> jobs;
        public String orgId;

        public SCANJobRequest(List<ALM_Job__c> jobs, Map<Id, Auth_User__c> authInfo, Map<Id, ALM_Application_Result__c> jobIdToLatestApplicationResult) {
            this.orgId = UserInfo.getOrganizationId();
            this.jobs = new List<SCANJob>();

            for (ALM_Job__c job : jobs) {
                ALM_Application_Result__c result = jobIdToLatestApplicationResult.get(job.Id);
                this.jobs.add( new SCANJob(job, authInfo.get(job.Source_Instance__c), authInfo.get(job.Target_Instance__c), result != null ? result.Id : null) );
            }
        }
    }

    public class SCANJob {

        public String jobId;
        public String clientId;
        public String clientSecret;
        public String sourceInstanceId;
        public String sourceInstanceName;
        public String accountName;
        public String components;
        public String excludedTypes;
        public String sourceRefreshToken;
        public String sourceEndpoint;
        public String targetRefreshToken;
        public String targetEndpoint;
        public String currentApplicationResultId;
        public Integer maxPackageSize;
        public Boolean syncDescriptions;
        public Boolean includeProfiles;
        public Boolean includePermissionSets;

        public SCANJob(ALM_Job__c job, Auth_User__c source, Auth_User__c target, Id currentApplicationResultId) {
            this.accountName = UserInfo.getOrganizationName();
            this.jobId = job.Id;
            this.sourceInstanceId = job.Source_Instance__c;
            this.components = job.Components__c;
            this.excludedTypes = job.Excluded_Types__c;
            this.maxPackageSize = (job.Max_Package_Size__c == null) ? null : job.Max_Package_Size__c.intValue();
            this.syncDescriptions = job.Sync_Descriptions__c;
            this.includeProfiles = job.Include_Profiles__c;
            this.includePermissionSets = job.Include_Permission_Sets__c;
            this.sourceInstanceName = job.Source_Instance__r.Name;

            OAuthServices.AppSettings almPrivateSettings = OAuthServices.getAppSettings();
            this.clientId = almPrivateSettings.consumerKey;
            this.clientSecret = almPrivateSettings.consumerSecret;

            if (source == null) {
                throw new ALMException('The source Auth_User__c cannot be null for a SCAN Job');
            } else if (target == null) {
                throw new ALMException('The target Auth_User__c cannot be null for a SCAN Job');
            }

            setSourceAuth(source);
            setTargetAuth(target);

            this.currentApplicationResultId = currentApplicationResultId;
        }

        public void setSourceAuth(Auth_User__c source) {
            this.sourceRefreshToken = source.Refresh_Token__c;
            this.sourceEndpoint = source.Instance_URL__c + SOAP_ENDPOINT;
        }

        public void setTargetAuth(Auth_User__c target) {
            this.targetRefreshToken = target.Refresh_Token__c;
            this.targetEndpoint = target.Instance_URL__c + SOAP_ENDPOINT;
        }
    }

}