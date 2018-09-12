public with sharing class AssemblerServices {

    public static final String ASSEMBLER_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + '/assembler';
    public static final String VC_ASSEMBLER_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + '/assembler/assembleFromGit';

    public static final String ERROR_INSTANCE_AUTH_INVALID = 'Instance authorization is invalid.';
    public static final String ERROR_MISSING_AUTH_USERS = 'All required Auth_User__c records do not exist to make the assemble request.';
    public static final String ERROR_MISSING_REPO = 'The specified repository does not exist.';

    public static final String PARSE_PACKAGE_PATH = '/assembler/parsePackage';
    public static final String PARSE_PACKAGE_ENDPOINT = ALMRestServices.WEB_SERVICE_URL + PARSE_PACKAGE_PATH;
    public static final String PROFILE_TYPE = 'Profile';


    public static List<AssemblerManifestRecord> getManifest(Id releaseId) {

        List<String> noFilter = new List<String>();
        return getManifest(releaseId, noFilter, noFilter, noFilter, noFilter);
    }

    public static List<AssemblerManifestRecord> getManifest(Id releaseId, List<String> instances,
        List<String> types, List<String> backlogStatuses, List<String> backlogIds) {

        List<AssemblerManifestRecord> records = new List<AssemblerManifestRecord>();

        String query = 'SELECT Id, Backlog__r.Name, Backlog__r.Status__c, Source_Instance__r.Name, Component__r.Name,';
        query += 'Component__r.Full_Name__c, Component__r.Type__c, Component__r.Parent_Component__r.Name, Deleted__c, Notes__c,';
        query += 'Profile_Permission__c, Profile__c, Profile__r.Name, Backlog_Component__c.Deploy_Manually__c';
        query +=  ' FROM  '+ SObjectServices.getFullyQualifiedName('Backlog_Component__c');
        query +=  ' WHERE ';

        List<String> conditions = new List<String>();
        if ( !String.isEmpty(releaseId) ) {
            conditions.add( 'Backlog__r.Release__c = :releaseId' );
        }

        conditions.add( 'Profile_Permission__c = false' );
        conditions.add( 'Component__r.Type__c != \'' + PROFILE_TYPE +  '\'' );

        if( !instances.isEmpty()) {
            conditions.add( ' Source_Instance__c IN :instances' );
        }

        if( !types.isEmpty()) {
            conditions.add( ' Component__r.Type__c IN :types' );
        }

        if( !backlogStatuses.isEmpty()) {
            conditions.add( ' Backlog__r.Status__c IN :backlogStatuses' );
        }

        if( !backlogIds.isEmpty()) {
            conditions.add( ' Backlog__c IN :backlogIds' );
        }

        query += String.join( conditions, ' AND ');
        query += ' ORDER BY Backlog__r.Name';

        for( Backlog_Component__c backlogComponent : Database.query( query )) {
            records.add( new AssemblerManifestRecord(backlogComponent) );
        }

        return records;
    }

    /**
    * Returns any profile permissions documented against a release
    * @param releaseId      The release to check for documented profiles
    */
    public static List<ProfileManifestRecord> getDocumentedProfiles(Id releaseId) {
        List<ProfileManifestRecord> records = new List<ProfileManifestRecord>();
        List<Backlog_Component__c> allProfileComponents = [
                SELECT Id, Backlog__r.Name, Backlog__r.Status__c, Source_Instance__r.Name, Component__r.Name, Component__r.Full_Name__c,
                    Component__r.Type__c, Component__r.Parent_Component__r.Name, Deleted__c, Notes__c, Profile_Permission__c,
                    Profile_Data_1__c, Profile_Data_2__c, Include_Entire_Profile__c, Profile__c, Profile__r.Name

                FROM Backlog_Component__c
                WHERE Backlog__r.Release__c = :releaseId
                AND Component__r.Type__c = :PROFILE_TYPE

        ];
        Map<Id, List<Backlog_Component__c>> uniqueProfiles = GroupBy.ids(Backlog_Component__c.Profile__c, allProfileComponents);

        for (Id profileId : uniqueProfiles.keySet()) {

            List<ProfilePermissions> allProfilePermissions = new List<ProfilePermissions>();
            List<Backlog_Component__c> profileComponents = uniqueProfiles.get(profileId);
            Backlog_Component__c mergedComponent = profileComponents[0];

            for (Backlog_Component__c profile : profileComponents) {
                allProfilePermissions.add( ProfilePermissions.valueOf(profile) );
                mergedComponent.Include_Entire_Profile__c |= profile.Include_Entire_Profile__c;
                mergedComponent.Profile_Permission__c |= profile.Profile_Permission__c;
            }
            ProfileManifestRecord profileRecord = new ProfileManifestRecord( mergedComponent );

            if (!mergedComponent.Include_Entire_Profile__c) {
                ProfilePermissions mergedPermission = ProfilePermissions.mergePermissions(allProfilePermissions);
                profileRecord.selectedPermissions = JSON.serialize(mergedPermission);
            }

            records.add( profileRecord );
        }

        records.sort();
        return records;
    }

    /**
    * Returns any profile permissions not documented against a release
    * @param releaseId      The release to check for documented profiles
    */
    public static List<ProfileManifestRecord> getUndocumentedProfiles(Id releaseId) {
        List<ProfileManifestRecord> records = new List<ProfileManifestRecord>();

        List<Component__c> components = [
            SELECT Id, Name, Full_Name__c, Type__c, Parent_Component__c, Parent_Component__r.Name,
              (SELECT Id
                FROM Backlog_Components__r
                WHERE Backlog__r.Release__c = :releaseId
                AND Profile_Permission__c = true
                LIMIT 1)
            FROM Component__c
            WHERE Type__c = :PROFILE_TYPE
            Order by Name
        ];

        for( Component__c profile : components) {
            if (profile.Backlog_Components__r.isEmpty()) {
                records.add( new ProfileManifestRecord(profile) );
            }
        }

        return records;
    }

    /**
    * Retrieves the entire manifest for the given build
    * @param buildlId   the build to retreive the manifest for
    * @return   The manifest with any profiles included as ProfileManifestRecords
    */
    public static List<AssemblerManifestRecord> getManifestByBuildId(Id buildId) {
        List<AssemblerManifestRecord> records = new List<AssemblerManifestRecord>();

        String query = 'SELECT Id, Build__c, Component_Name__c, Component_Type__c, Parent_Component__c, Instance_Name__c, Type__c, Backlog_Component__c, Component__c, ';
        query += 'Include_Documented_Components__c, Is_Deletion__c, Profile_Data_1__c, Profile_Data_2__c, Include_Entire_Profile__c, Is_Manual_Deployment__c, ';
        query += 'Component__r.Name, Component__r.Full_Name__c, Is_Profile__c, Backlog_Component__r.Backlog__r.Name, Backlog_Component__r.Backlog__r.Status__c, ';
        query += 'Backlog_Component__r.Source_Instance__r.Name, Backlog_Component__r.Component__r.Name, Backlog_Component__r.Component__r.Full_Name__c, Backlog_Component__r.Component__r.Type__c, ';
        query += 'Backlog_Component__r.Component__r.Parent_Component__r.Name, Backlog_Component__r.Notes__c, Backlog_Component__r.Deploy_Manually__c, ';
        query += 'Backlog_Component__r.Profile_Permission__c,Backlog_Component__r.Profile__c, Backlog_Component__r.Profile__r.Name';
        query +=  ' FROM  '+ SObjectServices.getFullyQualifiedName('Build_Component__c');
        query +=  ' WHERE Build__c = :buildId';

        for( Build_Component__c buildComponent : Database.query( query )) {
            if (buildComponent.Is_Profile__c || buildComponent.Backlog_Component__r.Component__r.Type__c == PROFILE_TYPE) {
                records.add( new ProfileManifestRecord(buildComponent, ProfileServices.getProfileName(buildComponent)) );
            } else {
                records.add( new AssemblerManifestRecord(buildComponent) );
            }
        }
        return records;
    }

    /**
    * @throws AssemblerException
    */
    public static BuildResult makeAssembleRequest(Build__c build, String sourceInstanceId, String targetInstanceId, Boolean skipTargetBackup) {
        String endpoint = ASSEMBLER_ENDPOINT + '/assemble';

        Auth_User__c sourceOAuth = String.isEmpty(sourceInstanceId) ? null : prepAuthUserForCallout(sourceInstanceId, build.Id);
        Auth_User__c targetOAuth = prepAuthUserForCallout(targetInstanceId, build.Id);
        Auth_User__c sightlineOAuth = prepAuthUserForCallout(getSightlineAuthUser(build.Id), build.Id);

        List<Auth_User__c> reauthorizedUsers = new List<Auth_User__c> { targetOAuth, sightlineOAuth };
        if (sourceOAuth != null) {
            reauthorizedUsers.add(sourceOAuth);
        }

        AssemblerOrgSourceRequest assemblerRequest = new AssemblerOrgSourceRequest(build, sourceOAuth, targetOAuth, skipTargetBackup);
        return makeAssembleRequest(endpoint, assemblerRequest, reauthorizedUsers);
    }

    private static BuildResult makeAssembleRequest(String endpoint, AssemblerRequest assemblerRequest,
                                                   List<Auth_User__c> reauthorizedUsers) {
        String body = JSON.serialize(assemblerRequest);

        String response;
        try {
            response = ALMRestServices.makePostRequest(endpoint, body);
        } catch(ALMException ae) {
            throw new AssemblerException(ae.getMessage());
        }

        updateReauthorizedUsers(reauthorizedUsers);

        BuildResult result;
        try {
            result =
             (BuildResult) JSON.deserialize(response, BuildResult.class);
        }
        catch(JSONException je) {
            System.debug(je);
            throw new AssemblerException( System.Label.Generic_Error + ' \n'+ je.getMessage() );
        }

        return result;
    }

    /**
    * @throws AssemblerException
    */
    public static BuildResult makeGitAssembleRequest(Build__c build, String targetInstanceId, Boolean skipTargetBackup) {
        return makeGitAssembleRequest(build, targetInstanceId, false, skipTargetBackup);
    }

    private static BuildResult makeGitAssembleRequest(Build__c build, String targetInstanceId, Boolean isJenkinsAssembleRequest, Boolean skipTargetBackup) {
        List<VC_Repository__c> repositories = [SELECT Id, Repository_URL__c, SFDC_Metadata_Path__c, Source_Format__c 
            FROM VC_Repository__c WHERE Id = :build.Source_Repository__c];

        if (repositories.isEmpty()) {
            throw new AssemblerException(System.Label.Generic_Error + ' ' + ERROR_MISSING_REPO);
        }

        Auth_User__c targetOAuth = prepAuthUserForCallout(targetInstanceId, build.Id);
        Auth_User__c sightlineOAuth = prepAuthUserForCallout(getSightlineAuthUser(build.Id), build.Id);

        List<Auth_User__c> reauthorizedUsers = new List<Auth_User__c> { targetOAuth, sightlineOAuth };

        AssemblerRequest assemblerRequest;
        
        if (isJenkinsAssembleRequest) {
            assemblerRequest = new AssemblerJenkinsBuildRequest(build, targetOAuth, repositories[0], skipTargetBackup);
        } else {
            assemblerRequest = new AssemblerGitSourceRequest(build, targetOAuth, repositories[0], skipTargetBackup);
        }

        return makeAssembleRequest(VC_ASSEMBLER_ENDPOINT, assemblerRequest, reauthorizedUsers);
    }

    public static BuildResult makeJenkinsAssembleRequest(Build__c build, String targetInstanceId, Boolean skipTargetBackup) {
        return makeGitAssembleRequest(build, targetInstanceId, true, skipTargetBackup);
    }

    /**
    * @throws AssemblerException    if the sightline instance doesn't exist
    */
    private static Auth_User__c getSightlineAuthUser(String buildId) {
        Instances__c sightlineInstance = InstanceServices.almInstance;
        if (sightlineInstance == null) {
            ALM_Error__c error = ALMErrorServices.createALMError(
                ALMErrorServices.getOtherRecordTypeId(), 'Error', buildId, System.Label.Generic_Error, 'Sightline Instance does not exist!');
            throw new AssemblerException(error.Error_Cause__c);
        }

        return OAuthServices.getSightlineAuthUser();
    }

    /**
    * Prepares an auth user to be used in a assemble callout. Retrieves the auth user for the specified instance
    * and reauthorizes it
    * @param instanceId  the instance to retrieve the auth user for
    * @param buildId    the buildId to log any errors against
    * @throws AssemblerException    if the auth user doesn't exist or the refresh token is invalid
    */
    private static Auth_User__c prepAuthUserForCallout(String instanceId, String buildId) {
        Auth_User__c authUser = OAuthServices.getAuthUser(instanceId, false);
        if (authUser == null) {
            throw new AssemblerException(ERROR_MISSING_AUTH_USERS);
        }

        return prepAuthUserForCallout(authUser, buildId);
    }

    /**
    * Prepares an auth user to be used in a assemble callout.
    * @param authUser  the Auth_User__c to reauthorize
    * @param buildId    the buildId to log any errors against
    * @throws AssemblerException    if the auth user doesn't exist or the refresh token is invalid
    */
    private static Auth_User__c prepAuthUserForCallout(Auth_User__c authUser, String buildId) {
        // Reauthorize auth user to ensure access tokens are up-to-date.
        Auth_User__c reauthorizedUser;
        try {
            List<Auth_User__c> reauthorizedUsers =
                 new OAuthRequest().reauthorize(new List<Auth_User__c>{authUser}, false);
            reauthorizedUser = reauthorizedUsers[0];
        } catch(Exception e) {
            ALM_Error__c error = ALMErrorServices.createALMError(ALMErrorServices.getOtherRecordTypeId(), 'Error', buildId, e.getMessage(), System.Label.Generic_Error + e.getMessage());
            throw new AssemblerException(error.Error_Cause__c);
        }

        if (!reauthorizedUser.Is_Refresh_Token_Valid__c) {
            ALM_Error__c error = ALMErrorServices.createALMError(ALMErrorServices.getOtherRecordTypeId(), 'Error', buildId, System.Label.Generic_Error, ERROR_INSTANCE_AUTH_INVALID);
            throw new AssemblerException(error.Error_Cause__c);
        }

        return reauthorizedUser;
    }

    /**
    * @throws AssemblerException    if there are any DmlExceptions when updating the reauthorized users
    */
    private static void updateReauthorizedUsers(List<Auth_User__c> reauthorizedUsers) {
        List<Auth_User__c> dedupedUsers = new List<Auth_User__c>(new Set<Auth_User__c>(reauthorizedUsers));

        try {
            update dedupedUsers;
        } catch (DMLException de) {
            throw new AssemblerException(System.Label.Generic_Error + de.getMessage());
        }
    }

    /**
    * Makes a callout to web assembler to get the build status
    * @throws AssemblerException
    */
    public static BuildStatus getBuildStatus(Build__c build) {
        String endpoint = ASSEMBLER_ENDPOINT + '/' + build.UUID__c;

        String response;
        try {
             response = ALMRestServices.makeGetRequest(endpoint);
        } catch(ALMException ae) {
            throw new AssemblerException(ae.getMessage());
        }

        BuildStatus result;
        try {
            result =
             (BuildStatus) JSON.deserialize(response, BuildStatus.class);
        }
        catch(JSONException je) {
            System.debug(je);
            throw new AssemblerException( System.Label.Generic_Error + ' \n'+ je.getMessage() );
        }

        return result;
    }

    public static List<String> getComponentTypes() {
        List<String> componentTypes =
            SObjectServices.getPicklistValues( Schema.sObjectType.Component__c.fields.Type__c );
        return componentTypes;
    }

    public static Map<String, String> getBacklogStatuses() {
        Map<String, String> backlogStatuses =
            SObjectServices.getPicklistValueMap( Schema.sObjectType.Backlog__c.fields.Status__c );
        return backlogStatuses;
    }

    public static List<SelectOption> getBacklogStatusesAsSelectOptions() {
        List<SelectOption> statusFilters = new List<SelectOption>();
        Map<String, String> statusMap = getBacklogStatuses();
        List<String> orderedStatuses = SObjectServices.getPicklistValues( Schema.sObjectType.Backlog__c.fields.Status__c );
        for( String statusValue : orderedStatuses ) {
            statusFilters.add( new SelectOption(statusValue, statusMap.get(statusValue)) );
        }
        return statusFilters;
    }

    public static List<Backlog__c> getRelatedBacklogItems(Id releaseId) {
        return [
            SELECT Id, Name, RecordType.Name
            FROM Backlog__c
            WHERE Release__c = :releaseId
        ];
    }

    /**
    * Makes callout to WebAssembler to parse out the component details from
    * a build package and then calls createBuildComponentsFromBuildPackage to
    * insert build components into the database for each component returned
    * @param Build__c build
    * @throws ALMException if a dml exception or post request error has been caught
    */
    public static void makeParsePackageRequest(Build__c build) {
        ParseBuildPackageRequest parsePackageRequest = new ParseBuildPackageRequest(build.Id, build.Package_URL__c);
        try {
            String response = ALMRestServices.makePostRequest(PARSE_PACKAGE_ENDPOINT, Json.serialize(parsePackageRequest));

            ParsedPackageModel packageModel = (ParsedPackageModel)JSON.deserialize(response , ParsedPackageModel.class);
            if (!packageModel.isSuccess) {
                build.Manual_Package_Parse_Failure_Reason__c = packageModel.failureReason;
            } else {
                createBuildComponentsFromBuildPackage(build.Id, packageModel);
            }
        } catch(Exception ae) {
            String message = System.Label.Generic_Error + ' ' +  ae.getMessage(); 
            build.Manual_Package_Parse_Failure_Reason__c = message.abbreviate(255);
        } finally {
            try {
                build.Is_Manual_Package_Parsed__c = true;
                update build;
            } catch(DmlException de) {
                throw new ALMException(System.Label.Generic_Error);
            }   
        }
    }

    /**
    * Creates build components from the list of components in the ParsedPackageModel 
    * and links and related components to the build component
    * @param Id buildId
    * @param ParsedPackageModel packageModel
    * @return List<Build_Component__c>
    * @throws ALMException if a dml exception has been caught
    */
    @TestVisible
    private static List<Build_Component__c> createBuildComponentsFromBuildPackage(String buildId, ParsedPackageModel packageModel) {
        if ( !packageModel.isSuccess 
            || ((packageModel.components == null || packageModel.components.isEmpty()) 
                && (packageModel.destructiveChanges == null || packageModel.destructiveChanges.isEmpty()))) {
            return new List<Build_Component__c>();
        }

        Set<String> componentNames = new Set<String>();
        Set<String> componentTypes = new Set<String>();
        Set<String> componentParents = new Set<String>();
        List<Build_Component__c> buildComponents = processComponentsFromUploadedPackage(buildId, 
            packageModel.components, false, componentNames, componentTypes, componentParents);

        buildComponents.addAll(processComponentsFromUploadedPackage(buildId, packageModel.destructiveChanges, 
            true, componentNames, componentTypes, componentParents));

        Integer selectLimit = LimitServices.getRemainingQueryRowsAvailable();
        List<Component__c> components = [ SELECT Id, Full_Name__c, Type__c, Parent_Component__c, Parent_Component__r.Name
                                          FROM Component__c 
                                          WHERE Full_Name__c IN :componentNames
                                              AND Type__c IN :componentTypes 
                                              AND ( Parent_Component__r.Name IN :componentParents 
                                                  OR Parent_Component__r.Name = null ) 
                                          LIMIT :selectLimit ];

        Map<String, Component__c> componentKeyToRecord = new Map<String, Component__c>();
        for (Component__c component : components) {
            String key = ComponentServices.createComponentKey(
                ComponentServices.getComponentName(component), component.Type__c, component.Parent_Component__r.Name );
            componentKeyToRecord.put(key, component);
        }

        for (Build_Component__c buildComponent : buildComponents) {
            String buildComponentKey = ComponentServices.createComponentKey(
                buildComponent.Component_Name__c, buildComponent.Component_Type__c, buildComponent.Parent_Component__c );
            if (componentKeyToRecord.keySet().contains(buildComponentKey)) {
                buildComponent.Component__c = componentKeyToRecord.get(buildComponentKey).Id;
            }
        }

        // TODO: Enhancement - process these build components in batches so we do not need to chop them off.
        if (!buildComponents.isEmpty()) {
            try {
                while ( buildComponents.size() > LimitServices.getRemainingDMLRecordsAvailable() ) {
                    buildComponents.remove(0);
                }
                insert buildComponents;
            } catch (DMLException de) {
                throw new ALMException(System.Label.DML_Error + ' ' +  de.getMessage());
            }
        }
        return buildComponents;
    }

    /**
    * Processes components from an uploaded package to prepare for populating parent component lookups on 
    * build components.
    * The Set parameters for name, type and parent will be populated by parsing the components list
    * @return List<Build_Component__c> records created from these components
    */
    private static List<Build_Component__c> processComponentsFromUploadedPackage(String buildId,
         List<List<String>> components, Boolean isDestructiveChanges, Set<String> componentNames, Set<String> componentTypes,
          Set<String> componentParents) {
        List<Build_Component__c> buildComponents = new List<Build_Component__c>();

        if (components == null) {
            return buildComponents;
        }

        for (List<String> component : components) {
            if (component.size() == 3) {
                String componentName = component[0];
                String componentType = component[1];
                String parentComponentName = component[2];
                componentNames.add(componentName);
                componentTypes.add(componentType);
                if (!String.isBlank(parentComponentName)) {
                    componentParents.add(parentComponentName);
                }
                buildComponents.add(
                    createBuildComponentFromUploadedPackage(buildId, componentName, componentType, 
                    parentComponentName, isDestructiveChanges));
            }
        }

        return buildComponents;
    }

    private static Build_Component__c createBuildComponentFromUploadedPackage(String buildId, String componentName, 
        String componentType, String parentComponentName, Boolean isDestructiveChange) {

        return new Build_Component__c(
            Build__c = buildId,
            Type__c = AssemblerManifestRecord.UNDOCUMENTED,
            Is_Deletion__c = isDestructiveChange,
            Component_Name__c = componentName,
            Component_Type__c = componentType,
            Parent_Component__c = (String.isBlank(parentComponentName)) ? null : parentComponentName,
            Is_Profile__c = componentType == PROFILE_TYPE
        );
    }

    /**
    * Diffs the given build and release, returning all components
    * added or removed from the release based on the build
    * @param Id buildId
    * @param Id releaseId
    * @return List<ManifestDiff>
    * @throws ALMException
    */
    public static List<ManifestDiff> diffBuildAndRelease(Id buildId, Id releaseId) {
        if(buildId == null || releaseId == null) {
            throw new ALMException('Invalid ID. Cannot perform diff.');
        }

        List<ManifestDiff> differenceList = new List<ManifestDiff>();
        List<AssemblerManifestRecord> buildManifest = getManifestByBuildId(buildId);
        List<AssemblerManifestRecord> releaseManifest = getManifest(releaseId);
        // Add in profiles
        releaseManifest.addAll(((List<AssemblerManifestRecord>)getDocumentedProfiles(releaseId)));

        if(releaseManifest.isEmpty() && buildManifest.isEmpty()) {
            return differenceList;
        }

        ManifestFilterable buildFilterable = new ManifestFilterable(buildManifest);
        ManifestFilterable releaseFilterable = new ManifestFilterable(releaseManifest);

        for(AssemblerManifestRecord releaseRec : releaseManifest) {
            // Check if a release record exists in the build
            AssemblerManifestRecord buildRec = buildFilterable.findByKey(releaseRec.getDocumentedKey());

            // If there is no build record or the build record is undocumented, consider it
            // an "added" diff
            if(buildRec == null || buildRec.getIsUndocumented()) {
                // No manifest record exists for the build so add it as an added diff
                ManifestDiff currDiff = new ManifestDiff();
                currDiff.type = DiffType.ADDED;
                currDiff.manifestRecord = releaseRec;
                differenceList.add(currDiff);
            } else if (buildRec.getBuildComponent().Is_Manual_Deployment__c != releaseRec.getBuildComponent().Is_Manual_Deployment__c) {
                ManifestDiff currDiff = new ManifestDiff();
                currDiff.type = DiffType.CHANGED;
                currDiff.manifestRecord = releaseRec;
                differenceList.add(currDiff);
            }
        }

        for(AssemblerManifestRecord buildRec : buildManifest) {
            AssemblerManifestRecord releaseRec = releaseFilterable.findByKey(buildRec.getDocumentedKey());

            if(releaseRec == null && buildRec.getIsDocumented()) {
                ManifestDiff currDiff = new ManifestDiff();
                currDiff.type = DiffType.REMOVED;
                currDiff.manifestRecord = buildRec;
                differenceList.add(currDiff);
            }
        }

        return differenceList;
    }

    /**
    * This class allows lists of manifest records to be filtered in various ways
    */
    public class ManifestFilterable {
        private List<AssemblerManifestRecord> manifestList;
        // Map of backlog component key -> manifest rec
        private Map<String, AssemblerManifestRecord> manifestKeyMap;

        public ManifestFilterable(List<AssemblerManifestRecord> mList) {
            manifestList = mList;
            manifestKeyMap = new Map<String, AssemblerManifestRecord>();

            for(AssemblerManifestRecord rec : manifestList) {
                manifestKeyMap.put(rec.getDocumentedKey(), rec);
            }
        }

        public AssemblerManifestRecord findByKey(String key) {
            return manifestKeyMap.get(key);
        }
    }

    public enum DiffType {
        ADDED,
        CHANGED,
        REMOVED
    }

    public class ManifestDiff {
        public DiffType type;
        public AssemblerManifestRecord manifestRecord;
    }

    public class BuildResult {
        public String result;
        public String jobId;
    }

    public class BuildStatus {
        public String failureReason;
        public String status;
        public String jobId;
        public String buildStage;
        public Integer componentsRetrieved;
        public Integer componentsTotal;
    }

    public class ParsedPackageModel {
        public Boolean isSuccess;
        public String failureReason;
        public List<List<String>> components;
        public List<List<String>> destructiveChanges;

        public ParsedPackageModel(Boolean isSuccess, String failureReason, List<List<String>> components,
             List<List<String>> destructiveChanges) {
            this.isSuccess = isSuccess;
            this.failureReason = failureReason;
            this.components = components;
            this.destructiveChanges = destructiveChanges;
        }
    }
}
