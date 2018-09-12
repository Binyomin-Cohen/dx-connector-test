public with sharing class SlingshotControllerExt2 extends OAuthController {

    public static final Integer ERROR_CHUNK_SIZE = 1000;

    public static final String ERROR_BUILD_ALREADY_STARTED = 'Build is already in-progress.';
    public static final String ERROR_INVALID_VC_DEPLOY_PARAMS_MESSAGE =
                                    'Invalid repository or branch data was submitted';

    public static final String SRC_INSTANCE_STATE_PARAM = 'src_instance_id';
    public static final String TGT_INSTANCE_STATE_PARAM = 'tgt_instance_id';
    public static final String DEPLOYMENT_STATE_PARAM = 'deployment_id';

    public static final String INVALID_BUILD_ID_ERROR = 'An invalid build id was provided.';

    @TestVisible
    private static final String PAGE_STATE_TOKEN = 'PageState Slingshot';

    public transient DeploymentErrorsModel deploymentErrors {get; set;}
    public transient List<DeploymentSource> availableSources {get; set;}
    public transient Integer instancesCount {get; set;}
    public transient Integer reposCount {get; set;}
    public transient String availableTestClasses {get; set;}

    public String selectedDeploymentId {get; set;}

    public String sourceInstanceId {get; set;}
    public String targetInstanceId {get; set;}

    public Boolean hasSaveErrors {get; private set;}
    public Boolean ignoreDeploymentWarnings {get; set;}
    public Boolean backupTarget {get; set;}
    public Boolean isQuickDeploy {get; set;}
    public Boolean isValidation {get; set;}
    public Boolean userHasPermissions {get; set;}
    public Boolean rebuildPackageFromSource {get; set;}
    public String testLevel {get; set;}

    public ALMPageMessages pageMessageManager {get; private set;}
    public String pageMessageToRemove {get; set;}
    public Boolean isAuthValid {get; set;}

    public Release__c release {get; private set;}
    public Build__c build {get { return assembler.build; } }
    public String buildId {
        get { return build.Id; }
    }

    public Deployment__c deployment {get; set;}
    public Assembler assembler {get; set;}

    public String serializedClientDataBundle {get; set;}

    // TRUE if we are currently saving due to validate/deploy
    public Boolean validateDeployInProgress {get; set;}

    // TRUE if slingshot should be shown. False if there are errors on page load
    public Boolean displaySlingshot { get; set; }

    public Boolean isDeploymentSettingsChanged {get; set;}

    public String specifiedTestClasses {get; set;}

    public String staleManifestCheckTime {
        get {
            if(assembler.staleManifestCheckTime != null) {
                return assembler.staleManifestCheckTime.format();
            }
            return '';
        }
    }

    public SlingshotControllerExt2(ApexPages.StandardController sc) {
        if (!Test.isRunningTest()) {
            sc.addFields(new List<String> {
                'Name'
            });
        }

        isForTools = false;

        displaySlingshot = true;
        validateDeployInProgress = false;
        ignoreDeploymentWarnings = false;
        backupTarget = true;
        isQuickDeploy = false;
        isValidation = true;
        testLevel = DeploymentModel.DEFAULT_TEST_LEVEL;
        rebuildPackageFromSource = true;
        isAuthValid = true;

        pageMessageManager = new ALMPageMessages();

        SlingshotPermissions permissions = new SlingshotPermissions();
        userHasPermissions = permissions.hasPermission() == PermissionServices.PermissionLevel.FULL;

        try {

            this.release = (Release__c)sc.getRecord();

            if(this.release.Id == null) {
                throw new ALMException('You must specify a release to use Slingshot');
            }

            loadAvailableDeploymentSources();
            loadDeployment();

            restorePageState();
        } catch(Exception e) {
            this.displaySlingshot = false;
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                System.Label.Generic_Error + ': ' + e.getMessage()
            ));
        }
    }

    public void loadDeployment() {
        if (String.isBlank(selectedDeploymentId)) {
            initNewDeployment();
        } else {
            deployment = [
                SELECT  Id, Build__c, Completed_Build__c, Completed_Build__r.Source__c, Completed_Build__r.Target__c, Completed_Build__r.Package_URL__c,
                 Name, Source__c, Target__c, Deployment_Attempt__c, Deployment_Attempt__r.SF_Deployment_Id__c, Deployment_Attempt__r.Specified_Tests__c, Release__c
                FROM Deployment__c
                WHERE Id = :selectedDeploymentId
            ];
        }
        if (String.isBlank(deployment.Build__c)) {
            assembler = new Assembler(release.Id);
        } else {
            assembler = new Assembler(release.Id, getBuild(deployment.Build__c));
        }

        sourceInstanceId = deployment.Source__c;
        targetInstanceId = deployment.Target__c;
        getDeploymentErrors();
        assembler.checkManifestIsStale();
        setIsDeploymentSettingsChanged();
        if (!String.isBlank(deployment.Deployment_Attempt__c)) {
            specifiedTestClasses = deployment.Deployment_Attempt__r.Specified_Tests__c;
        }
    }

    private void initNewDeployment() {
        deployment = new Deployment__c(
            Release__c = release.Id
        );
    }

    private ClientDataBundle getClientDataBundle() {
        return (ClientDataBundle)JSON.deserialize(serializedClientDataBundle, ClientDataBundle.class);
    }

    public override Map<String, String> getState() {
        Instances__c sourceInstance = InstanceServices.getInstance(sourceInstanceId);
        Instances__c targetInstance = InstanceServices.getInstance(targetInstanceId);
        Instances__c selectedInstance = (selectedInstanceId == sourceInstanceId) ? sourceInstance : targetInstance;

        Map<String,String> state = super.getState();

        if (sourceInstance != null) {
            state.put(SRC_INSTANCE_STATE_PARAM, sourceInstanceId);
        }

        if (targetInstance != null) {
            state.put(TGT_INSTANCE_STATE_PARAM, targetInstanceId);
        }

        if (String.isNotBlank(deployment.Id)) {
            state.put(DEPLOYMENT_STATE_PARAM, deployment.Id);
        }

        return state;
    }

    public override void loadState(Map<String, Object> stateMap) {
        if (stateMap.containsKey(DEPLOYMENT_STATE_PARAM)) {
            selectedDeploymentId = (String)stateMap.get(DEPLOYMENT_STATE_PARAM);
            loadDeployment();
        }
    }

    public void loadManifest() {
        assembler.loadManifest();
    }

    public void getDeploymentErrors() {
        List<ALM_Error__c> buildErrors  = new List<ALM_Error__c>();
        List<ALM_Error__c> apexErrors = new List<ALM_Error__c>();
        List<ALM_Error__c> componentErrors = new List<ALM_Error__c>();
        List<ALM_Error__c> codeCoverageErrors = new List<ALM_Error__c>();

        if (!String.isEmpty(deployment.Completed_Build__c)) {
            buildErrors = ALMErrorServices.getBuildErrors(deployment.Completed_Build__c);
        } else if(!String.isEmpty(deployment.Build__c)) {
            buildErrors = ALMErrorServices.getBuildErrors(deployment.Build__c);
        }

        if (!String.isEmpty(deployment.Deployment_Attempt__c)) {
            apexErrors = ALMErrorServices.getApexErrors(deployment.Deployment_Attempt__c);
            componentErrors = ALMErrorServices.getComponentErrors(deployment.Deployment_Attempt__c);
            codeCoverageErrors = ALMErrorServices.getCodeCoverageErrors(deployment.Deployment_Attempt__c);
        }

        deploymentErrors = new DeploymentErrorsModel(buildErrors, apexErrors, componentErrors, codeCoverageErrors);
    }

    public List<List<ALM_Error__c>> getChunkedBuildErrors() {
        return chunkList(deploymentErrors.buildErrors, ERROR_CHUNK_SIZE);
    }

    public List<List<ALM_Error__c>> getChunkedComponentErrors() {
        return chunkList(deploymentErrors.componentErrors, ERROR_CHUNK_SIZE);
    }

    public List<List<ALM_Error__c>> getChunkedApexErrors() {
        return chunkList(deploymentErrors.apexErrors, ERROR_CHUNK_SIZE);
    }

    public List<List<ALM_Error__c>> getChunkedCodeCoverageErrors() {
        return chunkList(deploymentErrors.codeCoverageErrors, ERROR_CHUNK_SIZE);
    }

    @TestVisible
    private List<List<ALM_Error__c>> chunkList(List<ALM_Error__c> elements, Integer chunkSize) {
        List<List<ALM_Error__c>> chunks = new List<List<ALM_Error__c>>();

        if (elements != null) {
            Integer fromIndex = 0;
            Integer toIndex = 0;

            while (fromIndex < elements.size()) {
               List<ALM_Error__c> chunk = new List<ALM_Error__c>();

               if (toIndex + chunkSize > elements.size()) {
                   toIndex = elements.size();
               } else {
                   toIndex += chunkSize;
               }
               for(Integer i = fromIndex; i < toIndex; i++) {
                   chunk.add(elements[i]);
               }
               chunks.add( chunk );
               fromIndex += chunkSize;
            }
        }

        return chunks;
    }

    private Boolean validateDeploymentName() {
        return validateDeploymentName(null);
    }

    @TestVisible
    private Boolean validateDeploymentName(Id deploymentId) {
        ClientDataBundle dataBundle = getClientDataBundle();
        if(String.isBlank(dataBundle.deployName)) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, 'Deployment name cannot be blank.')
            );
            hasSaveErrors = true;
            return false;
        }
        String releaseId = release.Id;
        String deployName = dataBundle.deployName;
        List<Deployment__c> existingDeployments = [Select ID from Deployment__c where Release__c = :releaseId and Name = :deployName];
        if (existingDeployments.size() > 0 && existingDeployments[0].Id != deploymentId) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, 'A deployment with that name already exists.')
            );
            hasSaveErrors = true;
            return false;
        }
        return true;
    }

    public void saveAsDeployment() {
        if (validateDeploymentName()) {
          deployment = deployment.clone(false, true);
          assembler.cloneManifest();
          this.saveDeployment();
        }
    }

    private Boolean areMultipleControllersSavingSameDeployment() {
        Deployment__c latestVersionOfDeployment = null;
        if (!String.isBlank(deployment.Id)) {
            try {
                latestVersionOfDeployment = [
                        SELECT  Id, Build__c, Completed_Build__c, Completed_Build__r.Source__c, Completed_Build__r.Target__c, Completed_Build__r.Package_URL__c,
                        Name, Source__c, Target__c, Deployment_Attempt__c, Deployment_Attempt__r.SF_Deployment_Id__c, Deployment_Attempt__r.Specified_Tests__c, Release__c
                        FROM Deployment__c
                        WHERE Id = :deployment.Id
                        FOR UPDATE
                    ];
            } catch (Exception e) {
                return true;
            }

            if ( deployment.Build__c != latestVersionOfDeployment.Build__c || deployment.Completed_Build__c != latestVersionOfDeployment.Completed_Build__c) {
                return true;
            }
        }
        return false;
    }

    public void saveDeployment() {
        if(areMultipleControllersSavingSameDeployment()) {
            hasSaveErrors = true;
            Apexpages.addMessage(new Apexpages.Message(ApexPages.Severity.ERROR, Label.CURRENTLY_IN_PROGRESS));
            return;
        }
        else {
            hasSaveErrors = false;
        }

        ClientDataBundle dataBundle = getClientDataBundle();

        sourceInstanceId = dataBundle.sourceInstanceId;
        targetInstanceId = dataBundle.targetInstanceId;
        String originalDeploymentName = deployment.Name;
        deployment.Name = dataBundle.deployName;
        deployment.Source__c = sourceInstanceId;
        deployment.Target__c = targetInstanceId;

        assembler.build.Source__c = sourceInstanceId;
        assembler.build.Target__c = targetInstanceId;

        if (!validateDeploymentName(deployment.Id)) {
            deployment.Name = originalDeploymentName;
            return;
        }

        if (!assembler.isManifestLoaded) {
            assembler.loadManifest();
        }

        Savepoint sp = Database.setSavepoint();
        try {
            assembler.saveBuild();
            deployment.Build__c = assembler.build.Id;
            upsert deployment;
            assembler.saveComponents();
            
            for (AssemblerManifestRecord amr : assembler.getTotalManifest(false)) {
                amr.savedIsRemovedValue = amr.isRemoved;
            }

            assembler.checkManifestIsStale();
        } catch(Exception e) {
            Database.rollback(sp);
            if (assembler.build != null && [Select Id From Build__c Where Id = :assembler.build.Id].isEmpty()) {
                assembler.build.Id = null;
            }
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, Label.Generic_Error + ': ' + e.getMessage())
            );
            hasSaveErrors = true;
        }
        setIsDeploymentSettingsChanged();
    }

    public void syncManifest() {
        Savepoint sp = Database.setSavepoint();
        try {
            assembler.syncManifest();
            deployment.Build__c = assembler.build.Id;
            update deployment;
        } catch(Exception e) {
            Database.rollback(sp);
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, Label.Generic_Error + ': ' + e.getMessage())
            );
        }
    }

    /**
    * Checks to see if the given deployment name is valid based on the release
    * @param String name
    * @param Id releaseId
    * @return Boolean isValid
    */
    private static Boolean checkDeploymentName(Id releaseId, String name) {
        if(String.isBlank(name)) {
            return false;
        }

        String baseName = name.replaceAll('.zip', '');
        Integer existingDeployments = [
            select count()
            from Deployment__c
            where Release__c = :releaseId
            and Name = :baseName
        ];

        return existingDeployments == 0;
    }

    public void loadAvailableTestClasses() {
        Set<String> splitSpecifiedTests = new Set<String>(
                (String.isBlank(specifiedTestClasses)) ? new List<String>() : specifiedTestClasses.split(',')
        );
        List<String> filteredTestClasses = new List<String>();

        for(Component__c testClass : assembler.retrieveAllAvailableTestClasses()) {
            if (!splitSpecifiedTests.contains(testClass.Name)) {
                filteredTestClasses.add(testClass.Name);
            }
        }
        availableTestClasses = String.join(filteredTestClasses, ',');
    }

    @RemoteAction
    public static String slingshotAuthorizeInstance(String instanceId) {
        return OAuthLightningController.auraAuthorizeInstance(instanceId, false);
    }

    @RemoteAction
    public static OAuthRequest.UserInfoResponse getAuthInfo(String instanceId) {
        Auth_User__c auth = OAuthServices.getAuthUser(instanceId, false);

        OAuthRequest request = new OAuthRequest();
        return request.getUserInfo(auth);
    }

    @RemoteAction
    public static ProfileTemplate getProfileTemplate(List<String> instances) {
        return ProfileServices.retrieveProfileTemplate(instances);
    }

    @RemoteAction
    public static Deployment__c createDeployment(String releaseId,
                                                String deployName,
                                                String sourceInstanceId,
                                                String targetInstanceId,
                                                Boolean isManualUpload)
    {

        if(!checkDeploymentName(releaseId, deployName)) {
            throw new ALMException('Deployment name cannot be blank or already exist for this release.');
        }

        Build__c build = new Build__c(
            Release__c=releaseId,
            Source__c=sourceInstanceId,
            Target__c=targetInstanceId,
            Manual_Upload__c = isManualUpload,
            Status__c = BuildServices.STATUS_NOT_STARTED
        );
        insert build;

        Deployment__c deployment = new Deployment__c(
            Release__c = releaseId,
            Build__c = build.Id,
            Name = deployName.replaceAll('.zip', '')
        );
        insert deployment;

        return deployment;
    }

    @RemoteAction
    public static List<String> retrieveBranches(String repositoryId) {
        VCServices.GitListResponse response;
        try {
            response = VCServices.gitListBranches(UserInfo.getUserId(), repositoryId, true);
        } catch (Exception e) {
            throw new ALMException(e.getMessage());
        }

        if (response.isSuccess) {
            return response.references;
        } else {
            throw new ALMException(response.failureReason);
        }
    }

    @RemoteAction
    public static void updateBuildPackageURL(Id buildId, Id attachmentId) {
        Build__c build = new Build__c(
            Id = buildId,
            Package_URL__c = SObjectServices.getDownloadLinkForAttachment(new Attachment(Id = attachmentId))
        );
        update build;
    }

    @RemoteAction
    public static void handleUpdatePackageUrlFailure(Id buildId) {
        Build__c build = BuildServices.getBuild(buildId);
        if (build != null) {
            Deployment__c deployment = DeploymentServices.getDeploymentByBuildId(buildId);
            if (deployment != null) {
                delete deployment;
            }

            delete build;
        }
    }

   @RemoteAction
    public static Deployment__c createNewBuildForManualUpload(Id deploymentId) {
        List<Deployment__c> deployments =
            [Select Id, Release__c, Target__c from Deployment__c where Id = :deploymentId LIMIT 1];
        if (deployments.size() < 1 ) {
            throw new ALMException('Deployment not found');
        }
        Deployment__c dep = deployments[0];

        Build__c newBuild = new Build__c(
            Release__c = dep.Release__c,
            Source__c = null,
            Target__c = dep.Target__c,
            Manual_Upload__c = true,
            Status__c = BuildServices.STATUS_NOT_STARTED
        );
        insert newBuild;

        dep.Build__c = newBuild.Id;
        update dep;
        return dep;

    }

    @RemoteAction
    public static BuildModel checkBuildStatus(String buildId) {
        Build__c build = getBuild(buildId);

        if (build == null) {
            throw new ALMException('Build with Id: \''+ buildId + '\' does not exist');
        }

        if (!BuildServices.COMPLETE_STATUSES.contains(build.Status__c)) {
            try {
                AssemblerServices.BuildStatus buildStatus = AssemblerServices.getBuildStatus(build);
                BuildModel buildModel = new BuildModel(build, buildStatus);
                buildModel.save();
                return buildModel;
            } catch (Exception ex) {
                ALMLogServices.error(ex, ALMLogServices.Application.SLINGSHOT);
            }
        }

        return new BuildModel(build);
    }

    @RemoteAction
    public static List<DeploymentModel> getSavedDeployments(String releaseId) {
        List<Deployment__c> deployments = DeploymentServices.getDeploymentsByReleaseId(releaseId);

        Set<Id> buildIds = new Set<Id>();
        Set<Id> deploymentAttemptIds = new Set<Id>();

        for(Deployment__c currDep : deployments) {
            if (currDep.Completed_Build__c != null) {
                buildIds.add(currDep.Completed_Build__c);
            }
            if (currDep.Deployment_Attempt__c != null ) {
                deploymentAttemptIds.add(currDep.Deployment_Attempt__c);
            }
        }
        Map<Id, Integer> buildErrorMap = ALMErrorServices.getErrorCountsByBuild(buildIds);

        Map<Id, Integer> codeCoverageErrorMap = ALMErrorServices.getDeploymentAttemptIdsToCodeCoverageErrorCounts(deploymentAttemptIds);

        List<DeploymentModel> savedDeployments = new List<DeploymentModel>();
        for(Deployment__c currDep : deployments) {
            Integer codeCoverageErrorsCount =
                (currDep.Deployment_Attempt__c == null || codeCoverageErrorMap.get(currDep.Deployment_Attempt__c) == null)? 0:
                codeCoverageErrorMap.get(currDep.Deployment_Attempt__c);
            savedDeployments.add(new DeploymentModel(currDep, currDep.Deployment_Attempt__r,
                codeCoverageErrorsCount, buildErrorMap.get(currDep.Completed_Build__c)));
        }
        return savedDeployments;
    }

    @RemoteAction
    public static void parseManualBuildPackage(String buildId) {
        try {
            Build__c build = getBuild(buildId);
            if (build != null) {
                AssemblerServices.makeParsePackageRequest(build);
            }
        } catch( Exception e ) {
            // TODO: Handle this error in a page message in the next iteration of manual package upload story.
        }
    }

    @RemoteAction
    public static ParsePackageResult pollParsePackageUpdate(String buildId) {
        try {
            Build__c build = getBuild(buildId);
            if (build != null) {
                return new ParsePackageResult(build.Is_Manual_Package_Parsed__c, build.Manual_Package_Parse_Failure_Reason__c);
            }
        } catch( Exception e ) {
            return new ParsePackageResult();
        }
        return new ParsePackageResult();
    }

    @AuraEnabled
    public static Id updateBuildWithVCInfo(Id releaseId, Id repoId, String resourceLocation) {
        if (String.isEmpty(resourceLocation)) {
            throw new AuraHandledException(ERROR_INVALID_VC_DEPLOY_PARAMS_MESSAGE + ': empty branch selected.');
        }


        Deployment__c deployment = getLatestSavedDeployment(releaseId);
        if(deployment == null) {
            throw new AuraHandledException('No deployments found');
        }

        Id buildId = deployment.Build__c;
        if(buildId == null) {
            throw new AuraHandledException('No builds found');
        }

        try {
            Build__c build = new Build__c(Id=buildId, Source_Repository__c = repoId,
                    Source_Repository_Location__c = resourceLocation);
            update build;
        } catch (Exception e) {
            throw new AuraHandledException(ERROR_INVALID_VC_DEPLOY_PARAMS_MESSAGE + ': ' + e.getMessage());
        }

        return buildId;
    }

    private static Deployment__c getLatestSavedDeployment(String releaseId) {
        List<Deployment__c> deployments = DeploymentServices.getDeploymentsByReleaseId(releaseId);
        return deployments.size() > 0 ? deployments[0] : null;
    }

    @RemoteAction
    public static DeploymentModel.Attempt getUpdatedDeployment(String buildId) {
        List<Deployment_Attempt__c> updates = DeploymentServices.updateOngoingDeployments(buildId);
        if (updates.isEmpty()) {
              throw new ALMException('No deployment attempts found for the current build');
        }
        Deployment_Attempt__c deploymentAttempt = updates.get(0);
        Integer codeCoverageErrorsCount = ALMErrorServices.getCodeCoverageErrors(deploymentAttempt.Deployment__c).size();
        DeploymentModel.Attempt updatedDeployment = new DeploymentModel.Attempt(deploymentAttempt, codeCoverageErrorsCount);
        return updatedDeployment;
    }

    @RemoteAction
    public static Integer getBuildErrors(String buildId) {
        List<ALM_Error__c> errors = ALMErrorServices.getBuildErrors(buildId);
        return errors.size();
    }

    @RemoteAction
    public static Instances__c getInstance(String instanceId) {
        return InstanceServices.getInstance(instanceId);
    }

    public void clearDeploymentErrors() {
        if (deploymentErrors != null) {
            deploymentErrors.buildErrors.clear();
            deploymentErrors.apexErrors.clear();
            deploymentErrors.componentErrors.clear();
        }
    }

    private static Build__c getBuild(String buildId) {
        Build__c build = BuildServices.getBuild(buildId);

        if (build == null) {
            ApexPages.addMessage(
                new Apexpages.Message(ApexPages.Severity.ERROR, 'Build with Id: ' + buildId + 'does not exist.')
            );
            return null;
        }

        return build;
    }

    public void startAssembler() {
        List<Build__c> lockedBuilds;
        try {
            lockedBuilds = [SELECT Status__c FROM Build__c WHERE Id = :deployment.Build__c FOR UPDATE];
        } catch (Exception e) {
            ALMLogServices.error(e, ALMLogServices.Application.SLINGSHOT);
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, ERROR_BUILD_ALREADY_STARTED)
            );
            return;
        }

        if (!lockedBuilds.isEmpty() && BuildServices.STARTED_STATUSES.contains(lockedBuilds[0].Status__c)) {
            ALMLogServices.error(new ALMException(ERROR_BUILD_ALREADY_STARTED), ALMLogServices.Application.SLINGSHOT);
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, ERROR_BUILD_ALREADY_STARTED)
            );
            return;
        }

        clearDeploymentErrors();

        if (deployment.Completed_Build__c == null || assembler.isManifestChanged(deployment.Completed_Build__c)
                                                  || String.isBlank(deployment.Completed_Build__r.Package_URL__c)) {
            rebuildPackageFromSource = true;
        }

        if (!rebuildPackageFromSource || isQuickDeploy) {
            assembler.build.Package_URL__c = deployment.Completed_Build__r.Package_URL__c;
        } else if (!assembler.isManualUpload) {
            assembler.build.Package_URL__c = null;
        }

        if (isQuickDeploy
            || (!backupTarget && (assembler.isManualUpload || !rebuildPackageFromSource))) {
            //skip the assemble process.
            assembler.build.Status__c = BuildServices.STATUS_SUCCESS;
        } else {
            AssemblerServices.BuildResult buildResult;
            try {
                if (String.isBlank(build.Source_Repository__c)) {
                    buildResult = AssemblerServices.makeAssembleRequest(build, sourceInstanceId, targetInstanceId, !this.backupTarget);
                } else {
                    buildResult = AssemblerServices.makeGitAssembleRequest(build, targetInstanceId, !this.backupTarget);
                }
            } catch (AssemblerException e) {
                assembler.build.Status__c = BuildServices.STATUS_FAILURE;

                Deployment_Attempt__c deployAttempt = buildDeploymentAttempt();
                deployAttempt.Status__c = DeploymentServices.STATUS_FAILED;
                deployAttempt.Assemble_Request_Error__c = System.Label.Generic_Error + ' : ' + e.getMessage();
                saveOnAssemblerStart(deployAttempt);

                ALMLogServices.error(e, ALMLogServices.Application.SLINGSHOT);
                return;
            }

            assembler.build.Status__c = buildResult.result;
            assembler.build.UUID__c = buildResult.jobId;
        }

        Deployment_Attempt__c deployAttempt = buildDeploymentAttempt();
        saveOnAssemblerStart(deployAttempt);
    }

    public void finishBuild() {
        //Only necessary to update the reference, since Completed_Build__c is populated by a trigger
        deployment.Completed_Build__c = assembler.build.Id;
        assembler.build.Status__c = BuildServices.STATUS_SUCCESS;
        getDeploymentErrors();
    }

    private void saveOnAssemblerStart(Deployment_Attempt__c deployAttempt) {
        System.savepoint sp = Database.setSavepoint();
        try {
            insert deployAttempt;
            deployment.Deployment_Attempt__c = deployAttempt.Id;
            update deployment;
            assembler.saveBuild();
         } catch (DMLException e) {
            Database.rollback(sp);
            ALMLogServices.error(e, ALMLogServices.Application.SLINGSHOT);
            ApexPages.addMessage(
                new Apexpages.Message(ApexPages.Severity.ERROR, System.Label.Generic_Error + ' \n'+ e.getMessage() ));
        }
    }

    private Deployment_Attempt__c buildDeploymentAttempt() {
        Deployment_Attempt__c deployAttempt = new Deployment_Attempt__c();
        deployAttempt.Status__c = DeploymentServices.STATUS_NOT_STARTED;
        deployAttempt.Build__c = build.Id;
        deployAttempt.Release__c = build.Release__c;
        deployAttempt.Target_Instance__c = targetInstanceId;
        deployAttempt.Is_Validation__c = isValidation;
        deployAttempt.Ignore_Deployment_Warnings__c = ignoreDeploymentWarnings;
        deployAttempt.Test_Level__c = testLevel;
        deployAttempt.Start_Date__c = DateTime.now();
        deployAttempt.Is_Quick_Deploy__c = isQuickDeploy;
        deployAttempt.Deployment__c = deployment.Id;
        deployAttempt.Specified_Tests__c = specifiedTestClasses;
        if (isQuickDeploy) {
            deployAttempt.SF_Deployment_Id__c = deployment.Deployment_Attempt__r.SF_Deployment_Id__c;
        }

        return deployAttempt;
    }

    public void cancelDeployment() {
        Build__c currBuild = getBuild(deployment.Completed_Build__c);
        if(currBuild.Status__c == BuildServices.STATUS_SUCCESS || currBuild.Status__c == BuildServices.STATUS_FAILURE) {
            try {
                List<Deployment_Attempt__c> deploymentAttempts = [
                    SELECT UUID__c, Test_Level__c, Is_Validation__c, Target_Instance__c, Ignore_Deployment_Warnings__c, Is_Quick_Deploy__c, Specified_Tests__c, CreatedById
                    FROM Deployment_Attempt__c
                    WHERE Build__c = :currBuild.Id
                    AND Status__c NOT IN (:DeploymentServices.STATUS_FAILED, :DeploymentServices.STATUS_SUCCESS, :DeploymentServices.STATUS_CANCELED)
                    ORDER BY LastModifiedDate DESC
                ];

                if(deploymentAttempts.isEmpty()) {
                    ApexPages.addMessage(
                        new Apexpages.Message(ApexPages.Severity.ERROR, System.Label.Slingshot_cancel_error )
                    );
                    return;
                }

                DeploymentRequest request = new DeploymentRequest(assembler.build, deploymentAttempts[0]);
                request.sendCancelRequest();
            } catch(ALMException e) {
                ApexPages.addMessage(
                    new Apexpages.Message(ApexPages.Severity.ERROR, System.Label.Generic_Error + ' \n'+ e.getMessage() )
                );
            }
        }
    }

    private void setIsDeploymentSettingsChanged() {

        if (String.isblank(deployment.Completed_Build__c)) {
            isDeploymentSettingsChanged = false;
        }
        else if (deployment.Completed_Build__r.Source__c != sourceInstanceId
            || deployment.Completed_Build__r.Target__c != targetInstanceId) {
            isDeploymentSettingsChanged = true;
        } else {
            assembler.loadManifest();
            isDeploymentSettingsChanged = assembler.isManifestChanged(deployment.Completed_Build__c);
        }
    }

    public void validateAuth() {
        final String settingsLinkHTML = '<a href=\'/apex/' + SObjectServices.getFullyQualifiedName('AdminAlmSettings') + '\'>Sightline Settings <span class=\'link-arrow\'>&#8250;</span></a>';

        Instances__c almInstance = InstanceServices.almInstance;
        Auth_User__c almAuth = (almInstance == null) ? null : OAuthServices.getAuthUserForTools(almInstance.Id);

        if (almAuth == null || !almAuth.Is_Refresh_Token_Valid__c) {
            isAuthValid = false;
        } else {
            List<Auth_User__c> reauthorizedUsers =
                new OAuthRequest().reauthorize(new List<Auth_User__c>{ almAuth }, true);

            if(reauthorizedUsers.isEmpty() || !reauthorizedUsers[0].Is_Refresh_Token_Valid__c) {
                isAuthValid = false;
            }
        }

        if (!isAuthValid) {
            pageMessageManager.addMessage(
                new PageMessage(
                    'validateAuth',
                    ApexPages.Severity.WARNING,
                    System.Label.Sightline_Instance_Not_Authorized + settingsLinkHTML,
                    false
                )
            );
        }
    }

    public void removePageMessage() {
        pageMessageManager.removeMessageById(pageMessageToRemove);
    }

    @TestVisible
    protected override Map<String, Object> getCurrentPageStateMap() {
        Map<String, Object> currentPageStateMap = new Map<String, Object>();
        if (deployment != null && !String.isBlank(deployment.Id)) {
            currentPageStateMap.put('deploymentId', deployment.Id);
        } else {
            if (!String.isBlank(sourceInstanceId)) {
                currentPageStateMap.put('sourceInstanceId', sourceInstanceId);
            }
            if (!String.isBlank(targetInstanceId)) {
                currentPageStateMap.put('targetInstanceId', targetInstanceId);
            }
        }

        return currentPageStateMap;
    }

    protected override String getPageStateToken() {
        return PAGE_STATE_TOKEN;
    }

    private void loadAvailableDeploymentSources() {
        availableSources = new List<DeploymentSource>();

        List<Instances__c> allInstances = InstanceServices.getAllInstances();
        for (Instances__c instance : allInstances) {
            availableSources.add(new DeploymentSource(instance));
        }
        instancesCount = allInstances.size();

        List<VC_Repository__c> allRepos = [SELECT Id, Name, Source_Format__c, Repository_URL__c FROM VC_Repository__c LIMIT :LimitServices.getRemainingQueryRowsAvailable()];
        for (VC_Repository__c repo : allRepos) {
            availableSources.add(new DeploymentSource(repo));
        }
        reposCount = allRepos.size();

         availableSources.sort();
    }

    @TestVisible
    private void restorePageState() {
        Map<String, Object> pageStateMap = loadPageState();

        if (pageStateMap != null) {
            if (pageStateMap.containsKey('deploymentId')) {
                selectedDeploymentId = String.valueOf(pageStateMap.get('deploymentId'));
                loadDeployment();
            } else {
                if (pageStateMap.containsKey('sourceInstanceId')) {
                    sourceInstanceId = String.valueOf(pageStateMap.get('sourceInstanceId'));
                }
                if (pageStateMap.containsKey('targetInstanceId')) {
                    targetInstanceId = String.valueOf(pageStateMap.get('targetInstanceId'));
                }
            }
        }
    }

    @TestVisible
    private class ClientDataBundle {
        public Id sourceInstanceId;
        public Id targetInstanceId;
        public String deployName;
        public Id buildId;
    }

    public class DeploymentSource implements Comparable {

        public String id {get; set;}
        public String name {get; set;}
        public Boolean isInstance {get; set;}
        public String instanceType {get; set;}
        public String repoUrl {get; set;}

        public DeploymentSource(Instances__c instance) {
            this.id = instance.Id;
            this.name = instance.Name;
            this.isInstance = true;
            this.instanceType = instance.Type__c;
        }

        public DeploymentSource(VC_Repository__c repo) {
            this.id = repo.Id;
            this.name = repo.Name;
            this.isInstance = false;
            this.repoUrl = repo.Repository_URL__c;
        }

        public Integer compareTo(Object compareTo) {
            DeploymentSource that = (DeploymentSource) compareTo;
            if (this.name.toLowerCase() == that.name.toLowerCase()) {
                return 0;
            } else if (this.name.toLowerCase() > that.name.toLowerCase()) {
                return 1;
            } else {
                return -1;
            }
        }
    }

    public class DeploymentErrorsModel {
        public List<ALM_Error__c> buildErrors {get; set;}
        public List<ALM_Error__c> apexErrors {get; set;}
        public List<ALM_Error__c> componentErrors {get; set;}
        public List<ALM_Error__c> codeCoverageErrors {get; set;}

        public Boolean renderBuildErrors {
          get {
            return buildErrors.size() > 0;
          }
        }

        public Boolean renderApexErrors {
          get {
            return apexErrors.size() > 0;
          }
        }

        public Boolean renderComponentErrors {
          get {
            return componentErrors.size() > 0;
          }
        }

        public Boolean renderCodeCoverageErrors {
          get {
            return codeCoverageErrors.size() > 0;
          }
        }

        public DeploymentErrorsModel() {
            this.buildErrors = new List<ALM_Error__c>();
            this.apexErrors = new List<ALM_Error__c>();
            this.componentErrors = new List<ALM_Error__c>();
            this.codeCoverageErrors = new List<ALM_Error__c>();
        }

        public DeploymentErrorsModel(List<ALM_Error__c> buildErrors, List<ALM_Error__c> apexErrors, List<ALM_Error__c> componentErrors, List<ALM_Error__c> codeCoverageErrors) {
            this.buildErrors = buildErrors;
            this.apexErrors = apexErrors;
            this.componentErrors = componentErrors;
            this.codeCoverageErrors = codeCoverageErrors;
        }
    }

    public class ParsePackageResult {
        public Boolean isPackageParsed;
        public String failureReason;

        public ParsePackageResult() {
            this.isPackageParsed = true;
            this.failureReason = System.Label.Parse_Package_Apex_Tests_Error;
        }

        public ParsePackageResult(Boolean isPackageParsed, String failureReason) {
            this.isPackageParsed = isPackageParsed;
            this.failureReason = (String.isBlank(failureReason)) ? '' : failureReason;
        }
    }
}
