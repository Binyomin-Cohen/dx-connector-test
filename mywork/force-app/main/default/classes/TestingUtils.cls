@isTest
public class TestingUtils {
    public static final String SYSADMIN_PROFILE_NAME = 'System Administrator';
    public static final String INSTANCE_URL = 'https://na15.salesforce.com';
    public static final String TEST_PUBLIC_KEY = 'Test Public Key';
    public static final String TEST_PRIVATE_KEY = 'Test Private Key';
    public static final String TEST_PASSPHRASE = 'Test Passphrase';
    public static final String TEST_BRANCH = 'Test Branch Name';
    public static final String TEST_OBJECT = 'Test Object';
    public static final String CONSUMER_SECRET = 'itssecret';

    public static User ADMIN_USER {
        get {
            if(ADMIN_USER == null) {
                ADMIN_USER = [SELECT Id, ProfileId, Username FROM User WHERE IsActive = true AND Profile.Name = :SYSADMIN_PROFILE_NAME LIMIT 1];
            }

            return ADMIN_USER;
        }
        private set;
    }

    public static String STORY_RECORD_TYPE_ID {
        get {
            if(STORY_RECORD_TYPE_ID == null) {
                STORY_RECORD_TYPE_ID = [SELECT Id FROM RecordType WHERE SObjectType = :SObjectServices.getFullyQualifiedName('Backlog__c') AND Name = :BacklogItemServices.STORY_RECORD_TYPE_NAME].Id;
            }

            return STORY_RECORD_TYPE_ID;
        }
        private set;
    }

    public static PermissionSet ALM_ADMIN_ACCESS_PERMISSION_SET {
        get {
            if (ALM_ADMIN_ACCESS_PERMISSION_SET == null) {
                ALM_ADMIN_ACCESS_PERMISSION_SET = [SELECT Id, Name FROM PermissionSet WHERE Name = 'ALM_Admin_Access'];
            }

            return ALM_ADMIN_ACCESS_PERMISSION_SET;
        }

        private set;
    }

    public static ALM_Error__c buildAssemblerBuildError(Id buildId) {
        Schema.RecordTypeInfo info =
            ALM_Error__c.sObjectType.getDescribe().getRecordTypeInfosByName().get(ALMErrorServices.COMPONENT_RECORD_TYPE);
        String recordTypeId = info.getRecordTypeId();

        return new ALM_Error__c(RecordTypeId=recordTypeId, Build__c=buildId);
    }

    public static Feedback_API_Settings__c createFeedackAPISettings() {
        Feedback_API_Settings__c settings = new Feedback_API_Settings__c();
        settings.Org_Id__c = '123456789';
        settings.Target_Object_Name__c = SObjectServices.getFullyQualifiedName( 'Backlog__c' );

        System.runAs( ADMIN_USER ) {
            insert settings;
        }

        return settings;
    }

    public static Feedback_API_Mapping__c createFeedackAPIMapping(String sourceField, String targetField) {
        Feedback_API_Mapping__c fieldMapping = new Feedback_API_Mapping__c();
        fieldMapping.Name = sourceField;
        fieldMapping.Source_Field__c = sourceField;
        fieldMapping.Target_Field__c = targetField;

        System.runAs( ADMIN_USER ) {
            insert fieldMapping;
        }

        return fieldMapping;
    }

    public static Jenkins_Build__c buildJenkinsBuild(String jenkinsJobRecordId) {
        Jenkins_Build__c jenkinsBuild = new Jenkins_Build__c(
            Jenkins_Job__c=jenkinsJobRecordId
        );
        return jenkinsBuild;
    }

    public static Jenkins_Build__c createJenkinsBuild(String jenkinsJobRecordId) {
        Jenkins_Build__c jenkinsBuild = buildJenkinsBuild(jenkinsJobRecordId);
        insert jenkinsBuild;
        return jenkinsBuild;
    }

    public static Jenkins_Job__c buildJenkinsJob(String instanceId, String releaseId) {
        CI_Instance__c ciInstance = new CI_Instance__c(Name='test', Target_Instance__c = instanceId, Release__c = releaseId);
        insert ciInstance;

        Jenkins_Job__c jenkinsJob = new Jenkins_Job__c(
           Path__c = 'somePath',
           Token__c = 'someToken',
           CI_Instance__c = ciInstance.Id
        );
        return jenkinsJob;
    }

    public static Jenkins_Job__c createJenkinsJob(String instanceId, String releaseId) {
        Jenkins_Job__c jenkinsJob = buildJenkinsJob(instanceId, releaseId);
        insert jenkinsJob;
        return jenkinsJob;
    }

    public static Jenkins_Job__c createJenkinsJob() {
        Release__c release = new Release__c(Name='Test release');
        insert release;
        Instances__c instance = new Instances__c();
        insert instance;

        Jenkins_Job__c jJob = buildJenkinsJob(instance.Id, release.Id);
        insert jJob;
        return jJob;
    }

    public static JIRA_Field_Mapping__c createJIRAMapping(String objectType, String sourceField, String targetField) {
        JIRA_Field_Mapping__c fieldMapping = buildJIRAMapping(objectType, sourceField, targetField);
        System.runAs( ADMIN_USER ) {
            insert fieldMapping;
        }

        return fieldMapping;
    }

    public static JIRA_Field_Mapping__c buildJIRAMapping(String objectType, String sourceField, String targetField) {
        JIRA_Field_Mapping__c fieldMapping = new JIRA_Field_Mapping__c();
        fieldMapping.Name = (objectType + '.' + sourceField).abbreviate(38);
        fieldMapping.Source_Type__c = objectType;
        fieldMapping.Source_Field__c = sourceField;
        fieldMapping.Target_Field__c = targetField;
        fieldMapping.Active__c = true;

        return fieldMapping;
    }

    public static ALM_Job__c createDefaultScanJob(Instances__c source, Instances__c target) {
        ALM_Job__c scanJob = buildDefaultScanJob(source, target);
        insert scanJob;

        return scanJob;
    }

    public static ALM_Job__c buildDefaultScanJob(Instances__c source, Instances__c target) {
        return buildDefaultSightlineJob(source, target, ALMJobServices.ToolType.SCAN);
    }

    public static ALM_Job__c createDefaultButrJob(Instances__c source, Instances__c target) {
        ALM_Job__c butrJob = buildDefaultButrJob(source, target);
        insert butrJob;

        return butrJob;
    }

    public static ALM_Job__c buildDefaultButrJob(Instances__c source, Instances__c target) {
        return buildDefaultSightlineJob(source, target, ALMJobServices.ToolType.AUTOMATED_TESTING);
    }

    public static ALM_Job__c buildDefaultSightlineJob(Instances__c source, Instances__c target, ALMJobServices.ToolType tool) {
        ALM_Job__c almJob = new ALM_Job__c();
        almJob.Tool__c = ALMJobServices.getToolName(tool);
        almJob.Status__c = SCANServices.TOOL_STATUS_SCHEDULED;
        almJob.Source_Instance__c = source.Id;
        almJob.Target_Instance__c = target.Id;
        almJob.Scheduled_On_Monday__c = true;
        almJob.Scheduled_On_Tuesday__c = true;
        almJob.Scheduled_On_Wednesday__c = true;
        almJob.Scheduled_On_Thursday__c = true;
        almJob.Scheduled_On_Friday__c = true;
        almJob.Scheduled_On_Saturday__c = true;
        almJob.Scheduled_On_Sunday__c = true;

        if (tool == ALMJobServices.ToolType.SCAN) {
            almJob.Components__c = '*';
        }

        return almJob;
    }

    public static ALM_Private__c createOAuthSettings() {
        ALM_Private__c settings = new ALM_Private__c();
        settings.Callback_URL__c = 'https://tools.bluewolf.com/oauth2';
        settings.Consumer_Key__c = 'FakeKey123';
        settings.Consumer_Secret__c = CONSUMER_SECRET;

        System.runAs( ADMIN_USER ) {
            insert settings;
        }

        return settings;
    }

    public static Auth_User__c createAuthUser(Id userId, Id instanceId) {
       return createAuthUser(userId, instanceId, false);
    }

    public static Auth_User__c createAuthUser(Id userId, Id instanceId, Boolean isForTools) {
        Auth_User__c authUser = buildAuthUser(userId, instanceId, isForTools);
        insert authUser;

        return authUser;
    }

    public static Instances__c createInstance(String name) {
        Instances__c instance = buildInstance(name);
        insert instance;

        return instance;
    }

    public static Auth_User__c buildAuthUser(Id userId, Id instanceId, Boolean isForTools) {
        Auth_User__c authUser = new Auth_User__c();
        authUser.User__c = userId;
        authUser.Access_Token__c = 'xyz123';
        authUser.Instance__c = instanceId;
        authUser.Is_For_Tools__c = isForTools;
        authUser.Instance_URL__c = INSTANCE_URL;
        authUser.Is_Refresh_Token_Valid__c = true;
        authUser.Org_ID__c = UserInfo.getOrganizationId();

        return authUser;
    }

    public static Instances__c buildInstance(String name) {
        Instances__c instance = new Instances__c(Name=name);

        return instance;
    }

    public static Sprint__c buildSprint(String name) {
        return new Sprint__c(Name=name);
    }

    public static List<Sprint__c> buildSprints(String name, Integer howMany) {
        List<Sprint__c> sprints = new List<Sprint__c>();
        for (Integer i = 0; i < howMany; i++){
            sprints.add( buildSprint(name + '_' + i) );
        }
        return sprints;
    }

    public static Sprint__c createSprint(String name) {
        Sprint__c sprint = buildSprint(name);
        insert sprint;
        return sprint;
    }

    public static List<Sprint__c> createSprints(String name, Integer howMany) {
        List<Sprint__c> sprints = buildSprints(name, howMany);
        insert sprints;
        return sprints;
    }

    public static List<Backlog__c> buildBacklogItems(Integer howMany) {
        List<Backlog__c> bklgs = new List<Backlog__c>();
        for (Integer i = 0; i < howMany; i++){
            bklgs.add(buildBacklogItem());
        }
        return bklgs;
    }

    public static List<Backlog__c> createBacklogItems(Integer howMany, Boolean doInsert) {
        List<Backlog__c> bklgs = buildBacklogItems(howMany);
        if (doInsert) {
            insert bklgs;
        }
        return bklgs;
    }

    public static List<Sprint_Item__c> buildSprintItems(Id sprintId, List<Backlog__c> backlogs) {
        return buildSprintItems( sprintId, backlogs, SprintModel.NOT_STARTED_STATUS);
    }

    public static List<Sprint_Item__c> buildSprintItems(Id sprintId, List<Backlog__c> backlogs, String status) {
        List<Sprint_Item__c> sprintItems = new List<Sprint_Item__c>();
        for (Backlog__c backlog : backlogs) {
            Sprint_Item__c item = new Sprint_Item__c(Sprint__c = sprintId, Backlog__c = backlog.Id);
            item.Status__c = status;
            sprintItems.add(item);
        }

        return sprintItems;
    }

    public static List<Sprint_Item__c> createSprintItems(Id sprintId, List<Backlog__c> backlogs) {
        List<Sprint_Item__c> items = buildSprintItems(sprintId, backlogs);
        insert items;
        return items;
    }

    public static List<Sprint_Item__c> createSprintItems(Id sprintId, List<Backlog__c> backlogs, String status) {
        List<Sprint_Item__c> items = buildSprintItems(sprintId, backlogs, status);
        insert items;
        return items;
    }

    public static Custom_Backlog__c buildCustomBacklog(String backlogName) {
        Custom_Backlog__c customBacklog = new Custom_Backlog__c(Name=backlogName);
        return customBacklog;
    }

    public static Custom_Backlog__c createCustomBacklog(String backlogName) {
        Custom_Backlog__c customBacklog = buildCustomBacklog(backlogName);
        insert customBacklog;
        return customBacklog;
    }

    public static Backlog__c buildBacklogItem() {
        Backlog__c backlogItem = new Backlog__c();
        return backlogItem;
    }

    public static Backlog__c buildBacklogItem(String status) {
        Backlog__c backlogItem = buildBacklogItem();
        backlogItem.Status__c = status;
        return backlogItem;
    }

    public static Backlog__c buildBacklogItem(Integer priority) {
      Backlog__c backlogItem = buildBacklogItem();
      backlogItem.Priority__c = priority;
      return backlogItem;
    }

    public static Backlog__c createBacklogItem() {
        Backlog__c backlogItem = buildBacklogItem();
        insert backlogItem;
        return backlogItem;
    }

    public static Backlog__c createBacklogItem(Integer priority) {
        Backlog__c backlogItem = buildBacklogItem(priority);
        insert backlogItem;
        return backlogItem;
    }

    public static Build__c buildBuild(String releaseId, Boolean manualUpload) {
        Build__c build = new Build__c(Release__c=releaseId);
        build.Manual_Upload__c = manualUpload;
        return build;
    }

    public static Build__c buildBuild(String releaseId, String jBuildId) {
        Build__c build = new Build__c(
                Release__c = releaseId,
                Jenkins_Build__c = jBuildId
        );
        return build;
    }

    public static Build__c createBuild(String releaseId, Boolean manualUpload) {
        Build__c build = buildBuild(releaseId, manualUpload);
        insert build;
        return build;
    }

    public static Build__c createBuild(String releaseId, String status) {
        Build__c build = new Build__c(Status__c = status);
        build.Release__c = releaseId;

        insert build;
        return build;
    }

    /**
    * Creates a deployment with the last modified date populated
    */
    public static Deployment__c createDeployment(String releaseId) {
        Deployment__c deployment = new Deployment__c(Release__c=releaseId, Name='saved deployment');
        insert deployment;

        return DeploymentServices.getDeploymentsByReleaseId(releaseId)[0];
    }

    public static Deployment_Attempt__c createDeploymentAttempt(Id releaseId, Id instanceId,
                                                                 Integer totalLines, Integer totalTests,
                                                                 Integer codeCoverage, Boolean runTests) {
        return createDeploymentAttempt(releaseId, instanceId, 'Success', totalLines, totalTests, codeCoverage, runTests, 0, 0);
    }

    public static Deployment_Attempt__c createDeploymentAttempt(Id releaseId, Id instanceId,
                                                                 String status, Integer totalLines, Integer totalTests,
                                                                 Integer codeCoverage, Boolean runTests,
                                                                 Integer numberOfTestErrors, Integer numberOfComponentErrors) {
        Deployment_Attempt__c deployAttempt = new Deployment_Attempt__c();
        deployAttempt.Release__c = releaseId;
        deployAttempt.Is_Validation__c = true;
        deployAttempt.Total_Lines__c = totalLines;
        deployAttempt.Number_Tests_Total__c = totalTests;
        deployAttempt.Total_Code_Coverage__c = codeCoverage;
        deployAttempt.Run_Tests__c = runTests;
        deployAttempt.Start_Date__c  = DateTime.now();
        deployAttempt.End_Date__c  = DateTime.now();
        deployAttempt.Status__c = status;
        deployAttempt.Target_Instance__c = instanceId;
        deployAttempt.Number_Test_Errors__c = numberOfTestErrors;
        deployAttempt.Number_Components_Errors__c = numberOfComponentErrors;
        deployAttempt.Number_Components_Total__c = 0;
        deployAttempt.Number_Components_Deployed__c = 0;
        insert deployAttempt;


        return DeploymentServices.getDeploymentAttempts(new Set<Id> {deployAttempt.Id})[0];
    }

    public static Component__c buildComponentWithParent(String name, String type, String parentId) {
        Component__c c = new Component__c();
        c.Name = name;
        c.Full_Name__c = name;
        c.Type__c = type;

        if (parentId != '') {
            c.Parent_Component__c = parentId;
        }

        return c;
    }

    public static Component__c buildComponent(String name, String type, String instanceId) {
        Component__c component = new Component__c(Name=name, Full_Name__c=name, Type__c=type, Instance__c = instanceId);
        return component;
    }

    public static List<Component__c> buildComponents(Integer howMany, String namePrefix, String type, String instanceId) {
        List<Component__c> comps = new List<Component__c>();
        for(Integer i = 0; i < howMany; i++){
            String name = namePrefix + i;
            comps.add(buildComponent(name, type, instanceId));
        }
        return comps;
    }

    public static Component__c createComponent(String name, String type, String instanceId) {
        Component__c component = buildComponent(name, type, instanceId);
        insert component;
        return component;
    }

    public static List<Component__c> createComponents(Integer howMany, String namePrefix, String type, String instanceId) {
        List<Component__c> comps = buildComponents(howMany, namePrefix, type, instanceId);
        insert comps;
        return comps;
    }

    public static Component__c createTestApexComponent(String name, Instances__c instance) {
        Component__c component = buildComponent(name, ComponentServices.APEX_ALM_NAME, instance.Id);
        component.Is_Test_Class__c = true;
        component.Source_Instances__c = instance.Name;
        insert component;

        return component;
    }

    public static Component__c createUndocumentedComponent(String name, String type, Id instanceId, FieldModifiedData environmentData) {
        return createUndocumentedComponent(name, type, instanceId, new List<FieldModifiedData>{ environmentData });
    }

    public static Component__c createUndocumentedComponent(String name, String type, Id instanceId, List<FieldModifiedData> environmentData) {

        Component__c undocumentedComponent = new Component__c(Name=name, Type__c=type, Instance__c = instanceId);
        undocumentedComponent.Field_Modified_Data__c = JSON.serialize( environmentData );
        insert undocumentedComponent;

        return undocumentedComponent;
    }

    public static Backlog_Component__c buildDocumentedComponent(String backlogId, Component__c component, String instanceId) {
        Id componentId = (component != null) ? component.Id : null;

        Backlog_Component__c documentedComponent = new Backlog_Component__c(Backlog__c = backlogId);
        documentedComponent.Component__c = componentId;
        documentedComponent.Source_Instance__c = instanceId;
        documentedComponent.Component__r = component;

        return documentedComponent;
    }

    public static Backlog_Component__c buildDocumentedProfile(String backlogId, Component__c profileComponent, String instanceId) {
        Id profileComponentId = (profileComponent != null) ? profileComponent.Id : null;

        Backlog_Component__c documentedProfile = buildDocumentedComponent(backlogId, profileComponent, instanceId);
        documentedProfile.Profile__c = profileComponentId;
        documentedProfile.Profile_Permission__c = true;
        documentedProfile.Profile__r = profileComponent;

        return documentedProfile;
    }

     public static Backlog_Component__c createDocumentedProfile(String backlogId, String profileName, String instanceId) {
        Component__c profileComponent = createComponent(profileName, 'Profile', instanceId);
        return createDocumentedProfile(backlogId, profileComponent, instanceId);
    }

    public static Backlog_Component__c createDocumentedProfile(String backlogId, Component__c profileComponent, String instanceId) {
        Backlog_Component__c documentedProfile = buildDocumentedProfile(backlogId, profileComponent, instanceId);

        insert documentedProfile;
        return documentedProfile;
    }

    public static Backlog_Component__c createDocumentedBacklogComponent( String backlogItemId, Instances__c instance ) {

        FieldModifiedData envData1 = new FieldModifiedData( instance.Name,  Datetime.now(), null, null, null);

        Component__c component = new Component__c(Name=TEST_OBJECT, Type__c='Object');
        component.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData1 } );
        insert component;

        Backlog_Component__c documentedComp = new Backlog_Component__c(Backlog__c = backlogItemId);
        documentedComp.Component__c = component.Id;
        documentedComp.Source_Instance__c = instance.Id;

        insert documentedComp;
        return documentedComp;
    }

    public static List<Backlog_Component__c>
                documentComponentsToBacklogItem(String instanceId, String backlogId, List<Component__c> components) {
        List<Backlog_Component__c> backlogComps = new List<Backlog_Component__c>();
        for (Component__c component : Components) {
            backlogComps.add(buildDocumentedComponent(backlogId, component, instanceId));
        }
        insert backlogComps;
        return backlogComps;
    }

    public static Build_Component__c createDocumentedBuildComponent(Backlog_Component__c documentedComp , String buildId, String instanceName ) {
        Build_Component__c buildComponent = new Build_Component__c( Build__c = buildId );
        buildComponent.Type__c = AssemblerManifestRecord.DOCUMENTED;
        buildComponent.Component__c = documentedComp.Component__c;
        buildComponent.Backlog_Component__c = documentedComp.Id;
        buildComponent.Instance_Name__c = instanceName;

        insert buildComponent;
        return buildComponent;
    }

    public static Build_Component__c buildDocumentedBuildComponent(Component__c component, String buildId, String instanceName) {
        return buildBuildComponent(component, AssemblerManifestRecord.DOCUMENTED, buildId, instanceName);
    }

    public static Build_Component__c createUndocumentedBuildComponent(Component__c component, String buildId, String instanceName) {
        return createBuildComponent(component, AssemblerManifestRecord.UNDOCUMENTED, buildId, instanceName);
    }

    public static Build_Component__c buildUndocumentedBuildComponent(Component__c component, String buildId, String instanceName) {
        return buildBuildComponent(component, AssemblerManifestRecord.UNDOCUMENTED, buildId, instanceName);
    }

    private static Build_Component__c createBuildComponent(Component__c component, String type, String buildId, String instanceName) {
        Build_Component__c buildComponent = buildBuildComponent(component, type, buildId, instanceName);

        insert buildComponent;
        return buildComponent;
    }

    private static Build_Component__c buildBuildComponent(Component__c component, String type, String buildId, String instanceName) {
        Build_Component__c buildComponent = new Build_Component__c( Build__c = buildId );
        buildComponent.Component__c = component.Id;
        buildComponent.Type__c = type;
        buildComponent.Component_Name__c = component.Name;
        buildComponent.Component_Type__c = component.Type__c;
        buildComponent.Parent_Component__c = component.Parent_Component__c;
        buildComponent.Instance_Name__c = instanceName;

        return buildComponent;
    }

    /**
    * Creates a new ProfilePermissions.Section and adds it to the ProfilePermissions object
    * @param permissions        The ProfilePermissions to add the section to
    * @param sectionApiName     The name of the section
    * @param sectionPermisions         The list of permissions for the section
    */
    public static void buildProfilePermissionsSection(ProfilePermissions permissions, String sectionApiName, List<String> sectionPermisions) {
        ProfilePermissions.Section section = new ProfilePermissions.Section();
        section.apiName = sectionApiName;
        section.permissions = sectionPermisions;

        permissions.sections.add(section);
    }

    public static Build_Component__c buildProfileBuildComponent(String buildId, Backlog_Component__c backlogComponent, ProfilePermissions selectedPermissions,
                                                        Boolean includeEntireProfile, Boolean includeOnlyDocumentedComponents)
    {
        ProfileManifestRecord profileRecord = new ProfileManifestRecord(backlogComponent);
        if (selectedPermissions != null) {
            profileRecord.selectedPermissions = JSON.serialize(selectedPermissions);
        }
        profileRecord.includeEntireProfile = includeEntireProfile;
        profileRecord.includeOnlyDocumentedComponents = includeOnlyDocumentedComponents;

        Build_Component__c profileBuildComponent = profileRecord.getBuildComponent();
        profileBuildComponent.Build__c = buildId;

        return profileBuildComponent;
    }


    public static List<Project__c> buildProjects(Integer howMany){
        List<Project__c> projs = new List<Project__c>();
        for (Integer i = 0; i < howMany; i++){
            projs.add(new Project__c(Name='project_'+i));
        }
        return projs;
    }
    public static List<Project__c> createProjects(Integer howMany){
        List<Project__c> testProjs = buildProjects(howMany);
        insert testProjs;
        return testProjs;
    }

    public static List<Persona__c> buildPersonas(Integer howMany){
        List<Persona__c> personas = new List<Persona__c>();
        for (Integer i = 0; i < howMany; i++){
            personas.add(new Persona__c(Name='persona_'+i));
        }
        return personas;
    }

    public static List<Persona__c> createPersonas(Integer howMany){
        List<Persona__c> testPersonas = buildPersonas(howMany);
        insert testPersonas;
        return testPersonas;
    }

    public static User buildUser( Id profileId ) {
        return buildUser(profileId, 'probablynotauser@example.com');
    }

    public static User buildUser( Id profileId, String username ) {
        User user = new User(
                Alias = 'hasrole',
                Email='kramer@gmail.com',
                EmailEncodingKey='UTF-8',
                lastname='kramer',
                languagelocalekey='en_US',
                localesidkey='en_US',
                profileid = profileId,
                timezonesidkey='America/New_York',
                username=username);

        return user;
    }

    public static User createUser( Id profileId ) {
        return createUser(profileId, 'probablynotauser@example.com');
    }

    public static User createUser( Id profileId, String username ) {
        User testUser = buildUser( profileId, username );

        System.runAs(ADMIN_USER) {
            insert testUser;
        }

        return testUser;
    }

    public static ALM_User__c createALMUser(String name) {

        ALM_User__c user = new ALM_User__c();
        user.Name = name;

        insert user;
        return user;
    }

    public static ALM_User_Role__c createUserRole(String name) {
        ALM_User_Role__c role = new ALM_User_Role__c(Name = name);
        insert role;
        return role;
    }

    /**
    * Even with seeAllData=false, CronJobDetail records in org data are visible in tests
    * This method checks and ensures that they are removed before a test
    * @param jobNames   The list of job names to remove
    */
    public static void deleteExistingJobs(List<String> jobNames) {
        List<CronTrigger> cronTriggers = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name IN :jobNames
        ];
        if(!cronTriggers.isEmpty()) {
            // Abort the jobs and make sure they no longer exist
            for(CronTrigger ct : cronTriggers) {
                System.abortJob(ct.Id);
            }

            List<CronJobDetail> scheduledJobs = [
                SELECT Id
                FROM CronJobDetail
                WHERE Name IN :jobNames
            ];
            System.assert(scheduledJobs.isEmpty(), 'There should be no scheduled jobs in the org interfering with tests');
        }
    }

    /**
    * @author Michael Hendy
    * @description Determines if the pagemessages contains a certain string
    * @param String messageNeedle : the string we will search for in the pagemessages
    * @return Boolean : true if found, false otherwise
    */
    public static Boolean pageMessageContains(String messageNeedle) {
        if( ApexPages.getMessages().size() > 0 )
        {
            ApexPages.Message message = ApexPages.getMessages()[0];

            if(message.getSummary().contains(messageNeedle))
                return true;
        }

        return false;
    }

    public static Boolean customPageMessageContains(String messageNeedle, List<PageMessage> messages) {
        if( messages.size() > 0 )
        {
            for(PageMessage currentPageMessage : messages) {
                if(String.IsNotBlank(currentPageMessage.message) && currentPageMessage.message.contains(messageNeedle))
                    return true;
            }
        }
        return false;
    }

    public static ALMSettings__c setupJIRASettings() {
        ALMSettings__c settings = ALMSettings__c.getOrgDefaults();
        settings.JIRA_Default_Username__c = 'jerry';

        System.runAs( ADMIN_USER ) {
            upsert settings;
        }

        return settings;
    }

    public static Auth_User__c setupSightlineAuth() {
        Instances__c sightlineInstance = new Instances__c(Name = 'Sightline Instance', Is_ALM_Instance__c = true);
        insert sightlineInstance;
        return createAuthUser(UserInfo.getUserId(), sightlineInstance.Id, true);
    }

    public static ALM_Job__c buildAlmJob(ALMJobServices.ToolType toolType, String status, Id sourceInstance, Id targetInstance) {
        return new ALM_Job__c(
            Source_Instance__c = sourceInstance,
            Target_Instance__c = targetInstance,
            Tool__c = ALMJobServices.getToolName(toolType),
            Status__c = status
        );
    }

    public static ALM_Job__c buildScanJob(Id sourceInstance, Id targetInstance, String status) {
        return buildAlmJob(ALMJobServices.ToolType.SCAN, status, sourceInstance, targetInstance);
    }

    public static ALM_Job__c buildButrJob(Id sourceInstance, String status) {
        return buildAlmJob(ALMJobServices.ToolType.AUTOMATED_TESTING, status, sourceInstance, null);
    }

    public static ALM_Application_Result__c createAlmApplicationResult(DateTime startTime, DateTime runTime, String result, String errorCode, Id instanceId, ALMJobServices.ToolType toolName) {

        ALM_Application_Result__c appResult = buildAlmApplicationResult(startTime, runTime, result, errorCode, instanceId, toolName);
        insert appResult;
        return appResult;
    }

    public static ALM_Application_Result__c buildAlmApplicationResult(DateTime startTime, DateTime runTime, String result, String errorCode, Id instanceId, ALMJobServices.ToolType toolName) {

        ALM_Application_Result__c appResult = new ALM_Application_Result__c();
        appResult.Start_Time__c = startTime;
        appResult.Run_Time__c = runTime;
        appResult.Result__c = result;
        appResult.Error_Code__c = errorCode;
        appResult.Instance__c = instanceId;
        appResult.Tool__c = ALMJobServices.getToolName(toolName);

        return appResult;
    }

    public static Boolean isUserAssignedToPermissionSet(String userId, String permissionSetId) {
        List<PermissionSetAssignment> assignments = [SELECT Id
                                                    FROM PermissionSetAssignment
                                                    Where AssigneeId =: userId
                                                      AND PermissionSetId =: permissionSetId];

       if (assignments.size() == 0) {
           return false;
       }

       return true;
    }

    public static ALM_Private__c createSSHPrivateSettings() {
        return createSSHPrivateSettings(null);
    }

    public static ALM_Private__c createSSHPrivateSettings(Blob managementKey) {
        ALM_Private__c privateSettings = new ALM_Private__c();

        if (managementKey != null) {
            privateSettings.SSH_Management_Key__c = EncodingUtil.base64Encode(managementKey);
        }

        insert privateSettings;

        return privateSettings;
    }

    public static SSH_Keypair__c createSSHUserKeypair(Schema.SObjectField userKeyFieldReference, String userFieldContent) {
        return createSSHUserKeypair(userKeyFieldReference, userFieldContent, null, null);
    }

    public static SSH_Keypair__c createSSHUserKeypair(Schema.SObjectField userKeyFieldReference, String userFieldContent, Blob managementKey) {
        return createSSHUserKeypair(userKeyFieldReference, userFieldContent, managementKey, null);
    }

    public static SSH_Keypair__c createSSHUserKeypair(Schema.SObjectField userKeyFieldReference, String userFieldContent, Blob managementKey, Id userKeyOwnerId) {
        SSH_Keypair__c sshKeypair = new SSH_Keypair__c(OwnerId = userKeyOwnerId == null ? TestingUtils.ADMIN_USER.Id : userKeyOwnerId);

        sshKeypair.put(userKeyFieldReference, encryptSSHField(userFieldContent, managementKey));

        insert sshKeypair;

        return sshKeypair;
    }

    public static SSH_Keypair__c createSSHUserKeypair(String userPublicKey, String userPrivateKey, String userPassphrase) {
        return createSSHUserKeypair(userPublicKey, userPrivateKey, userPassphrase, null, null);
    }

    public static SSH_Keypair__c createSSHUserKeypair(String userPublicKey, String userPrivateKey, String userPassphrase, Blob managementKey) {
        return createSSHUserKeypair(userPublicKey, userPrivateKey, userPassphrase, managementKey, null);
    }

    public static SSH_Keypair__c createSSHUserKeypair(String userPublicKey, String userPrivateKey, String userPassphrase, Blob managementKey, Id userKeyOwnerId) {
        SSH_Keypair__c sshKeypair = new SSH_Keypair__c(
            OwnerId = userKeyOwnerId == null ? TestingUtils.ADMIN_USER.Id : userKeyOwnerId,
            Public_Key__c = encryptSSHField(userPublicKey, managementKey),
            Private_Key__c = encryptSSHField(userPrivateKey, managementKey),
            Passphrase__c = encryptSSHField(userPassphrase, managementKey)
        );

        insert sshKeypair;

        return sshKeypair;
    }

    public static String encryptSSHField(String fieldContent, Blob managementKey) {
        return EncodingUtil.base64Encode(
            Crypto.EncryptWithManagedIV(
                SSHServices.MANAGEMENT_ENCRYPTION_ALGORITHM,
                managementKey != null ? managementKey : Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH),
                Blob.valueOf(fieldContent)
            )
        );
    }

    public static ALM_Job__c createSnapshotALMJob(ALMJobServices.ToolType tool, String status, String targetObjectAPIName, String reportDeveloperName) {
        return createSnapshotALMJob(ALMJobServices.getToolName(tool), status, targetObjectAPIName, reportDeveloperName, '');
    }

    public static ALM_Job__c createSnapshotALMJob(String tool, String status, String targetObjectAPIName, String reportDeveloperName) {
        return createSnapshotALMJob(tool, status, targetObjectAPIName, reportDeveloperName, '');
    }

    public static ALM_Job__c createSnapshotALMJob(ALMJobServices.ToolType tool, String status, String targetObjectAPIName, String reportDeveloperName, String errors) {
        return createSnapshotALMJob(ALMJobServices.getToolName(tool), status, targetObjectAPIName, reportDeveloperName, '');
    }

    public static ALM_Job__c createSnapshotALMJob(String tool, String status, String targetObjectAPIName,
                                                  String reportDeveloperName, String errors) {
        ALM_Job__c job = new ALM_Job__c(
            Tool__c = tool,
            Status__c = status,
            Target_Object_API_Name__c = targetObjectAPIName,
            Report_Developer_Name__c = reportDeveloperName,
            Errors__c = errors
        );
        insert job;

        return job;
    }

    public static VC_Commit__c buildVCCommit(String commitMessage, Boolean isExternalCommit) {
        return new VC_Commit__c(
                Commit_Message__c = commitMessage,
                External_Commit__c = isExternalCommit
        );
    }

    public static VC_Commit__c setupVCCommit() {

        String TEST_KEY_OWNER_ID = ADMIN_USER.Id;
        String TEST_REPOSITORY_URL = 'https://www.example.com/test-repository';
        String TEST_PUBLIC_KEY = 'Test Public Key';
        String TEST_PRIVATE_KEY = 'Test Private Key';
        String TEST_PASSPHRASE = 'Test Passphrase';
        String TEST_LIST_FAILURE_REASON = 'Test Failure Reason';

        String BRANCH_NAME = 'test-branch';
        String COMMIT_MESSAGE = 'initial commit';

        Instances__c instance = new Instances__c(Name='dev');
        insert instance;

        Auth_User__c sourceAuthUser = TestingUtils.createAuthUser(TEST_KEY_OWNER_ID, instance.Id);

        Backlog__c backlog = new Backlog__c(Status__c='Complete');
        insert backlog;

        VC_Repository__c repo = new VC_Repository__c(Repository_URL__c=TEST_REPOSITORY_URL);
        insert repo;

        Auth_User__c sightlineAuthUser = TestingUtils.setupSightlineAuth();
        sightlineAuthUser.Refresh_Token__c = 'test token';
        update sightlineAuthUser;

        ALM_Private__c almPrivate = TestingUtils.createOAuthSettings();
        OAuthServices.AppSettings settings = OAuthServices.getAppSettings();

        SSHServices.storePublicKey(TEST_KEY_OWNER_ID, TEST_PUBLIC_KEY);
        SSHServices.storePrivateKey(TEST_KEY_OWNER_ID, TEST_PRIVATE_KEY);
        SSHServices.storePassphrase(TEST_KEY_OWNER_ID, TEST_PASSPHRASE);

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(backlog.Id, instance);

        VC_Commit__c vcCommit = new VC_Commit__c(Backlog_Item__c=backlog.Id, Branch_Name__c=BRANCH_NAME,
                                                    Commit_Message__c=COMMIT_MESSAGE, VC_Repository__c=repo.Id,
                                                    Source_Instance__c=instance.Id, Backlog_Components__c = backlogComponent.Id);
        insert vcCommit;

        vcCommit = [SELECT Backlog_Item__c, Branch_Name__c, Commit_Message__c, VC_Repository__c,
                            Source_Instance__c, Backlog_Components__c, CreatedBy.Username
                     FROM VC_Commit__c
                     WHERE Id=:vcCommit.Id];

        return vcCommit;
    }

    public static Scratch_Org_Definition__c createScratchOrgDefinition(String name) {
        
        Scratch_Org_Definition__c orgDef = new Scratch_Org_Definition__c(Name=name, Edition__c = 'Enterprise');
        insert orgDef;
        return orgDef;
    }

    public static Snapshot_Field_Mapping__c createSnapshotMapping(Id jobId, String reportColumnName) {
        return createSnapshotMapping(jobId, reportColumnName, '');
    }

    public static Snapshot_Field_Mapping__c createSnapshotMapping(Id jobId, String reportColumnName, String targetFieldAPIName) {
        Snapshot_Field_Mapping__c snapshotMapping = new Snapshot_Field_Mapping__c(
            ALM_Job__c = jobId,
            Report_Column__c = reportColumnName,
            Target_Field_API_Name__c = targetFieldAPIName
        );
        insert snapshotMapping;

        return snapshotMapping;
    }

    public static VC_Repository__c createVcRepository(String name, String repoUrl) {
        return createVcRepository(name, repoUrl, null, null, null, null);
    }

    public static VC_Repository__c createVcRepository(String name, String repoUrl, String repoHost, String repoOrgName) {
		return createVcRepository(name, repoUrl, repoHost, repoOrgName, null, null);
    }

    public static VC_Repository__c buildVcRepository(String name, String repoUrl, String repoHost, String repoOrgName) {
		return buildVcRepository(name, repoUrl, repoHost, repoOrgName, null, null);
    }

    public static VC_Repository__c createVcRepository(String name, String repoUrl, String repoHost, String repoOrgName,
                                                      Date syncRevisionsFrom, Date lastSyncDate) {

        VC_Repository__c repoRecord = buildVcRepository(name, repoUrl, repoHost, repoOrgName,
                                                       syncRevisionsFrom, lastSyncDate);
        insert repoRecord;
        return repoRecord;
    }

    public static VC_Repository__c buildVcRepository(String name, String repoUrl, String repoHost, String repoOrgName,
                                                      Date syncRevisionsFrom, Date lastSyncDate) {
        VC_Repository__c repoRecord = new VC_Repository__c(
            Name = name,
            Repository_URL__c = repoUrl,
            Host__c = repoHost,
            Organization_Name__c = repoOrgName,
            Sync_Revisions_From__c = syncRevisionsFrom,
            Last_Sync_Date__c = lastSyncDate,
            Source_Format__c = 'Metadata API'
        );
        return repoRecord;
    }

    public static VC_Repository_Validation__c createVcRepositoryValidation(VC_Repository__c repo, Boolean doInsert) {
        VC_Repository_Validation__c repoValidationRecord = new VC_Repository_Validation__c(
            VC_Repository__c = repo.Id,
            ExternalID__c = UserInfo.getUserId()+repo.Id
        );
        if (doInsert) {
            insert repoValidationRecord;
        }
        return repoValidationRecord;
    }

    public static void setupSSH() {
        Id userId = UserInfo.getUserId();
        SSHServices.storePublicKey(userId, TEST_PUBLIC_KEY);
        SSHServices.storePrivateKey(userId, TEST_PRIVATE_KEY);
        SSHServices.storePassphrase(userId, TEST_PASSPHRASE);
    }

    public static VCRepoSyncSetup setupSyncRepoJobs(){
        return setupSyncRepoJobs(true);
    }

    public static VCRepoSyncSetup setupSyncRepoJobs(boolean shouldBeScheduled){

        // OAUTH and SSH
        VCRepoSyncSetup vcrSetup = new VCRepoSyncSetup();

        Auth_User__c authUser = TestingUtils.setupSightlineAuth();
        vcrSetup.setAuthUser(authUser);

        createOAuthSettings();
        OAuthServices.AppSettings settings = OAuthServices.getAppSettings();
        vcrSetup.setOauthSettings(settings);

        setupSSH();

        //REPOS.
        List<VC_Repository__c> reposList = new List<VC_Repository__c>();
        reposList.add( createVcRepository('git-repo1', 'http://www.git.com/one',
                'GitHub', 'GitTest1', Date.newInstance(2016, 2, 17), Date.newInstance(2017, 2, 17)) );
        reposList.add( createVcRepository('git-repo2', 'http://www.git.com/two',
                'BitBucket', 'GitTest2', Date.newInstance(2017, 8, 17), Date.newInstance(2016, 8, 18)) );
        vcrSetup.setReposList(reposList);

        //ALM JOBS
        List<ALM_Job__c> repoSyncJobs = new List<ALM_Job__c>{
                createVCRepoSyncJob(reposList[0].Id, shouldBeScheduled),
                createVCRepoSyncJob(reposList[1].Id, shouldBeScheduled)
        };
        vcrSetup.setRepoSyncJobs(repoSyncJobs);

        return vcrSetup;
    }

    public static ALM_Job__c createVCRepoSyncJob(Id repoId, Boolean scheduled) {
        ALM_Job__c job = buildVCRepoSyncJob(repoId, scheduled);
        insert job;
        return job;
    }

    public static ALM_Job__c buildVCRepoSyncJob(Id repoId, Boolean scheduled) {
        DateTime startTime = DateTime.newInstance(2016, 1, 1, 1, 1, 0);
        DateTime endTime =   DateTime.newInstance(2040, 12, 30, 24, 59, 59);
        ALM_Job__c job = new ALM_Job__c(
                Scheduled_Start_Time__c = startTime, Scheduled_End_Time__c = endTime,
                VC_Repo__c = repoId, Tool__c = ALMJobServices.getToolName(ALMJobServices.ToolType.VC_REPO_SYNC),
                Scheduled_On_Monday__c = scheduled, Scheduled_On_Tuesday__c = scheduled,
                Scheduled_On_Wednesday__c = scheduled, Scheduled_On_Thursday__c = scheduled,
                Scheduled_On_Friday__c = scheduled, Scheduled_On_Saturday__c = scheduled,
                Scheduled_On_Sunday__c = scheduled, Last_Queue_Time__c = null
        );
        return job;
    }

    public static ALM_Job__c createVCRepoSyncJob(Id repoId) {
        return createVCRepoSyncJob(repoId, true);
    }

    public class VCRepoSyncSetup {

        Auth_User__c authUser;
        List<VC_Repository__c> reposList;
        List<ALM_Job__c> repoSyncJobs;
        OAuthServices.AppSettings oauthSettings;


        public Auth_User__c getAuthUser(){
            return authUser;
        }

        public void setAuthUser( Auth_User__c authUser ){
            this.authUser = authUser;
        }

        public  List<VC_Repository__c> getReposList(){
            return reposList;
        }

        public void setReposList( List<VC_Repository__c> reposList){
            this.reposList = reposList;
        }

        public List<ALM_Job__c> getRepoSyncJobs(){
            return repoSyncJobs;
        }

        public void setRepoSyncJobs( List<ALM_Job__c> repoSyncJobs ){
            this.repoSyncJobs =repoSyncJobs;
        }

        public OAuthServices.AppSettings getOauthSettings(){
            return oauthSettings;
        }

        public void setOauthSettings(OAuthServices.AppSettings settings){
            this.oauthSettings = settings;
        }

        public Set<Id> getJobIds(){
            Map<Id,ALM_Job__c> repoSyncIdsToJobs = new Map<Id,ALM_Job__c>( this.repoSyncJobs);
            Set<Id> repoSyncJobIds = repoSyncIdsToJobs.keySet();
            return repoSyncJobIds;
        }

        public Map<Id, ALM_Job__c> getRepoSyncJobIdsToJobs(){
            return new Map<Id, ALM_Job__c>(getRepoSyncJobs());
        }

        public Map<Id, VC_Repository__c> getRepoIdToRepoMap(){
            Map<Id, VC_Repository__c> repoIdToRepoMap =   new Map<Id, VC_Repository__c>( getReposList() );
            return repoIdToRepoMap;
        }

    }

    public static Id createFakeSObjectId(Schema.SObjectType objectType) {
        return objectType.getDescribe().getKeyPrefix() + '000000000000';
    }

    public static Id createRandomFakeSObjectId(Schema.SObjectType objectType) {
        String randomSObjectId = objectType.getDescribe().getKeyPrefix() + '000';

        for (Integer i = 0; i < 9; ++i) {
            randomSObjectId += String.valueOf((Integer)(10 * Math.random()));
        }

        return randomSObjectId;
    }

    public static List<ALM_Application_Result__c> sortResults(List<ALM_Application_Result__c> results, Integer resultCount) {
        List<ApplicationResultSortingWrapper> resultWrappers = new List<ApplicationResultSortingWrapper>();
        for (ALM_Application_Result__c result : results) {
            resultWrappers.add(new ApplicationResultSortingWrapper(result));
        }

        resultWrappers.sort();

        if (resultCount == null) {
            resultCount = resultWrappers.size();
        }

        List<ALM_Application_Result__c> sortedResults = new List<ALM_Application_Result__c>();
        for (Integer i = resultWrappers.size() - 1; i >= 0 && sortedResults.size() < resultCount; --i) {
            sortedResults.add(resultWrappers[i].result);
        }

        return sortedResults;
    }

    private class ApplicationResultSortingWrapper implements Comparable {
        public ALM_Application_Result__c result;

        public ApplicationResultSortingWrapper(ALM_Application_Result__c result) {
            this.result = result;
        }

        public Integer compareTo(Object comparedObject) {
            ALM_Application_Result__c otherApplicationResult = ((ApplicationResultSortingWrapper)comparedObject).result;

            if (this.result.CreatedDate > otherApplicationResult.CreatedDate) {
                return 1;
            } else if (this.result.CreatedDate < otherApplicationResult.CreatedDate) {
                return -1;
            } else {
                return 0;
            }
        }
    }

    public class JenkinsJobSetup {
        public final String jobName;
        public final String jobPath;
        public final String jobToken;
        public final String branchName;

        public Jenkins_Job__c jenkinsJob;
        public Release__c release;
        public Instances__c instance;
        public CI_Instance__c ciInstance;
        public VC_Repository__c vcRepo;
        public Jenkins_Config__c jenkinsConfig;

        public JenkinsJobSetup(Boolean createRepo, String fieldNamePrefix) {
            this.jobName = fieldNamePrefix + 'testJobName';
            this.jobPath = fieldNamePrefix + 'testJobPath';
            this.jobToken = fieldNamePrefix + 'testJobToken';
            this.branchName = fieldNamePrefix + 'testBranchName';

            try {
                createOAuthSettings();
            } catch (Exception e) {
                // do nothing. This only happens when there are existing OAuthSettings
            }
            setupSightlineAuth();

            // create related Objects
            this.instance = createInstance(fieldNamePrefix + 'Test Instance Name');

            this.jenkinsConfig = new Jenkins_Config__c(
                Endpoint__c = fieldNamePrefix + 'TEST_ENDPOINT',
                User_ID__c = fieldNamePrefix + 'TEST_USER_ID',
                User_API_Token__c = fieldNamePrefix + 'TEST_USER_API_TOKEN'
            );
            try {
                insert this.jenkinsConfig;
            } catch (Exception e) {
                // do nothing. This only happens when there is an existing Jenkins Config
            }

            this.release = new Release__c(Name = fieldNamePrefix + 'Test Release Name');
            insert this.release;

            this.ciInstance = new CI_Instance__c(Name=fieldNamePrefix + 'test', Target_Instance__c = this.instance.Id,
                                                 Release__c = this.release.Id);
            insert this.ciInstance;

            if (createRepo) {
                this.vcRepo = new VC_Repository__c(
                    Repository_URL__c = fieldNamePrefix + 'testRepoURL',
                    Source_Format__c = 'Metadata API' );
                insert this.vcRepo;
            }
            Id repoId = createRepo ? this.vcRepo.Id : null;

            this.jenkinsJob = new Jenkins_Job__c(
                Name=this.jobName, Path__c=this.JobPath, Token__c=this.jobToken,
                CI_Instance__c=this.ciInstance.Id, Release__c=this.release.Id,
                Source_Repository_Location__c=this.branchName, Source_Repository__c=repoId
            );
            insert this.jenkinsJob;
        }
    }

    public class MockJenkinsBuildPackage {
        public String packageRequestContent;
        public String packageRequestJson;
        public String expectedBuildIdParam;
        public Attachment buildPackage;

        public MockJenkinsBuildPackage(String packageBody, String parentBuildId) {
            this(packageBody, parentBuildId, Datetime.now());
        }

        public MockJenkinsBuildPackage(String packageBody, String parentBuildId, Datetime packageCreatedDate) {
            Build__c parentBuild = [
                SELECT Id, Name, Jenkins_Build__r.Name, Package_URL__c FROM Build__c where Id = :parentBuildId
            ];

            expectedBuildIdParam = '{"name" :"buildId", "value" : "' +parentBuild.Jenkins_Build__r.Name + '"}';

            packageRequestContent =
                '\r\nContent-Disposition: form-data; name="package"; filename="' + JenkinsServices.PACKAGE_FILE_NAME + '"\r\n' +
                'Content-Type: application/xml\r\n' +
                '\r\n' + packageBody + '\r\n';
            packageRequestJson =
                '\r\nContent-Disposition: form-data; name="json"\r\n' +
                '\r\n{"parameter":[{"name":"packages/' + JenkinsServices.PACKAGE_FILE_NAME + '", "file":"package"}, ' + expectedBuildIdParam + ']}\r\n';

            buildPackage = new Attachment(
                ParentId = parentBuildId,
                Name='build-' + String.valueOf(packageCreatedDate.getTime()) + '.zip',
                Body = Blob.valueOf(packageBody)
            );

            insert buildPackage;
            final String buildPackageURL =
                'https://salesforce.com/servlet/servlet.FileDownload?file=' + buildPackage.Id;

            parentBuild.Package_URL__c = buildPackageURL;
            update parentBuild;
        }
    }

    public class SnapshotMappingDG implements UnitTest.DataGenerator{
        public List<SObject> generateData(Integer howMany){
            List<Snapshot_Field_Mapping__c> mappings = new List<Snapshot_Field_Mapping__c>();
            for(Integer i = 0; i < howMany; i++){
                mappings.add(new Snapshot_Field_Mapping__c());
            }
            return mappings;
        }
    }
}
