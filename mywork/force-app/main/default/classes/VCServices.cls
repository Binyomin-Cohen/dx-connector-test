public with sharing class VCServices {
    public static final String SOAP_ENDPOINT = '/services/Soap/u/40.0';
    public static final String TOOL_STATUS_SCHEDULED = 'Scheduled';

    public static final String GIT_LIST_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + '/git-list';
    public static final String GIT_COMMIT_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + '/git-commit';
    public static final String GIT_REPO_SYNC_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + '/git-repo-sync';
    public static final String NO_REPOSITORY_URL_ERROR = 'The selected repository has an empty URL.';

    public static final String INVALID_PARAMETERS = 'Please make sure the Name and URL are valid.';
    public static final String NONEXISTING_REPOSITORY = 'Could not find an existing repository to update.';
    public static final String MALFORMATTED_REPOSITORY = 'The repository is not formatted correctly, please contact your administrator.';
    public static final String BAD_URL = 'The URL provided is not working. Please check the value entered is correct.';

    private static final Map<String, String> HTTP_ERROR_MESSAGE_SUBSTITUTIONS = new Map<String, String>{
        'org.eclipse.jgit.transport.TransportHttp cannot be cast to org.eclipse.jgit.transport.SshTransport' => BAD_URL,
        'org.eclipse.jgit.transport.TransportHttp incompatible with org.eclipse.jgit.transport.SshTransport' => BAD_URL
    };

    /**
    * Retrieves the branches, and optionally tags, for the given repository
    * @param userKeyOwnerId - The user ID of the keypair owner.
    * @param vcRepositoryId - The record ID of the VC repository to validate a connection to.
    * @param includeTags - determines whether to include tags in addition to branches.
    * @throws ALMException
    * @return - GitListResponse containing the branches, and optionally tags, from a repository
    */
    public static GitListResponse gitListBranches(Id userKeyOwnerId, Id vcRepositoryId, Boolean includeTags) {
        String publicKey = SSHServices.retrievePublicKey(userKeyOwnerId);
        String privateKey = SSHServices.retrievePrivateKey(userKeyOwnerId);
        String passphrase = SSHServices.retrievePassphrase(userKeyOwnerId);

        if (String.isBlank(publicKey) || String.isBlank(privateKey) || String.isBlank(passphrase)) {
            throw new ALMException(System.Label.VC_Keypair_Retrieval_Error);
        }

        List<VC_Repository__c> vcRepositories = [
            SELECT Repository_URL__c, Source_Format__c
            FROM VC_Repository__c
            WHERE Id = :vcRepositoryId
        ];

        if (vcRepositories.isEmpty()) {
            throw new ALMException(System.Label.VC_Repository_Retrieval_Error);
        }

        GitListRequest request = new GitListRequest(
            vcRepositories[0].Repository_URL__c,
            publicKey,
            privateKey,
            passphrase,
            includeTags
        );

        String serializedRequest = null;
        try {
            serializedRequest = JSON.serialize(request);
        } catch (Exception e) {
            throw new ALMException('Failed to serialize list request.');
        }

        Map<String, Object> optionsMap = new Map<String, Object>();
        optionsMap.put('timeout', 90 * 1000);

        String response = null;
        try {
            response = ALMRestServices.makeSensitiveHTTPRequest(
                ALMRestServices.RequestMethod.POST,
                GIT_LIST_ENDPOINT,
                null,
                serializedRequest,
                optionsMap,
                HTTP_ERROR_MESSAGE_SUBSTITUTIONS
            );
        } catch (Exception e) {
            if (e.getMessage() == System.Label.HTTP_Error && vcRepositories[0].Repository_URL__c.startsWith('https')) {
                throw new ALMException(BAD_URL);
            }
        }
        return (GitListResponse)JSON.deserialize(response, GitListResponse.class);
    }

    /**
    * Validates a Git connection using a stored SSH keypair and creates a VC_Repository_Validation__c record
    * @param userKeyOwnerId - The user ID of the keypair owner.
    * @param vcRepositoryId - The record ID of the VC repository to validate a connection to.
    * @return - The response of the attempted Git connection validation.
    */
    public static GitListResponse validateGitConnection(Id userKeyOwnerId, Id vcRepositoryId) {
        try {
            GitListResponse responseToReturn = gitListBranches(userKeyOwnerId, vcRepositoryId, false);
            createVCValidationRecord(vcRepositoryId, responseToReturn.failureReason,
                                     DateTime.newInstance(responseToReturn.dateTimeEpoch));
             return responseToReturn;
        } catch (Exception e) {
            if (e instanceof ALMException) {
                if (!e.getMessage().contains(System.Label.VC_Validation_Creation_Attempt_Error)) {
                    try {
                        createVCValidationRecord(vcRepositoryId, e.getMessage(), null );
                    } catch (ALMException attemptCreationException) {
                        throw new ALMException(e.getMessage() + ' ' + attemptCreationException.getMessage());
                    }
                }
                throw e;
            } else {
                    String genericExceptionMessageToStore = System.Label.VC_Connection_Validation_Error + ' Exception type: ' + e.getTypeName();
                    try {
                        createVCValidationRecord(vcRepositoryId, genericExceptionMessageToStore, null );
                    } catch (ALMException attemptCreationException) {
                        throw new ALMException(genericExceptionMessageToStore + ' ' + attemptCreationException.getMessage());
                    }
                throw new ALMException(genericExceptionMessageToStore);
            }
        }
    }

    /**
    * Makes a commit request to the web service.
    * @param vcCommit - object with required data for the commit request.
    * @return - The response to the commit request from the web service.
    */
    public static CommitResult makeCommitRequest(VC_Commit__c vcCommit) {
        Instances__c sightlineInstance = InstanceServices.almInstance;
        if (sightlineInstance == null) {
            throw new ALMException(System.Label.Sightline_Instance_Does_Not_Exist);
        }

        Auth_User__c sourceAuth = OAuthServices.getAuthUser(vcCommit.Source_Instance__c, false);
        Auth_User__c sightlineAuth = OAuthServices.getAuthUserForTools(sightlineInstance.Id);

        if (sourceAuth == null || sightlineAuth == null) {
            throw new ALMException('All required Auth_User__c records do not exist to make the commit request.');
        }
        // Reauthorize source and Sightline instances to ensure access tokens are up-to-date.
        List<Auth_User__c> reauthorizedUsers;
        try {
            reauthorizedUsers = new OAuthRequest().reauthorize(new List<Auth_User__c>{sourceAuth, sightlineAuth}, false);

            sourceAuth = reauthorizedUsers[0];
            sightlineAuth = reauthorizedUsers[1];
        } catch(Exception e) {
            throw new ALMException(e.getMessage());
        }

        if (!sourceAuth.Is_Refresh_Token_Valid__c || !sightlineAuth.Is_Refresh_Token_Valid__c) {
            throw new ALMException(System.Label.Instance_Auth_Invalid);
        }

        String body = JSON.serialize(new VCCommitRequest(vcCommit, sourceAuth));

        String response;
        try {
            response = ALMRestServices.makeSensitiveHTTPRequest(ALMRestServices.RequestMethod.POST,
                                                                GIT_COMMIT_ENDPOINT, null, body, null);
        } catch(ALMException ae) {
            throw new AssemblerException(ae.getMessage());
        }

        try {
            update new List<Auth_User__c>(new Set<Auth_User__c>(reauthorizedUsers));
        } catch (DMLException de) {
            throw new AssemblerException(System.Label.Generic_Error + de.getMessage());
        }

        CommitResult result;
        try {
            result =
             (CommitResult) JSON.deserialize(response, CommitResult.class);
        }
        catch(JSONException je) {
            throw new ALMException( System.Label.Generic_Error + ' \n'+ je.getMessage() );
        }

        vcCommit.Status__c =  result.result;
        vcCommit.UUID__c = result.jobId;
        vcCommit.Commit_Owner__c = vcCommit.CreatedBy.Username;
        try {
            update vcCommit;
        } catch (DMLException de) {
            throw new ALMException(System.Label.Generic_Error + de.getMessage());
        }

        return result;
    }


    /**
    * Makes a Repository Sync request to the web service.
    * @param List of ALM_Job__c ids to sync
    * @throws ALMException
    */
    @future (Callout=true)
    public static void syncRepositories(Set<Id> almJobIds) {
        List<ALM_Job__c> syncRepoJobs = [SELECT Id, VC_Repo__c, VC_Repo__r.Repository_URL__c,
                                                VC_Repo__r.Sync_Revisions_From__c, VC_Repo__r.Last_Sync_Date__c,
                                                CreatedById
                                         FROM ALM_Job__c
                                         WHERE Id in :almJobIds
                                         AND VC_Repo__c !=null
                                         AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.VC_REPO_SYNC)];

        // Get SSH Keys for creator of each ALM_Job__c.
        Map<Id, Map<String, String>> userIdToSSHDetails = getSSHDetailsForALMJobs(syncRepoJobs);

        // Get unique Repo details off of Jobs (repos could be duplicated across jobs)
        Map<Id, ALM_Job__c> repoIdToJob = new Map<Id, ALM_Job__c>();
        for (ALM_Job__c job : syncRepoJobs) {
            repoIdToJob.put(job.VC_Repo__c, job);
        }
        List<ALM_Job__c> jobs = repoIdToJob.values();

        List<VCRepoSyncRequest.VCRepoSyncDetails> reposToSync = buildVCRepoSyncDetailsList(jobs,  userIdToSSHDetails);
        try {
            String requestBody = buidVcRepoSyncRequest(reposToSync);

            String response = ALMRestServices.makeSensitiveHTTPRequest(ALMRestServices.RequestMethod.POST,
                                                                GIT_REPO_SYNC_ENDPOINT, null, requestBody, null);
            for (ALM_Job__c job : jobs) {
                job.Status__c = SCANServices.TOOL_STATUS_QUEUED;
            }

        } catch(ALMException ae) {

            ALMLogServices.error(ae, ALMLogServices.Application.VC);

            for (ALM_Job__c job : jobs) {
                ALMJobServices.markJobAsFailure(job, 'Repo Sync Request job failure');
            }
        }

        try{
            update jobs;
        }
        catch (DMLException de){
            ALMLogServices.error(de, ALMLogServices.Application.VC);
        }

    }

    private static Map<Id, Map<String, String>> getSSHDetailsForALMJobs(List<ALM_Job__c> syncRepoJobs){
        Map<Id, Map<String, String>> userIdToSSHDetails = new Map<Id, Map<String, String>>();
        for (Id userId : Pluck.ids('CreatedById', syncRepoJobs)) {
            userIdToSSHDetails.put(userId, SSHServices.retrieveKeysAndPassphrase(userId) );
        }
        return userIdToSSHDetails;

    }

    private static List<VCRepoSyncRequest.VCRepoSyncDetails> buildVCRepoSyncDetailsList(List<ALM_Job__c> jobs,
            Map<Id, Map<String, String>> userIdToSSHDetails) {

        List<VCRepoSyncRequest.VCRepoSyncDetails> reposToSync = new List<VCRepoSyncRequest.VCRepoSyncDetails>();
        for (ALM_Job__c job : jobs) {
            VC_Repository__c repo = job.VC_Repo__r;
            Datetime syncDateFrom = getLatestDateTime(repo.Last_Sync_Date__c, repo.Sync_Revisions_From__c);
            Map<String, String> sshDetails = userIdToSSHDetails.get(job.CreatedById);

            if (syncDateFrom != null) {
                reposToSync.add(
                        new VCRepoSyncRequest.VCRepoSyncDetails(job.Id, repo.Id, repo.Repository_URL__c,
                                syncDateFrom.getTime(), sshDetails.get('publicKey'),
                                sshDetails.get('privateKey'), sshDetails.get('passphrase'))
                );
            }

        }
        return reposToSync;
    }

    private static String buidVcRepoSyncRequest(List<VCRepoSyncRequest.VCRepoSyncDetails> reposToSync){
        Instances__c sightlineInstance = InstanceServices.almInstance;
        String orgId = UserInfo.getOrganizationId();

        OAuthServices.AppSettings settings = OAuthServices.getAppSettings();
        String clientId = settings.consumerKey;
        String clientSecret = settings.consumerSecret;

        Auth_User__c sightlineAuth = OAuthServices.getAuthUserForTools(sightlineInstance.Id);
        if (sightlineAuth == null) {
            throw new ALMException('Could not get auth user for tools');
        }
        // Reauthorize Sightline instance to ensure access token is up-to-date.
        // TODO: Pull refreshing into OAuthServices
        List<Auth_User__c> reauthorizedUsers;
        try {
            reauthorizedUsers = new OAuthRequest().reauthorize(new List<Auth_User__c>{sightlineAuth}, false);
            sightlineAuth = reauthorizedUsers[0];
        } catch(Exception e) {
            throw new ALMException(e.getMessage());
        }

        String requestBody = JSON.serialize(new VCRepoSyncRequest(clientId, clientSecret,
                sightlineAuth.Refresh_Token__c,
                sightlineAuth.Instance_URL__c, orgId, reposToSync));
        return requestBody;
    }

    private static Datetime getLatestDateTime(Datetime d1, Datetime d2) {
        if (d1 != null && d2 != null) {
            return (d2 > d1) ? d2 : d1;
        } else {
            return (d1 != null) ? d1 : d2;
        }
    }

    /**
    * Grab all existing vc repository records from the database.
    * @return - List of VCRepository objects translated from the VC_Repository__c records
    */
    public static List<VCRepository> getVCRepositories() {
        List<VCRepository> repositories = new List<VCRepository>();
        List<VC_Repository__c> existingRepos = [SELECT Id, Name, SFDC_Metadata_Path__c, Repository_URL__c, Host__c, 
                                                       Organization_Name__c, Sync_Revisions_From__c,
                                                       Enable_External_Commit_Link__c, Source_Format__c
                                                 FROM VC_Repository__c
                                                 ORDER BY Name ASC
                                                 LIMIT : LimitServices.getRemainingQueryRowsAvailable()];

        for (VC_Repository__c repo : existingRepos) {
            if (repo.Id != null && repo.Name != null && repo.Repository_URL__c != null) {
                repositories.add(new VCRepository( repo ));
            }
        }
        return repositories;
    }

    /**
    * Grab a vc repository record from the database.
    * @return - One VCRepository object translated from the VC_Repository__c records
    */
    public static VCRepository getVCRepository( String repoId ) {
        VCRepository repository;
        List<ALM_Job__c> jobs;

        List<VC_Repository__c> existingRepos = [SELECT Id, Name, SFDC_Metadata_Path__c, Repository_URL__c, Host__c,
                                                       Organization_Name__c, Sync_Revisions_From__c,
                                                       Enable_External_Commit_Link__c, Source_Format__c 
                                                FROM VC_Repository__c WHERE Id = :repoId LIMIT 1];
        if (!existingRepos.isEmpty()) {
	        VC_Repository__c repo = existingRepos[0];

	        jobs = [SELECT Id, Mail_To__c, Tool__c, Scheduled_Start_Time__c, Scheduled_End_Time__c,
	                       Scheduled_On_Monday__c, Scheduled_On_Tuesday__c, Scheduled_On_Wednesday__c,
	                       Scheduled_On_Thursday__c, Scheduled_On_Friday__c, Scheduled_On_Saturday__c,
	                       Scheduled_On_Sunday__c, Last_Queue_Time__c, Interval__c, Status__c,
	                       (SELECT Instance__c, Start_Time__c, Run_Time__c, Result__c, Error_Code__c, Duration__c
	                           FROM ALM_Application_Results__r
	                           WHERE Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.VC_REPO_SYNC)
	                           ORDER BY CreatedDate DESC LIMIT 10)
	                FROM ALM_Job__c
	                WHERE VC_Repo__c = :repo.id LIMIT 1];


	        if (repo.Id != null && repo.Name != null && repo.Repository_URL__c != null) {
	            repository = jobs.isEmpty() ? new VCRepository( repo ) :  new VCRepository( repo, jobs[0] );
	        }
        }

        return repository;
    }

    /**
    * Create or Update a VC Repository.
    * @param repoId - String value of repository id
    * @param repoName - String value of repository name
    * @param repoUrl - String value of repository url
    * @param repoHost - String value of repository host
    * @param repoOrgName - String value of repository host organization name
    * @param metadataPath - String value of repository SFDC metadata path
    * @return - The created/updated repository record translated to the VCRepository class
    * @throws ALMException
    */
    public static VCRepository upsertRepository(String repoId, String repoName, String repoUrl, String repoHost, String repoOrgName, String metadataPath) {
        if (String.isBlank(repoName) || String.isBlank(repoUrl)) {
            throw new ALMException(INVALID_PARAMETERS);
        }

        VC_Repository__c newRepo = new VC_Repository__c (
                Name = repoName,
                Host__c = repoHost,
                Organization_Name__c = repoOrgName,
                Repository_URL__c = repoUrl,
                SFDC_Metadata_Path__c = metadataPath
        );

        if (!String.isBlank(repoId)) {
            newRepo.Id = repoId;
        }

        try {
            upsert newRepo;
        } catch(DMLException de) {
            String dmlMessages = '';
            for(Integer i = 0; i < de.getNumDml(); i++){
                dmlMessages += de.getDmlMessage(i);
            }
            throw new ALMException(dmlMessages);
        }

        return new VCRepository(newRepo);
    }

    /**
    * Create or Update a VC Repository.
    * @param repoRepresentation - String representation of the vc repository record
    * @param repoName - String representation of the alm job record
    * @return - The created/updated repository record translated to the VCRepository class
    * @throws ALMException
    */
    public static VCRepository upsertRepositoryWithAlmJob(String repoRepresentation, Boolean destroyJob) {

        VCRepository newRepo;
        VCRepository repoToReturn;
        try {
            newRepo = (VCRepository) JSON.deserialize(repoRepresentation, VCRepository.class);
        } catch (System.JSONException jsonException) {
            throw new ALMException(MALFORMATTED_REPOSITORY);
        }
        VCRepository.AuraALMJob almJob = newRepo.job;

        VC_Repository__c vcRepoRecord = newRepo.getRepo();
        ALM_Job__c ALMJobRecord = almJob.getJob();
        if (String.isBlank(vcRepoRecord.Name) || String.isBlank(vcRepoRecord.Repository_URL__c)) {
            throw new ALMException(INVALID_PARAMETERS);
        }

        try {
            if( destroyJob ) {
               vcRepoRecord.Sync_Revisions_From__c = null;
               if (ALMJobRecord.id != null) {
                    delete ALMJobRecord;
                }
            }
            upsert vcRepoRecord;
            if( !destroyJob ) {
                ALMJobRecord.VC_Repo__c = vcRepoRecord.Id;
                upsert ALMJobRecord;
            }
            repoToReturn = getVCRepository( vcRepoRecord.Id );
        } catch(DMLException de) {
            String dmlMessages = '';
            for(Integer i = 0; i < de.getNumDml(); i++){
                dmlMessages += de.getDmlMessage(i);
            }
            throw new ALMException(dmlMessages);
        }

        return repoToReturn;
    }

  /**
  * Validates that repos being inserted or updated will not have names that duplicate existing repo names
  * @return repositories with names that duplicate existing ones
  */
    public static List<VC_Repository__c> validateRepoNamesForDuplicate( List<VC_Repository__c> newRepos) {

        List<VC_Repository__c> reposWithDuplicateNames = new List<VC_Repository__c>();
        Set<String> newNames = Pluck.strings(VC_Repository__c.Name, newRepos);

        List<VC_Repository__c> existingRepos = [SELECT Id, Name from VC_Repository__c where Name in :newNames];
        Set<String> existingNames = new Set<String>();
        for (VC_Repository__c existingRepo: existingRepos) {
            existingNames.add(existingRepo.Name.toLowerCase());
        }
        for (VC_Repository__c newRepo: newRepos) {
            if (newRepo.Name != null && !existingNames.add(newRepo.Name.toLowerCase())) {
                reposWithDuplicateNames.add(newRepo);
                newRepo.addError(System.Label.Duplicate_Repo_Name_Error + ' : ' + newRepo.Name);
            }
        }

        return reposWithDuplicateNames;

    }

    /**
    * Retrieve existing VC Repository Validation attempts for the current user for ALL repos.
    * @return - The validation attempts for the current user, mapped by repo id
    */
    public static List<VCRepository> loadVCReposWithValidationsForUser() {
        return loadVCReposWithValidationsForUser(null);
    }

    /**
    * Retrieve existing VC Repository Validation attempts for the current user for a specific or All repos.
    * @return - The validation attempts for the current user, mapped by repo id
    */
    public static List<VCRepository> loadVCReposWithValidationsForUser(Id repoId) {
        List<VCRepository> validationsWithReposToReturn = new List<VCRepository>();

        Id currentUserId = UserInfo.getUserId();
        String query = 'SELECT Id, Name, Repository_URL__c, Host__c, Organization_Name__c, Sync_Revisions_From__c,'
                        + ' Enable_External_Commit_Link__c, SFDC_Metadata_Path__c, Source_Format__c, '
                        + '(SELECT Id, SuccessfulValidation__c,'
                                         +'ValidationDate__c, ValidationError__c,'
                                         +'VC_Repository__c, ExternalID__c '
                                  +'FROM VC_Repository_Validations__r '
                                  +'WHERE CreatedById = :currentUserId) '
                        +'FROM VC_Repository__c ';
               query += repoId != null ? 'WHERE Id = :repoId':'';

        for (VC_Repository__c repo : Database.query(query)) {
            validationsWithReposToReturn.add(new VCRepository(repo, repo.VC_Repository_Validations__r));
        }

        return validationsWithReposToReturn;
    }

    /**
    * Create a VC Repository Validation record.
    * @param repoId - String value of repository id
    * @param error - The error received while validating the connection to the repo
    * @param attemptedDate - Date that the validation was attempted
    */
    private static void createVCValidationRecord(Id repoId, String error, DateTime attemptedDate ){
        try{
            if(String.IsNotBlank(error) && error.contains(System.Label.VC_Repository_Retrieval_Error)){
                //We don't have a repo to attach this validation attempt to, so we return.
                return;
            }
            VC_Repository_Validation__c validationAttempt = new VC_Repository_Validation__c();
            validationAttempt.SuccessfulValidation__c = String.IsBlank(error);
            validationAttempt.ValidationDate__c = attemptedDate == null ? DateTime.now() : attemptedDate;
            validationAttempt.ValidationError__c = error;
            validationAttempt.VC_Repository__c = repoId;
            validationAttempt.ExternalId__c = Userinfo.getUserId() + repoId;

            upsert validationAttempt ExternalId__c;
        }
        catch(DMLException dex){
            throw new ALMException(System.Label.VC_Validation_Creation_Attempt_Error);
        }
    }

    /**
     * Link the Backlog_Item__c field to the appropriate backlog item given the commit message
     * @param vcCommits : List of VC_Commit__c records before they are inserted into database
     */
    public static void linkBacklogItem(List<VC_Commit__c> vcCommits) {
        Map<String, List<VC_Commit__c>> backlogNamesToVCCommits = new Map<String, List<VC_Commit__c>>();

        for (VC_Commit__c vcCommit : vcCommits) {
            if (vcCommit.External_Commit__c) {
                String firstWord = parseBacklogItem(vcCommit.Commit_Message__c);
                if (!backlogNamesToVCCommits.containsKey(firstWord)) {
                    backlogNamesToVCCommits.put(firstWord, new List<VC_Commit__c>());
                }
                backlogNamesToVCCommits.get(firstWord).add(vcCommit);
            }
        }

        List<Backlog__c> backlogsFromVCCommits = [SELECT Id, Name
                                                  FROM Backlog__c
                                                  WHERE Name IN :backlogNamesToVCCommits.keySet()];
        Map<String, Id> backlogNamesToIds = new Map<String, Id>();

        for (Backlog__c backlogItem : backlogsFromVCCommits) {
            backlogNamesToIds.put(backlogItem.Name.toLowerCase(), backlogItem.Id);
        }

        for (String backlogName : backlogNamesToVCCommits.keySet()) {
            for(VC_Commit__c vcCommit : backlogNamesToVCCommits.get(backlogName)) {
                if (backlogNamesToIds.containsKey(backlogName) &&
                        String.isBlank(vcCommit.Backlog_Item__c) &&
                        vcCommit.External_Commit__c) {
                    vcCommit.Backlog_Item__c = backlogNamesToIds.get(backlogName);
                }
            }
        }
    }

    public static VC_Repository__c getVCRepoRecord( Id repoId ){
        List<VC_Repository__c> repos = [SELECT Id, Name, Source_Format__c FROM VC_Repository__c WHERE Id = :repoId];
        if (repos.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
               ApexPages.Severity.ERROR,
               System.Label.Generic_Error + ': Invalid Repository Item Id.'
            ));
            return null;
        }
        return repos[0];
    }

    public static String parseBacklogItem(String textField) {
        // TODO: Future implementations to improve parsing out the backlog item name with different patterns
        if (!String.isBlank(textField)) {
            String firstWord = textField.split('\\s+')[0].toLowerCase();
            return ( firstWord.contains('item') && firstWord.length() < 15 ) ? firstWord : '';
        }
        return '';
    }

    public class CommitResult {
        public String result;
        public String jobId;

        public CommitResult(String result, String jobId) {
            this.result = result;
            this.jobId = jobId;
        }
    }

    private class GitListRequest {
        public String orgId;
        public String repoUrl;
        public String publicKey;
        public String privateKey;
        public String passPhrase;
        public Boolean includeTags;

        public GitListRequest(String repositoryUrl, String publicKey, String privateKey, String passphrase,
                              Boolean includeTags) {
            this.orgId = UserInfo.getOrganizationId();
            this.repoUrl = repositoryUrl;
            this.publicKey = publicKey;
            this.privateKey = privateKey;
            this.passPhrase = passphrase;
            this.includeTags = includeTags;
        }

        public GitListRequest(String repositoryUrl, String publicKey, String privateKey, String passphrase) {
            this(repositoryUrl, publicKey, privateKey, passphrase, false);
        }
    }

    public class GitListResponse {
        public Boolean isSuccess;
        public String failureReason;
        public Long dateTimeEpoch;
        public List<String> references;
    }

}
