@isTest
private class TestSlingshotController2 {

    static Release__c release;
    static Instances__c instance;
    static Instances__c instance2;
    static Instances__c almInstance;
    private static FieldModifiedData envData1;

    static void setup() {
        release = new Release__c(Name='Sprint 15');
        insert release;

        instance = new Instances__c(Name='dev', Type__c='Production / Developer');
        instance2 = new Instances__c(Name='dev2', Type__c='Production / Developer');
        almInstance = new Instances__c(Name='ALM Instance', Is_ALM_Instance__c=true);

        insert new List<Instances__c>{instance, instance2, almInstance};

        envData1 = new FieldModifiedData( instance.Name,  Datetime.now().addDays(-1), null, null, null);
    }

    static void setupTestApexComponents(List<String> testNames, Instances__c instance) {
        for (String testName : testNames) {
            TestingUtils.createTestApexComponent(testName, instance);
        }
    }

    static void setupGitSSHSettings() {
        Blob testManagementKey = Crypto.generateAesKey(SSHServices.MANAGEMENT_ENCRYPTION_KEY_BIT_WIDTH);
        TestingUtils.createSSHPrivateSettings(testManagementKey);
        TestingUtils.createSSHUserKeypair('Test Public Key', 'Test Private Key', 'Test Passphrase', testManagementKey,  UserInfo.getUserId());
    }

    static String getDataBundleJSON() {
        return getDataBundleJSON(null, null);
    }

    static String getDataBundleJSON(String name, Id buildId) {
        return getDataBundleJSON(name, buildId, instance.Id, instance2.Id);
    }

    static String getDataBundleJSON(String name, Id buildId, Id sourceInstanceId, Id targetInstanceId) {
        SlingshotControllerExt2.ClientDataBundle cdb = new SlingshotControllerExt2.ClientDataBundle();
        cdb.deployName = name;
        cdb.buildId = buildId;
        cdb.sourceInstanceId = sourceInstanceId;
        cdb.targetInstanceId = targetInstanceId;

        return JSON.serialize(cdb);
    }

    private static Component__c createUndocumentedComponent(String name) {

        Component__c undocumentedComponent = new Component__c(Name=name, Type__c='Field');
        undocumentedComponent.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData1 } );
        insert undocumentedComponent;

        return undocumentedComponent;
    }

    private static AssemblerManifestRecord createUndocumentedManifestRecord(Component__c undocumentedComponent, String instanceName) {
        AssemblerManifestRecord record = new AssemblerManifestRecord(
               new ComponentSearchWrapper(undocumentedComponent, instanceName, null, null, null, false)
        );
        return record;
    }

    static testMethod void authorizeInstance() {
        setup();

        TestingUtils.createOAuthSettings();


        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        Test.startTest();
            slingshot.selectedInstanceId = instance.Id;
            slingshot.sourceInstanceId = instance.Id;
            slingshot.targetInstanceId = instance2.Id;
            PageReference authReference = slingshot.authorizeInstance();

        Test.stopTest();

        Map<String, String> params = authReference.getParameters();

        System.assertEquals(true, authReference.getUrl().startsWith('https://login.salesforce.com' + OAuthRequest.OAUTH_CODE_END_POINT_URL), 'The oauth endpoint should be set properly');
        System.assertEquals(true, params.containsKey('state'), 'A state parameter should be included');
        System.assertEquals(true, params.containsKey('grant_type'), 'A grant_type parameter should be included');
        System.assertEquals(OAuthRequest.AUTH_GRANT_TYPE_CODE, params.get('grant_type'), 'The grant_type parameter should be set to the authorization code value');

        Map<String, Object> state = (Map<String, Object>)JSON.deserializeUntyped(params.get('state'));
        System.assertEquals(true, state.containsKey('origin_url'), 'An origin_url should be included in the state parameter');
        System.assertEquals(true, state.containsKey(OAuthController.INSTANCE_STATE_PARAM), 'An instanceId should be included in the state parameter');

        String instanceId = (String)state.get(OAuthController.INSTANCE_STATE_PARAM);
        System.assertEquals(instance.Id, instanceId, 'The instance Id should be set to the selected instance.');

        System.assertEquals(true, state.containsKey(SlingshotControllerExt2.SRC_INSTANCE_STATE_PARAM), 'Source instance name should be included in the state parameter');
        String sourceInstanceId = (String)state.get(SlingshotControllerExt2.SRC_INSTANCE_STATE_PARAM);
        System.assertEquals(instance.Id, sourceInstanceId, 'The source instance Id should be set to the selected instance.');

        System.assertEquals(true, state.containsKey(SlingshotControllerExt2.TGT_INSTANCE_STATE_PARAM), 'Source instance name should be included in the state parameter');
        String targetInstanceId = (String)state.get(SlingshotControllerExt2.TGT_INSTANCE_STATE_PARAM);
        System.assertEquals(instance2.Id, targetInstanceId, 'The target instance Id should be set to the selected instance.');
    }

    static testMethod void handleOAuthRedirect_failure_noAuthCreated() {
        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();

        instance = new Instances__c(Name='dev');
        insert instance;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(new Release__c()));
        Test.startTest();
            PageReference ref = Page.Slingshot2;
            ref.getParameters().put('code', 'someinvalidcode');
            ref.getParameters().put('state', '{ \"instance_id\": \"' +instance.Id+ '\" }');
            Test.setCurrentPage(ref);

            slingshot.handleOAuthRedirect();

        Test.stopTest();

        List<Auth_User__c> auths = [SELECT Id FROM Auth_User__c];

        System.assertEquals(0, auths.size(), 'when the access token request fails, no auth records should be created');
    }

    static testMethod void handleOAuthRedirect_success() {
        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();

        instance = new Instances__c(Name='dev');
        insert instance;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(new Release__c()));
        Map<String,String> state = new Map<String, String>{
            OAuthController.INSTANCE_STATE_PARAM => instance.Id,
            OAuthController.CSRF_STATE_PARAM => OAuthServices.generateCSRFToken()
        };

        Test.startTest();
            PageReference ref = Page.Slingshot2;
            ref.getParameters().put('code', 'somecode');
            ref.getParameters().put('state', JSON.serialize(state));
            Test.setCurrentPage(ref);

            slingshot.handleOAuthRedirect();
        Test.stopTest();

        List<Auth_User__c> auths = [SELECT Id, Instance__c, User__c FROM Auth_User__c];

        System.assertEquals(1, auths.size(), 'when the access token request succeeds, an auth records should be created');
        System.assertEquals(instance.Id, auths[0].Instance__c, 'The instance Id should be set on the auth record');
        System.assertEquals(UserInfo.getUserId(), auths[0].User__c, 'The instance Id should be set on the auth record');
    }

    static testMethod void handleOAuthRedirect_loadSavedDeployment() {
        setup();

        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();

        Deployment__c deployment = new Deployment__c(Release__c=release.Id, Name='saved deployment');
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Map<String,String> state = new Map<String, String>{
            OAuthController.INSTANCE_STATE_PARAM => instance.Id,
            SlingshotControllerExt2.DEPLOYMENT_STATE_PARAM => deployment.Id,
            OAuthController.CSRF_STATE_PARAM => OAuthServices.generateCSRFToken()
        };
        Test.startTest();
            PageReference ref = Page.Slingshot2;
            ref.getParameters().put('code', 'somecode');


            ref.getParameters().put('state', JSON.serialize(state));
            Test.setCurrentPage(ref);

            slingshot.handleOAuthRedirect();

        Test.stopTest();

        System.assertEquals(deployment.Id, slingshot.deployment.Id, 'The selected deployment should be loaded on redirect');

        List<Auth_User__c> auths = [SELECT Id, Instance__c, User__c FROM Auth_User__c];

        System.assertEquals(1, auths.size(), 'when the access token request succeeds, an auth records should be created');
        System.assertEquals(instance.Id, auths[0].Instance__c, 'The instance Id should be set on the auth record');
    }

    static testMethod void startAssembler() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id);
        insert build;
        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        TestingUtils.createOAuthSettings();

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c = build.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.loadDeployment();

        slingshot.sourceInstanceId = instance.Id;
        slingshot.targetInstanceId = instance.Id;

        MockWebAssemblerAPI mockAPI = new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION);
        Test.setMock(HttpCalloutMock.class, mockAPI);

        Test.startTest();
            slingshot.startAssembler();
        Test.stopTest();

        Build__c updatedBuild = [SELECT Id, Status__c, UUID__c FROM Build__c WHERE Id = :slingshot.build.Id];
        System.assertEquals(false, mockAPI.shouldSkipTargetBackup(), 'It should not skip the target backup by default');
        System.assertEquals(MockWebAssemblerAPI.JOB_ID, updatedBuild.UUID__c, 'The build should be updated with the job Id from the assemble response');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT.toLowerCase(), updatedBuild.Status__c.toLowerCase(), 'The build should be updated with the status from the assemble response');
    }

    static testMethod void startAssembler_skipTargetBackup() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id);
        insert build;
        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        TestingUtils.createOAuthSettings();

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c = build.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.loadDeployment();
        
        slingshot.sourceInstanceId = instance.Id;
        slingshot.targetInstanceId = instance.Id;
        slingshot.backupTarget = false;

        MockWebAssemblerAPI mockAPI = new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION);
        Test.setMock(HttpCalloutMock.class, mockAPI);

        Test.startTest();
            slingshot.startAssembler();
        Test.stopTest();

        Build__c updatedBuild = [SELECT Id, Status__c, UUID__c FROM Build__c WHERE Id = :slingshot.build.Id];
        System.assertEquals(true, mockAPI.shouldSkipTargetBackup(), 'It should skip the target backup');
        System.assertEquals(MockWebAssemblerAPI.JOB_ID, updatedBuild.UUID__c, 'The build should be updated with the job Id from the assemble response');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT.toLowerCase(), updatedBuild.Status__c.toLowerCase(), 'The build should be updated with the status from the assemble response');
    }

    static testMethod void startAssembler_quickDeploy() {
        setup();
        String SF_DEPLOY_ID = 'sf_deploy_id';

        Build__c build = new Build__c(Release__c=release.Id);
        insert build;
        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        Deployment_Attempt__c attempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id,DeploymentServices.STATUS_SUCCESS, 1, 1, 75, true, 0, 0);
        attempt.SF_Deployment_Id__c = SF_DEPLOY_ID;
        update attempt;

        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        deployment.Build__c = build.Id;
        deployment.Deployment_Attempt__c = attempt.Id;
        update deployment;


        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.loadDeployment();

        slingshot.isQuickDeploy = true;
        slingshot.sourceInstanceId = instance.Id;
        slingshot.targetInstanceId = instance.Id;

        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));

        Test.startTest();
            slingshot.startAssembler();
        Test.stopTest();

        Deployment_Attempt__c newAttempt = DeploymentServices.getDeploymentAttempts(new Set<Id> { slingshot.deployment.Deployment_Attempt__c })[0];

        System.assertEquals(SF_DEPLOY_ID, newAttempt.SF_Deployment_Id__c, 'The prior deployment Id should be saved on new quick deployments');
        System.assertEquals(true, newAttempt.Is_Quick_Deploy__c, 'When the quick deploy option is set, the deployment attempt should be marked as a quick deploy');
    }

    static testMethod void startAssembler_webServiceError() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id);
        insert build;
        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c = build.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.loadDeployment();

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_FAILURE_ACTION));
            slingshot.sourceInstanceId = instance.Id;
            slingshot.targetInstanceId = instance.Id;
            slingshot.startAssembler();
        Test.stopTest();

        Build__c updatedBuild = [SELECT Id, Status__c, UUID__c FROM Build__c WHERE Id = :slingshot.build.Id];
        List<Deployment_Attempt__c> deployAttempts = [SELECT Id, Status__c FROM Deployment_Attempt__c];

        System.assertEquals(BuildServices.STATUS_FAILURE, updatedBuild.Status__c, 'The build should be marked as a failure');

        System.assertEquals(1, deployAttempts.size(), 'A failed deployment attempt should be created');
        System.assertEquals(DeploymentServices.STATUS_FAILED, deployAttempts[0].Status__c, 'A failed deployment attempt should be created');

    }

    static testMethod void startAssembler_reusePackage() {
        setup();

        String testURL = 'https://dat.test.url';
        Build__c previousBuild = new Build__c(Release__c=release.Id, Package_URL__c=testURL);
        insert previousBuild;
        TestingUtils.createOAuthSettings();
        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Completed_Build__c=previousBuild.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;

        slingshot.loadDeployment();

        String originalURL = slingshot.assembler.build.Package_URL__c;

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));
            slingshot.sourceInstanceId = instance.Id;
            slingshot.targetInstanceId = instance.Id;
            slingshot.rebuildPackageFromSource = false;
            slingshot.startAssembler();
        Test.stopTest();

        System.assertNotEquals(originalURL, testURL, 'The URL should not be set to the test URL prior to calling startAssembler.');
        System.assertEquals(testURL, slingshot.assembler.build.Package_URL__c, 'The current build URL should point to the URL of the previous build.');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, slingshot.assembler.build.Status__c, 'A build should still be kicked off so a new target backup package can be retrieved');
    }

    static testMethod void startAssembler_reusePackage_skipTargetBackup() {
        setup();

        String testURL = 'https://dat.test.url';
        Build__c previousBuild = new Build__c(Release__c=release.Id, Package_URL__c=testURL);
        insert previousBuild;
        TestingUtils.createOAuthSettings();
        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Completed_Build__c=previousBuild.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;

        slingshot.loadDeployment();

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));
            slingshot.sourceInstanceId = instance.Id;
            slingshot.targetInstanceId = instance.Id;
            slingshot.rebuildPackageFromSource = false;
            slingshot.backupTarget = false;
            slingshot.startAssembler();
        Test.stopTest();
        System.assertEquals(MockWebAssemblerAPI.STATUS_SUCCESS, slingshot.assembler.build.Status__c, 
            'A build should not be kicked off since user is skipping target backup');
        System.assertEquals(false, MockWebAssemblerAPI.assembleRequestWasMade, 
            'The web assembler API should not be called when not rebuildPackageFromSource and not backupTarget');    
  
    }

    static testMethod void createNewBuildForManualUpload() {
        setup();
        Deployment__c  deployment = new Deployment__c(
            Name = 'Test Deploy', 
            Release__c = release.Id, 
            Build__c = null,
            Target__c = instance.Id);
        insert deployment;
        
        Test.startTest();
            deployment = SlingshotControllerExt2.createNewBuildForManualUpload(deployment.Id);
        Test.stopTest();

        System.assert(deployment.Build__c != null, 'The build should not be null');

        Build__c build = [Select Release__c, Source__c, Target__c from Build__c where Id = :deployment.Build__c];
        System.assertEquals(build.Release__c, release.Id, 'The release should be set on the build');
        System.assertEquals(build.Target__c, instance.Id, 'The target should be set on the build');
    }

    static testMethod void createNewBuildForManualUpload_NoDeployment() {
        setup();
        Deployment__c  deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c = null);
        insert deployment;
        Id deploymentId = deployment.Id;
        delete deployment;
        
        Test.startTest();
            try {
                deployment = SlingshotControllerExt2.createNewBuildForManualUpload(deploymentId);
                System.assert(false, 'Deployment should not be found and ALM Exception should be thrown');
            } catch(Exception e) {
                System.assert(e instanceOf ALMException, 'ALM Exception should be thrown');
            }
        Test.stopTest();
    }

    static testMethod void startAssembler_reusePackage_nullPackageURL() {
        setup();

        Build__c previousBuild = new Build__c(Release__c = release.Id);
        insert previousBuild;

        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Completed_Build__c = previousBuild.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;

        slingshot.loadDeployment();

        String testURL = 'https://dat.test.url';
        slingshot.assembler.build.Package_URL__c = testURL;

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));
            slingshot.sourceInstanceId = instance.Id;
            slingshot.targetInstanceId = instance.Id;
            slingshot.rebuildPackageFromSource = false;
            slingshot.deployment.Completed_Build__r.Package_URL__c = null;
            slingshot.startAssembler();
        Test.stopTest();

        System.assertEquals(true, slingshot.rebuildPackageFromSource, 'The package should be rebuilt from the source when there is no prior completed build package url.');
        System.assertEquals(null, slingshot.assembler.build.Package_URL__c, 'The current build URL should be reset if there is no prior completed build package url.');
    }

    static testMethod void startAssembler_reusePackage_emptyPackageURL() {
        setup();

        Build__c previousBuild = new Build__c(Release__c = release.Id);
        insert previousBuild;

        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Completed_Build__c = previousBuild.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;

        slingshot.loadDeployment();

        String testURL = 'https://dat.test.url';
        slingshot.assembler.build.Package_URL__c = testURL;

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));
            slingshot.sourceInstanceId = instance.Id;
            slingshot.targetInstanceId = instance.Id;
            slingshot.rebuildPackageFromSource = false;
            slingshot.deployment.Completed_Build__r.Package_URL__c = '';
            slingshot.startAssembler();
        Test.stopTest();

        System.assertEquals(true, slingshot.rebuildPackageFromSource, 'The package should be rebuilt from the source when there is no prior completed build package url.');
        System.assertEquals(null, slingshot.assembler.build.Package_URL__c, 'The current build URL should be reset if there is no prior completed build package url.');
    }

    static testMethod void startAssembler_reusePackage_whitespacePackageURL() {
        setup();

        Build__c previousBuild = new Build__c(Release__c = release.Id);
        insert previousBuild;

        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Completed_Build__c = previousBuild.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;

        slingshot.loadDeployment();

        String testURL = 'https://dat.test.url';
        slingshot.assembler.build.Package_URL__c = testURL;

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));
            slingshot.sourceInstanceId = instance.Id;
            slingshot.targetInstanceId = instance.Id;
            slingshot.rebuildPackageFromSource = false;
            slingshot.deployment.Completed_Build__r.Package_URL__c = ' ';
            slingshot.startAssembler();
        Test.stopTest();

        System.assertEquals(true, slingshot.rebuildPackageFromSource, 'The package should be rebuilt from the source when there is no prior completed build package url.');
        System.assertEquals(null, slingshot.assembler.build.Package_URL__c, 'The current build URL should be reset if there is no prior completed build package url.');
    }

    static testMethod void syncManifest() {
    	setup();
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c = build.Id);
        insert deployment;

		Backlog__c backlogItem = TestingUtils.buildBacklogItem();
		backlogItem.Release__c = release.Id;
		insert backlogItem;

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(backlogItem.Id, instance);

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.loadDeployment();

        Test.startTest();

            slingshot.syncManifest();

        Test.stopTest();

        Deployment__c updatedDeployment = [SELECT Id, Build__c FROM Deployment__c WHERE Id = :deployment.Id];
        System.assertNotEquals(null, updatedDeployment.Build__c, 'The deployment should be updated with a new build when syncing the manifest after a rebuild.');
        System.assertNotEquals(build.Id, updatedDeployment.Build__c, 'The deployment should be updated with a new build when syncing the manifest after a rebuild.');

        List<Build_Component__c> buildComponents =
             [SELECT Id, Backlog_Component__c FROM Build_Component__c WHERE Build__c = :slingshot.buildId];

        System.assertEquals(1, buildComponents.size(), 'The new build manifest should be synced');
        System.assertEquals(backlogComponent.Id, buildComponents[0].Backlog_Component__c, 'A new build component should be created for the documented component');
    }

    static testMethod void startAssembler_manualUpload_skipTargetBackup() {
        setup();

        //TODO: Unable to fully test manual upload save flow because we are getting a "System.CalloutException: You have already created Savepoints.
        //   You cannot make callout after creating a Savepoint" error. Setting the status to success will make the callout not occur
        Build__c build = TestingUtils.createBuild(release.Id, true);
        build.Package_URL__c = 'some_url';
        update build;

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c = build.Id, Target__c = instance.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.loadDeployment();
        slingshot.assembler.loadManifest();
        slingshot.backupTarget = false;
        slingshot.build.Status__c = BuildServices.STATUS_SUCCESS;

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.DEPLOYMENTS_ACTION));
            slingshot.startAssembler();
        Test.stopTest();

        Build__c updatedBuild = [SELECT Id, Status__c, Package_URL__c FROM Build__c WHERE Id = :build.Id];

        System.assertEquals(BuildServices.STATUS_SUCCESS, updatedBuild.Status__c, 'The build status should be updated to be successful for manual builds');
        System.assertEquals(build.Package_URL__c, updatedBuild.Package_URL__c, 'The Package_URL__c should not be cleared out.');

        List<Deployment_Attempt__c> attempts = [SELECT Id, Build__c, UUID__c, Status__c FROM Deployment_Attempt__c];

        System.assertEquals(1, attempts.size(), 'A deployment attempt should be created');
        Deployment_Attempt__c attempt = attempts[0];

        System.assertEquals(build.Id, attempt.Build__c, 'A deployment attempt should be created looking up to the manual upload build');
    }
  
    static testMethod void startAssembler_manualUpload() {
        setup();

        TestingUtils.createOAuthSettings();
        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        Build__c build = TestingUtils.createBuild(release.Id, true);
        build.Package_URL__c = 'some_url';
        update build;

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c = build.Id, Target__c = instance.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.loadDeployment();
        slingshot.assembler.loadManifest();
        slingshot.backupTarget = true;

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));
            slingshot.startAssembler();
        Test.stopTest();

        Build__c updatedBuild = [SELECT Id, Status__c, Package_URL__c FROM Build__c WHERE Id = :build.Id];

        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, updatedBuild.Status__c,
            'When it is a manual upload and the option to backup the target is true, the build should be kicked off');
        System.assertEquals(build.Package_URL__c, updatedBuild.Package_URL__c,
            'The Package_URL__c should not be cleared out.');

        List<Deployment_Attempt__c> attempts = [SELECT Id, Build__c, UUID__c, Status__c FROM Deployment_Attempt__c];

        System.assertEquals(1, attempts.size(), 'A deployment attempt should be created');
        Deployment_Attempt__c attempt = attempts[0];

        System.assertEquals(build.Id, attempt.Build__c, 'A deployment attempt should be created looking up to the manual upload build');
    }

    static testMethod void staleManifestCheckTime_observesLocale() {
        User user = TestingUtils.createUser(TestingUtils.ADMIN_USER.ProfileId, 'de-user@sightline-test.com');
        user.localesidkey = 'de_DE';
        user.timezonesidkey = 'America/Los_Angeles';
        update user;

        System.runAs(user) {
            setup();

            SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
            //Monday, February 5, 2018 11:22:23 AM (US EST GMT-05:00)
            final Long RAW_TIME = 1517847743000L;

            Test.startTest();
                slingshot.assembler.staleManifestCheckTime = Datetime.newInstance(RAW_TIME);
                
                System.assertEquals('05.02.2018 08:22', slingshot.staleManifestCheckTime, 'The stale manifest time should be formatted into the users locale and timezone');
                
            Test.stopTest();

        }
    }

    static testMethod void saveDeployment() {
        setup();

        String deploymentName = 'new deployment';
        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        slingshot.serializedClientDataBundle = getDataBundleJSON(deploymentName, null);
        slingshot.sourceInstanceId = instance.Id;
        slingshot.targetInstanceId = instance2.Id;

        Test.startTest();
            slingshot.saveDeployment();
        Test.stopTest();

        Deployment__c createdDeployment = [SELECT Id, Completed_Build__c, Source__c, Target__c, Build__c, Build__r.Source__c, Build__r.Target__c FROM Deployment__c WHERE Name = :deploymentName];

        System.assertEquals(instance.Id, createdDeployment.Source__c, 'The source should be set on the deployment');
        System.assertEquals(instance.Id, createdDeployment.Build__r.Source__c, 'The source should be set on the build');

        System.assertEquals(instance2.Id, createdDeployment.Target__c, 'The target should be set on the deployment');
        System.assertEquals(instance2.Id, createdDeployment.Build__r.Target__c, 'The target should be set on the build');
        System.assertEquals(null, createdDeployment.Completed_Build__c, 'The completed build should be blank');
    }

    static testMethod void saveDeployment_noNameChange() {
        setup();

        String deploymentName = 'new deployment';
        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        slingshot.serializedClientDataBundle = getDataBundleJSON(deploymentName, null);
        slingshot.sourceInstanceId = instance.Id;
        slingshot.targetInstanceId = instance2.Id;
        slingshot.saveDeployment();

        slingshot.serializedClientDataBundle = getDataBundleJSON(deploymentName, null);
        slingshot.sourceInstanceId = instance.Id;
        slingshot.targetInstanceId = instance2.Id;

        Test.startTest();
            slingshot.saveDeployment();
        Test.stopTest();

        List<Deployment__c> createdDeployments = [SELECT Id, Completed_Build__c, Source__c, Target__c, Build__c, Build__r.Source__c, Build__r.Target__c FROM Deployment__c WHERE Name = :deploymentName];
        System.assertEquals(false, slingshot.hasSaveErrors, 'There should be no save error when not changing name of existing deployment');
        System.assertEquals(1, createdDeployments.size(), 'Only one deployment with a given name should exist for a release');
    }

    static testMethod void saveDeployment_deploymentNameAlreadyExists() {
        setup();

        String deploymentName = 'new deployment';
        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        slingshot.serializedClientDataBundle = getDataBundleJSON(deploymentName, null);
        slingshot.sourceInstanceId = instance.Id;
        slingshot.targetInstanceId = instance2.Id;
        slingshot.saveDeployment();

        SlingshotControllerExt2 slingshot2 = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot2.serializedClientDataBundle = getDataBundleJSON(deploymentName, null);
        slingshot2.sourceInstanceId = instance.Id;
        slingshot2.targetInstanceId = instance2.Id;

        Test.startTest();
            slingshot2.saveDeployment();
        Test.stopTest();

        List<Deployment__c> createdDeployments = [SELECT Id, Completed_Build__c, Source__c, Target__c, Build__c, Build__r.Source__c, Build__r.Target__c FROM Deployment__c WHERE Name = :deploymentName];
        System.assertEquals(true, slingshot2.hasSaveErrors, 'There should be a save error when using a deployment name that already exists');
        System.assertEquals(1, createdDeployments.size(), 'Only one deployment with a given name should exist for a release');
    }

    static testMethod void validateDeploymentName() {
        setup();

        String deploymentName = 'new deployment';
        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        slingshot.serializedClientDataBundle = getDataBundleJSON(deploymentName, null);
        slingshot.sourceInstanceId = instance.Id;
        slingshot.targetInstanceId = instance2.Id;
        slingshot.saveDeployment();

        slingshot.serializedClientDataBundle = getDataBundleJSON(deploymentName, null);
        slingshot.sourceInstanceId = instance.Id;
        slingshot.targetInstanceId = instance2.Id;

        Test.startTest();
            Boolean isValidDeploymentName = slingshot.validateDeploymentName(null);
        Test.stopTest();

        System.assertEquals(false, isValidDeploymentName, 'The deployment name should be invalid since it already exists');
    }


    static testMethod void saveAsDeployment_afterFirstSave() {
        setup();

        String deploymentName = 'new deployment';
        String deploymentName2 = 'another new deployment';
        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        slingshot.serializedClientDataBundle = getDataBundleJSON(deploymentName, null);
        slingshot.saveDeployment();

        Test.startTest();
            slingshot.serializedClientDataBundle = getDataBundleJSON(deploymentName2, null, instance.Id, instance.Id);
            slingshot.saveAsDeployment();
        Test.stopTest();

        List<Deployment__c> createdDeployments = [SELECT Id, Name, Completed_Build__c, Source__c, Target__c, Build__c, Build__r.Source__c, Build__r.Target__c FROM Deployment__c ];

        System.assertEquals(2, createdDeployments.size(), 'We expect two deployments to be created.');
        Map<String, Deployment__c> deploymentMap = new Map<String, Deployment__c>();
        for (Deployment__c d : createdDeployments ){
            deploymentMap.put(d.Name, d);
        }


        System.assert(deploymentMap.containsKey(deploymentName), 'The first deployment record should exist.');
        System.assert(deploymentMap.containsKey(deploymentName2), 'The second deployment record should be created.');

        Deployment__c originalDeployment = deploymentMap.get(deploymentName);
        Deployment__c savedNewDeployment = deploymentMap.get(deploymentName2);

        System.assertNotEquals(null, savedNewDeployment.Build__c, 'The new deployment record should have an associated build.');
        System.assertNotEquals(originalDeployment.Build__c, savedNewDeployment.Build__c,
          'The deployment records should have different builds.');

        for (Deployment__c deployment : createdDeployments){
            System.assertEquals(instance.Id, deployment.Source__c, 'The source should be set on the deployment');
            System.assertEquals(instance.Id, deployment.Build__r.Source__c, 'The source should be set on the build');
            System.assertEquals(null, deployment.Completed_Build__c, 'The completed build should be blank');
        }

        System.assertEquals(instance2.Id, originalDeployment.Target__c, 'The target should remain the same on the original deployment');
        System.assertEquals(instance2.Id, originalDeployment.Build__r.Target__c, 'The target should remain the same on the original build');
        System.assertEquals(instance.Id, savedNewDeployment.Target__c, 'The target should be updated on the new deployment');
        System.assertEquals(instance.Id, savedNewDeployment.Build__r.Target__c, 'The target should be updated on the new build');

    }

    static testMethod void saveAsDeployment_afterLoadDeployment() {
        setup();

        String deploymentName = 'new deployment';
        String deploymentName2 = 'another new deployment';


        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Deployment__c testDeployment = new Deployment__c(Name = deploymentName,
            Release__c = release.Id, Build__c = build.Id, Source__c = instance.Id, Target__c = instance2.Id);
        insert testDeployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        slingshot.selectedDeploymentId = testDeployment.Id;
        slingshot.loadDeployment();

        Test.startTest();
            slingshot.serializedClientDataBundle = getDataBundleJSON(deploymentName2, null, instance.Id, instance.Id);
            slingshot.saveAsDeployment();
        Test.stopTest();

        List<Deployment__c> createdDeployments = [SELECT Id, Name, Completed_Build__c, Source__c, Target__c, Build__c, Build__r.Source__c, Build__r.Target__c FROM Deployment__c ];

        System.assertEquals(2, createdDeployments.size(), 'We expect two deployments to be created.');
        Map<String, Deployment__c> deploymentMap = new Map<String, Deployment__c>();
        for (Deployment__c d : createdDeployments ){
            deploymentMap.put(d.Name, d);
        }

        System.assert(deploymentMap.containsKey(deploymentName), 'The first deployment record should exist.');
        System.assert(deploymentMap.containsKey(deploymentName2), 'The second deployment record should be created.');

        Deployment__c originalDeployment = deploymentMap.get(deploymentName);
        Deployment__c savedNewDeployment = deploymentMap.get(deploymentName2);

        System.assertNotEquals(null, savedNewDeployment.Build__c, 'The new deployment record should have an associated build.');
        System.assertNotEquals(originalDeployment.Build__c, savedNewDeployment.Build__c,
          'The deployment records should have different builds.');

        for (Deployment__c deployment : createdDeployments){
            System.assertEquals(instance.Id, deployment.Source__c, 'The source should be set on the deployment');
            System.assertEquals(null, deployment.Completed_Build__c, 'The completed build should be blank');
        }

        System.assertEquals(null, originalDeployment.Build__r.Source__c, 'The Build Source__c should remain the same on the original build');
        System.assertEquals(null, originalDeployment.Build__r.Target__c, 'The target should remain the same on the original build');
        System.assertEquals(instance.Id, savedNewDeployment.Build__r.Source__c, 'The Build Source__c should be set on the new build');
        System.assertEquals(instance2.Id, originalDeployment.Target__c, 'The target should remain the same on the original deployment');
        System.assertEquals(instance.Id, savedNewDeployment.Target__c, 'The target should be updated on the new deployment');
        System.assertEquals(instance.Id, savedNewDeployment.Build__r.Target__c, 'The target should be updated on the new build');
    }

    static testMethod void saveAsDeployment_unDocumentedComponents_persistOnOriginalDeployment() {
        setup();

        String originalDeploymentName = 'original deployment';
        String newDeploymentName = 'new deployment';

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        Build_Component__c buildComponentOne = new Build_Component__c (
                Type__c = AssemblerManifestRecord.UNDOCUMENTED, Build__c = build.Id );
        Build_Component__c buildComponentTwo = new Build_Component__c (
                Type__c = AssemblerManifestRecord.UNDOCUMENTED, Build__c = build.Id );
        insert new List<Build_Component__c> { buildComponentOne, buildComponentTwo };

        Deployment__c originalDeployment = new Deployment__c(Name = originalDeploymentName,
                Release__c = release.Id, Build__c = build.Id, Source__c = instance.Id, Target__c = instance2.Id);
        insert originalDeployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = originalDeployment.Id;

        slingshot.loadDeployment();
        slingshot.assembler.loadManifest();

        for (AssemblerManifestRecord amr : slingshot.assembler.undocumentedComponents) {
            slingshot.assembler.selectedComponentIdString +=
                    (String.isBlank(slingshot.assembler.selectedComponentIdString) ? '' : ',') + amr.getKey();
        }

        Test.startTest();
            slingshot.assembler.removeUndocumentedComponents();
            slingshot.serializedClientDataBundle = getDataBundleJSON(newDeploymentName, null, instance.Id, instance.Id);
            slingshot.saveAsDeployment();
        Test.stopTest();

        Set<Id> oldBuildComponents = new Map<Id, Build_Component__c>(
                [SELECT Id, Build__c FROM Build_Component__c WHERE Build__c =: build.Id]).keySet();

        System.assertNotEquals(originalDeployment.Id, slingshot.deployment.Id,
                'The deployment loaded on slingshot should be different from the original deployment.');
        System.assertEquals(0, slingshot.assembler.undocumentedComponents.size(),
                'The new deployment should not have any undocumented build components.');
        System.assertEquals(2, oldBuildComponents.size(),
                'The old deployment should still have the two undocumented build components.');
        System.assert(oldBuildComponents.contains(buildComponentOne.Id),
                'The old deployments set should contain the first build component Id.');
        System.assert(oldBuildComponents.contains(buildComponentTwo.Id),
                'The old deployments set should contain the second build component Id.');
    }

    static testMethod void saveDeployment_existingCompletedBuild() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id, Status__c=BuildServices.STATUS_SUCCESS);
        insert build;

        Deployment__c deployment = new Deployment__c(Release__c=release.Id, Name='Deployment 1', Build__c = build.Id);
        deployment.Completed_Build__c = build.Id;
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.serializedClientDataBundle = getDataBundleJSON(deployment.Name, build.Id);
        slingshot.loadDeployment();

        Test.startTest();
            slingshot.saveDeployment();
        Test.stopTest();

        Deployment__c updatedDeployment = [SELECT Id, Build__c, Completed_Build__c FROM Deployment__c WHERE Id = :deployment.Id];

        System.assertEquals(build.Id, updatedDeployment.Completed_Build__c, 'The completed build should not be overwritten by the new build');
        System.assertNotEquals(updatedDeployment.Build__c, updatedDeployment.Completed_Build__c, 'The new build should be saved on the Deployment');
    }

    static testMethod void saveDeployment_TwoInstancesOfControllerWithSameDeployment_DifferentBuilds() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id, Status__c=BuildServices.STATUS_SUCCESS);
        insert build;

        Deployment__c deployment = new Deployment__c(Release__c=release.Id, Name='Deployment 1', Build__c = build.Id);
        deployment.Completed_Build__c = build.Id;
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        SlingshotControllerExt2 slingshot2 = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.serializedClientDataBundle = getDataBundleJSON(deployment.Name, build.Id);
        slingshot.loadDeployment();

        slingshot2.selectedDeploymentId = deployment.Id;
        slingshot2.serializedClientDataBundle = getDataBundleJSON(deployment.Name, build.Id);
        slingshot2.loadDeployment();

        Test.startTest();
            slingshot.saveDeployment();
            slingshot2.saveDeployment();
        Test.stopTest();

        System.assert(slingshot.hasSaveErrors == false, 'The first save deployment should not have page errors');
        System.assert(slingshot2.hasSaveErrors, 'The second save deployment should have page errors');
        
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertEquals(1, messages.size(), 'There should only be one page message');
        System.assertEquals(Label.CURRENTLY_IN_PROGRESS, messages[0].getSummary());

     }

    static testMethod void saveDeployment_TwoInstancesOfControllerWithSameDeployment_SameBuild_DifferentCompletedBuilds() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id, Status__c=BuildServices.STATUS_NOT_STARTED);
        insert build;

        Deployment__c deployment = new Deployment__c(Release__c=release.Id, Name='Deployment 1', Build__c = build.Id);
        deployment.Completed_Build__c = null;
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        SlingshotControllerExt2 slingshot2 = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.serializedClientDataBundle = getDataBundleJSON(deployment.Name, build.Id);
        slingshot.loadDeployment();

        slingshot2.selectedDeploymentId = deployment.Id;
        slingshot2.serializedClientDataBundle = getDataBundleJSON(deployment.Name, build.Id);
        slingshot2.loadDeployment();

        Test.startTest();
            slingshot.saveDeployment();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.DEPLOYMENTS_ACTION));
            build.status__c= BuildServices.STATUS_SUCCESS;
            update build;
            slingshot2.saveDeployment();
        Test.stopTest();

        System.assert(slingshot.hasSaveErrors == false, 'The first save deployment should not have page errors');
        System.assert(slingshot2.hasSaveErrors, 'The second save deployment should have page errors');
        
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertEquals(1, messages.size(), 'There should only be one page message');
        System.assertEquals(Label.CURRENTLY_IN_PROGRESS, messages[0].getSummary());
    }

    static testMethod void saveDeployment_validSetup_returnsDeploymentSaveResult() {
        setup();

        Build__c build = new Build__c(Release__c=release.Id);
        insert build;

        Test.startTest();
            SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
            slingshot.serializedClientDataBundle = getDataBundleJSON('Test Deploy', null);
            slingshot.saveDeployment();
        Test.stopTest();

        System.assertEquals(0, ApexPages.getMessages().size(), 'Deployment should be saved successfully in this case.');
    }

    static testMethod void saveDeployment_emptyName_returnsDeploymentSaveResult() {
        setup();

        Build__c build = new Build__c(Release__c=release.Id, Status__c = 'Complete');
        insert build;

        // Insert duplicate deployment
        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id);
        insert deployment;

        Test.startTest();
            SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
            slingshot.serializedClientDataBundle = getDataBundleJSON('', null);

            slingshot.saveDeployment();
        Test.stopTest();

        System.assertEquals(1, ApexPages.getMessages().size(), 'Deployment should fail because the name cannot be blank');
    }

    static testMethod void saveDeployment_duplicateName_returnsDeploymentSaveResult() {
        setup();

        Build__c build = new Build__c(Release__c=release.Id, Status__c = 'Complete');
        insert build;

        // Insert duplicate deployment
        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id);
        insert deployment;

        Test.startTest();
            SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
            slingshot.serializedClientDataBundle = getDataBundleJSON('Test Deploy', null);
            slingshot.saveDeployment();
        Test.stopTest();

        System.assertEquals(1, ApexPages.getMessages().size(), 'Deployment should fail because there is a duplicate deployment with same name.');
    }

    static testMethod void saveDeployment_longName_correctedName() {
        setup();

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.serializedClientDataBundle = getDataBundleJSON('x'.repeat(81), null);
        slingshot.saveDeployment();

        System.assert(ApexPages.hasMessages(), 'Deployment should fail because the deployment name is too long.');
        System.assert(slingshot.hasSaveErrors, 'Deployment should fail because the deployment name is too long.');

        Test.startTest();
            slingshot.serializedClientDataBundle = getDataBundleJSON('corrected_name', null);
            slingshot.saveDeployment();
        Test.stopTest();

        System.assert(!slingshot.hasSaveErrors, 'Saved Deployment should succeed because the name has been corrected. ');

    }

    static testMethod void saveDeployment_buildExist_longName_correctedName() {
        setup();

        Build__c build = new Build__c(Release__c=release.Id, Status__c = 'Complete');
        insert build;

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c=build.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.loadDeployment();

        slingshot.deployment.Id = null;
        slingshot.serializedClientDataBundle = getDataBundleJSON('x'.repeat(81), null);
        slingshot.saveDeployment();

        System.assert(slingshot.hasSaveErrors, 'Saved Deployment should fail because the name is too long.');

        Test.startTest();
            slingshot.serializedClientDataBundle = getDataBundleJSON('another_name', null);
            slingshot.saveDeployment();
        Test.stopTest();

        List<Build__c> currentBuilds = [Select Id from Build__c];

        System.assertEquals(1, currentBuilds.size(), 'There should only be one build for this deployment.');
        System.assert(!slingshot.hasSaveErrors, 'Saved Deployment should succeed because the name has been corrected. ');

    }

    static testMethod void saveDeployment_getSavedDeployments_buildStatusCheck() {
        setup();

        final String EXPECTED_STATUS = 'FailedBuild';

        Build__c build = TestingUtils.buildBuild(release.Id, true);
        build.Status__c = EXPECTED_STATUS;
        insert build;

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c = build.Id);
        insert deployment;

        Test.startTest();

            List<DeploymentModel> savedDeployments =  SlingshotControllerExt2.getSavedDeployments(release.Id);

        Test.stopTest();

        System.assertEquals(1, savedDeployments.size(), 'There should be one saved deployment attempt.');
        System.assertEquals(deployment.Id, savedDeployments[0].record.Id, 'There should be one saved deployment attempt.');
        System.assertEquals(EXPECTED_STATUS, savedDeployments[0].buildStatus, 'The deployment build status should be correct.');
    }

    static testMethod void saveDeployment_getSavedDeployments_repoSource() {
        setup();

        VC_Repository__c repo = TestingUtils.createVcRepository('git-repo', 'http://www.git.com', 'GitHub', 'GitTest');

        Build__c build = TestingUtils.buildBuild(release.Id, true);
        build.Status__c = BuildServices.STATUS_NOT_STARTED;
        build.Source_Repository__c = repo.Id;
        insert build;

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c = build.Id);
        insert deployment;

        Test.startTest();

            List<DeploymentModel> savedDeployments =  SlingshotControllerExt2.getSavedDeployments(release.Id);

        Test.stopTest();

        System.assertEquals(1, savedDeployments.size(), 'There should be one saved deployment attempt.');
        System.assertEquals(repo.Name, savedDeployments[0].sourceInstanceName, 'The deployment source instance name should be set to the repository.');
    }

    static testMethod void saveDeployment_getSavedDeployments_returnsSavedDeployments() {
        setup();

        Build__c build = TestingUtils.createBuild(release.Id, true);

        // Create a new deployment attempt to query for
        Deployment_Attempt__c dt = new Deployment_Attempt__c(
            Release__c = release.Id,
            Is_Validation__c = true
        );
        insert dt;

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Deployment_Attempt__c = dt.Id, Build__c = build.Id);
        insert deployment;

        Test.startTest();

            List<DeploymentModel> savedDeployments =  SlingshotControllerExt2.getSavedDeployments(release.Id);

        Test.stopTest();

        System.assertEquals(1, savedDeployments.size(), 'There should be one saved deployment attempt.');
        System.assertEquals(deployment.Id, savedDeployments[0].record.Id, 'There should be one saved deployment attempt.');
        System.assertEquals(true, savedDeployments[0].isValidation, 'The deployment should be marked as a valididation.');
        System.assertEquals(false, savedDeployments[0].isDeploy, 'The deployment should only be marked as a validation.');
        System.assertEquals(true, savedDeployments[0].isManualUpload, 'Manual uploads should be treated as such.');
        System.assertEquals(0, savedDeployments[0].codeCoverageErrorCount, 'The codeCoverageErrorCount should be 0 and not null');
    }

    static testMethod void saveDeployment_getSavedDeployments_codeCoverageErrors() {
        setup();

        Build__c build = TestingUtils.createBuild(release.Id, true);

        // Create a new deployment attempt to query for
        Deployment_Attempt__c dt = new Deployment_Attempt__c(
            Release__c = release.Id,
            Is_Validation__c = false
        );
        insert dt;

        List<ALM_Error__c> errorRecords = new List<ALM_Error__c>();
        errorRecords.add(new ALM_Error__c(Deployment_Attempt__c=dt.Id,
            RecordTypeId=ALMErrorServices.getCodeCoverageRecordTypeId()));
        errorRecords.add(new ALM_Error__c(Deployment_Attempt__c=dt.Id,
            RecordTypeId=ALMErrorServices.getApexRecordTypeId()));
        
        insert errorRecords;


        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Deployment_Attempt__c = dt.Id, Build__c = build.Id);
        insert deployment;

        Test.startTest();

            List<DeploymentModel> savedDeployments =  SlingshotControllerExt2.getSavedDeployments(release.Id);

        Test.stopTest();

        System.assertEquals(1, savedDeployments.size(), 'There should be one saved deployment attempt.');
        System.assertEquals(deployment.Id, savedDeployments[0].record.Id, 'There should be one saved deployment attempt.');
        System.assertEquals(1, savedDeployments[0].codeCoverageErrorCount, 'there should be one error');
    }

    static DeploymentModel saveDeployment_getSavedDeployments_isInProgress(String status) {
        setup();

        Build__c build = TestingUtils.createBuild(release.Id, true);

        // Create a new deployment attempt to query for
        Deployment_Attempt__c dt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id, status, 0, 0, 0, false, 0, 0);

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Deployment_Attempt__c = dt.Id, Build__c = build.Id);
        insert deployment;

        Test.startTest();

            List<DeploymentModel> savedDeployments =  SlingshotControllerExt2.getSavedDeployments(release.Id);

        Test.stopTest();

        System.assertEquals(1, savedDeployments.size(), 'There should be one saved deployment attempt.');
        System.assertEquals(deployment.Id, savedDeployments[0].record.Id, 'There should be one saved deployment attempt.');

        return savedDeployments[0];
    }

    static testMethod void saveDeployment_getSavedDeployments_isInProgress_canceled() {
        DeploymentModel savedDeployment = saveDeployment_getSavedDeployments_isInProgress(DeploymentServices.STATUS_CANCELED);

        System.assertEquals(false, savedDeployment.isInProgress, 'The canceled deployment should not be marked as in-progress.');
    }

    static testMethod void saveDeployment_getSavedDeployments_isInProgress_failed() {
        DeploymentModel savedDeployment = saveDeployment_getSavedDeployments_isInProgress(DeploymentServices.STATUS_FAILED);

        System.assertEquals(false, savedDeployment.isInProgress, 'The failed deployment should not be marked as in-progress.');
    }

    static testMethod void saveDeployment_getSavedDeployments_isInProgress_inProgress() {
        DeploymentModel savedDeployment = saveDeployment_getSavedDeployments_isInProgress(DeploymentServices.STATUS_IN_PROGRESS);

        System.assertEquals(true, savedDeployment.isInProgress, 'The in-progress deployment should be marked as in-progress.');
    }

    static testMethod void saveDeployment_getSavedDeployments_isInProgress_notStarted() {
        DeploymentModel savedDeployment = saveDeployment_getSavedDeployments_isInProgress(DeploymentServices.STATUS_NOT_STARTED);

        System.assertEquals(true, savedDeployment.isInProgress, 'The not-started deployment should be marked as in-progress.');
    }

    static testMethod void saveDeployment_getSavedDeployments_isInProgress_pending() {
        DeploymentModel savedDeployment = saveDeployment_getSavedDeployments_isInProgress(DeploymentServices.STATUS_PENDING);

        System.assertEquals(true, savedDeployment.isInProgress, 'The pending deployment should be marked as in-progress.');
    }

    static testMethod void saveDeployment_getSavedDeployments_isInProgress_success() {
        DeploymentModel savedDeployment = saveDeployment_getSavedDeployments_isInProgress(DeploymentServices.STATUS_SUCCESS);

        System.assertEquals(false, savedDeployment.isInProgress, 'The success deployment should not be marked as in-progress.');
    }

    static testMethod void getSavedDeployments_noDeploymentAttempt() {
        setup();

        Build__c build = new Build__c(Release__c=release.Id);
        insert build;

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy', Release__c = release.Id, Build__c = build.Id, Source__c = instance.Id);
        insert deployment;

        Test.startTest();

            List<DeploymentModel> savedDeployments =  SlingshotControllerExt2.getSavedDeployments(release.Id);

        Test.stopTest();

        System.assertEquals(1, savedDeployments.size(), 'There should be one saved deployment attempt.');
        System.assertEquals(deployment.Id, savedDeployments[0].record.Id, 'There should be one saved deployment attempt.');
        System.assertEquals(false, savedDeployments[0].isValidation, 'The deployment should be marked as a valididation only when it has started.');
        System.assertEquals(false, savedDeployments[0].isDeploy, 'The deployment should be marked as a deployment only when it has started.');
        System.assertEquals(instance.Name, savedDeployments[0].sourceInstanceName, 'The souce name should be populated when it is set.');
        System.assertEquals('', savedDeployments[0].targetInstanceName, 'The target name should be blank when it is not set.');
    }

    static testMethod void loadDeployment() {
        setup();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy',
            Release__c = release.Id, Build__c = build.Id, Source__c = instance.Id, Target__c = instance2.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        Test.startTest();
            slingshot.selectedDeploymentId = deployment.Id;
            slingshot.loadDeployment();
        Test.stopTest();

        System.assertEquals(deployment.Id, slingshot.deployment.Id, 'The selected deployment should be loaded.');
        System.assertNotEquals(build.Id, slingshot.assembler.build.Id, 'The build from the deployment should not be the same as the original.');
        System.assertEquals(instance.Id, slingshot.sourceInstanceId, 'The source instance should be loaded.');
        System.assertEquals(instance2.Id, slingshot.targetInstanceId, 'The target instance should be loaded.');
    }

    static testMethod void checkBuildStatus() {
        setup();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Test.startTest();
            BuildModel bModel = SlingshotControllerExt2.checkBuildStatus(build.Id);
        Test.stopTest();

        System.assertNotEquals(null, bModel, 'We expect to get back a Build Model');
        System.assertEquals(build.Status__c, bModel.buildStatus, 'We expect to get back the correct Build Status');
        System.assertEquals(null, bModel.webAssemblerFailureMessage, 'This build should NOT have a web assembler error message.');
    }

    static testMethod void checkBuildStatus_makesCalloutForStatus() {
        setup();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_GET_ACTION));
            BuildModel bModel = SlingshotControllerExt2.checkBuildStatus(build.Id);
        Test.stopTest();

        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, bModel.buildStatus, 'The build status should be updated from the web service response');
        System.assertEquals(null, bModel.webAssemblerFailureMessage, 'This build should NOT have a web assembler error message.');

        Build__c updatedBuild = [SELECT Id, Status__c FROM Build__c WHERE Id = :build.Id];
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, updatedBuild.Status__c, 'The build status should be updated in the db from the response');
    }

    static testMethod void checkBuildStatus_makesCalloutForStatus_updateFailureReason() {
        setup();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Deployment_Attempt__c deployAttempt = new Deployment_Attempt__c();
        deployAttempt.Release__c = release.Id;
        deployAttempt.Build__c = build.Id;
        insert deployAttempt;

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_GET_FAILED_ACTION));
            BuildModel bModel = SlingshotControllerExt2.checkBuildStatus(build.Id);
        Test.stopTest();

        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, bModel.buildStatus,
            'The build status should be updated from the web service response');
        System.assertEquals(MockWebAssemblerAPI.FAILURE_REASON, bModel.webAssemblerFailureMessage,
             'This build should have the web assembler failure reason.');

        Build__c updatedBuild = [SELECT Id, Status__c FROM Build__c WHERE Id = :build.Id];
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, updatedBuild.Status__c,
             'The build status should be updated in the db from the response');

        Deployment_Attempt__c updatedAttempt =
             [SELECT Id, Assemble_Request_Error__c FROM Deployment_Attempt__c WHERE Id = :deployAttempt.Id];
         System.assertEquals(MockWebAssemblerAPI.FAILURE_REASON, updatedAttempt.Assemble_Request_Error__c,
             'This deployment attempt should be updated with the failure reason.');
    }

    static testMethod void checkBuildStatus_withWebAssemblerFailure() {
        setup();

        final String EXPECTED_WEB_ASSEMBLER_MSG = 'Web Assembler Failed.';

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_FAILURE);

        Deployment_Attempt__c deploymentAttempt = new Deployment_Attempt__c(
            Build__c = build.Id,
            Status__c = DeploymentServices.STATUS_SUCCESS,
            Assemble_Request_Error__c = EXPECTED_WEB_ASSEMBLER_MSG,
            Target_Instance__c = instance.Id
        );
        insert deploymentAttempt;

        Test.startTest();
            BuildModel bModel = SlingshotControllerExt2.checkBuildStatus(build.Id);
        Test.stopTest();

        System.assertNotEquals(null, bModel, 'We expect to get back a Build Model');
        System.assertEquals(build.Status__c, bModel.buildStatus, 'We expect to get back the correct Build Status');
        System.assertEquals(EXPECTED_WEB_ASSEMBLER_MSG, bModel.webAssemblerFailureMessage, 'This build should have a web assembler error message.');
    }

    static testMethod void checkBuildStatus_invalidId() {

        BuildModel bModel;

        Test.startTest();
            try {
                bModel = SlingshotControllerExt2.checkBuildStatus(UserInfo.getUserId());
                System.assert(false, 'We expect an ALM Exception to have been thrown.');
            } catch (ALMException e){
                System.assert(true, 'We expect to have an error thrown when the id is invalid');
            }
        Test.stopTest();

        System.assertEquals(null, bModel, 'We expect to get back a null Build Model.');
    }

    static testMethod void loadDeployment_undocumentedComps() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id, Status__c = BuildServices.STATUS_SUCCESS);
        insert build;

        Component__c undocumentedComponent = createUndocumentedComponent('Test comp');

        Build_Component__c undocumentedBuildComponent =
            createUndocumentedManifestRecord(undocumentedComponent, instance.Name).getBuildComponent();
        undocumentedBuildComponent.Build__c = build.Id;
        insert undocumentedBuildComponent;
        String DEPLOYMENT_NAME = 'Test Deploy';
        Deployment__c deployment = new Deployment__c(Name = DEPLOYMENT_NAME,
            Release__c = release.Id, Build__c = build.Id, Source__c = instance.Id, Target__c = instance2.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.serializedClientDataBundle = getDataBundleJSON(DEPLOYMENT_NAME, null);

        Test.startTest();
            slingshot.loadDeployment();
            slingshot.saveDeployment();
        Test.stopTest();

        System.assertEquals(1,
            slingshot.assembler.undocumentedComponents.size(),
            'Assembler should have 1 undocumented component'
        );
        System.assertEquals(1,
            [select Id from Build_Component__c where Build__c = :slingshot.assembler.build.Id].size(),
            'The loaded build should have undocumented components'
        );
    }

    private static SlingshotControllerExt2 createSlingshot_WithDeployment_OneDocumentedAndOneUndocumentedComp() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id, Status__c = BuildServices.STATUS_SUCCESS);
        insert build;

        //creates undocumented component
        Component__c undocumentedComponent = createUndocumentedComponent('Test comp');
        AssemblerManifestRecord undocRecord1 = createUndocumentedManifestRecord(undocumentedComponent, instance.Name);
        Build_Component__c undocumentedBuildComponent = undocRecord1.getBuildComponent();
        undocumentedBuildComponent.Build__c = build.Id;
        insert undocumentedBuildComponent;

        //creates documented component
        Backlog__c backlogItem = TestingUtils.buildBacklogItem();
		backlogItem.Release__c = release.Id;
		insert backlogItem;
        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(backlogItem.Id, instance);
        TestingUtils.createDocumentedBuildComponent(backlogComponent, build.Id, instance.name);

        //creates deployment
        String DEPLOYMENT_NAME = 'Test Deploy';
        Deployment__c deployment = new Deployment__c(Name = DEPLOYMENT_NAME,
            Release__c = release.Id, Build__c = build.Id, Source__c = instance.Id, Target__c = instance2.Id);
        insert deployment;
        
        //creates the SlingshotConrtollerExt2 and loads deployment and manifest
        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;
        slingshot.serializedClientDataBundle = getDataBundleJSON(deployment.Name, null);
        slingshot.loadDeployment();
        slingshot.assembler.loadManifest();

        return slingshot;
    }
    
    static testMethod void savedIsRemovedValue_loadManifest() {
        SlingshotControllerExt2 slingshot = createSlingshot_WithDeployment_OneDocumentedAndOneUndocumentedComp();
        System.assertEquals(1, slingshot.assembler.manifest.size(), 'There should be one documented component');
        System.assertEquals(1, slingshot.assembler.undocumentedComponents.size(), 'There should be one undocumented component');
        System.assertEquals(false, slingshot.assembler.manifest[0].isRemoved,
         'Documented component should not show up as removed at last save');
        System.assertEquals(false, slingshot.assembler.manifest[0].savedIsRemovedValue,
         'Documented component should not show up as removed');
        System.assertEquals(false, slingshot.assembler.undocumentedComponents[0].savedIsRemovedValue, 
            'savedIsRemoved should be false for an undocumented component whenever loadDeployment is called,' +
             ' since deployment has been saved');
        System.assertEquals(false, slingshot.assembler.undocumentedComponents[0].isRemoved, 'isRemoved should be false');
    }

    static testMethod void savedIsRemovedValue_addUndocumentedComponent() {
        SlingshotControllerExt2 slingshot = createSlingshot_WithDeployment_OneDocumentedAndOneUndocumentedComp();

        Component__c undocumentedComponent2 = createUndocumentedComponent('Test comp2');
        AssemblerManifestRecord unsavedRecord = createUndocumentedManifestRecord(undocumentedComponent2, instance.Name);
        
        Test.startTest();
            slingshot.assembler.undocumentedComponents.add(unsavedRecord);
        Test.stopTest();
       
        System.assertEquals(2, slingshot.assembler.undocumentedComponents.size(), 'Assembler should have 2 undocumented components');
        System.assertEquals(true, unsavedRecord.savedIsRemovedValue, 'savedIsRemoved should be true');
        System.assertEquals(false, unsavedRecord.isRemoved, 'isRemoved should be false');
    }

    static testMethod void savedIsRemovedValue_addUndocumentedComponent_andSave() {
        SlingshotControllerExt2 slingshot = createSlingshot_WithDeployment_OneDocumentedAndOneUndocumentedComp();

        Component__c undocumentedComponent2 = createUndocumentedComponent('Test comp2');
        AssemblerManifestRecord unsavedRecord = createUndocumentedManifestRecord(undocumentedComponent2, instance.Name);
        slingshot.assembler.undocumentedComponents.add(unsavedRecord);
        
        Test.startTest();
            slingshot.saveDeployment();  
        Test.stopTest();  

        for (AssemblerManifestRecord amr: slingshot.assembler.undocumentedComponents) {
            System.assertEquals(false, amr.savedIsRemovedValue, 'savedIsRemoved should be false');
            System.assertEquals(false, amr.isRemoved, 'isRemoved should be false');
        }
    }

    static testMethod void savedIsRemovedValue_removeDocumentedComponent() {
        SlingshotControllerExt2 slingshot = createSlingshot_WithDeployment_OneDocumentedAndOneUndocumentedComp();

        Test.startTest();
            //Mark documented as removed and save deployment
            slingshot.assembler.manifest[0].isRemoved = true;
            slingshot.saveDeployment();  
        Test.stopTest();  

        System.assertEquals(true, slingshot.assembler.manifest[0].isRemoved, 'It should show up as removed at last save');
        System.assertEquals(true, slingshot.assembler.manifest[0].savedIsRemovedValue, 'It should show up as removed');
    }

    static testMethod void loadDeployment_populatedSpecifiedTests() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id, Status__c = BuildServices.STATUS_SUCCESS);
        insert build;

        String testSpecifiedTests = 'TestAssembler,TestRevisions';
        Deployment_Attempt__c specifiedTestsDeployment = TestingUtils.createDeploymentAttempt(release.Id, instance.Id, 100,1,76, true);
        specifiedTestsDeployment.Specified_Tests__c = testSpecifiedTests;
        update specifiedTestsDeployment;

        Deployment__c deployment = new Deployment__c(Name = 'Test Deploy',
                Release__c = release.Id, Build__c = build.Id, Source__c = instance.Id, Target__c = instance2.Id, Deployment_Attempt__c = specifiedTestsDeployment.Id);
        insert deployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.selectedDeploymentId = deployment.Id;

        Test.startTest();
            slingshot.loadDeployment();
        Test.stopTest();

        System.assertEquals( testSpecifiedTests, slingshot.specifiedTestClasses,
                        'The loaded deployment should have loaded the specified tests: /"' + testSpecifiedTests + '/".'
        );
    }

    static testMethod void isDeploymentSettingsChanged_newDeployment() {
        setup();

        Test.startTest();
            SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Test.stopTest();

        System.assertEquals(false, slingshot.isDeploymentSettingsChanged, 'New deployments should be marked as not changed');
    }

    static testMethod void clearDeploymentErrors() {
        setup();

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.deploymentErrors.buildErrors.add(new ALM_Error__c(Status__c='error1'));
        slingshot.deploymentErrors.apexErrors.add(new ALM_Error__c(Status__c='error2'));
        slingshot.deploymentErrors.componentErrors.add(new ALM_Error__c(Status__c='error3'));

        Test.startTest();
            slingshot.clearDeploymentErrors();
        Test.stopTest();

        System.assert(slingshot.deploymentErrors.buildErrors.isEmpty(), 'All build errors should be cleared.');
        System.assert(slingshot.deploymentErrors.apexErrors.isEmpty(), 'All apex errors should be cleared.');
        System.assert(slingshot.deploymentErrors.componentErrors.isEmpty(), 'All component errors should be cleared.');
    }

    static testMethod void clearDeploymentErrors_onStartAssembler() {

        setup();

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        slingshot.sourceInstanceId = instance.Id;
        slingshot.targetInstanceId = instance2.Id;

        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        TestingUtils.createAuthUser(UserInfo.getUserId(), instance2.Id);

        slingshot.deploymentErrors.buildErrors.add(new ALM_Error__c(Status__c='error1'));
        slingshot.deploymentErrors.apexErrors.add(new ALM_Error__c(Status__c='error2'));
        slingshot.deploymentErrors.componentErrors.add(new ALM_Error__c(Status__c='error3'));

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));
            slingshot.startAssembler();
        Test.stopTest();

        System.assert(slingshot.deploymentErrors.buildErrors.isEmpty(), 'All build errors should be cleared when startAssembler is called.');
        System.assert(slingshot.deploymentErrors.apexErrors.isEmpty(), 'All apex errors should be cleared when startAssembler is called.');
        System.assert(slingshot.deploymentErrors.componentErrors.isEmpty(), 'All component errors should be cleared when startAssembler is called.');
    }

    static testMethod void clearDeploymentErrors_null() {
        setup();

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.deploymentErrors = null;

        Test.startTest();
            try {
                slingshot.clearDeploymentErrors();
            } catch (Exception e) {
                System.assert(false, 'No exception should be thrown on a null deployment errors list.');
            }
        Test.stopTest();

        System.assertEquals(null, slingshot.deploymentErrors, 'The deployment errors list should be null.');
    }

    static testMethod void isDeploymentSettingsChanged_changedSource() {
        setup();

        Build__c completedBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        completedBuild.Source__c = instance.Id;
        update completedBuild;

        Deployment__c savedDeployment = new Deployment__c(Completed_Build__c = completedBuild.Id, Name='d', Release__c = release.Id);
        savedDeployment.Source__c = instance2.Id;
        insert savedDeployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Test.startTest();
            slingshot.selectedDeploymentId = savedDeployment.Id;
            slingshot.loadDeployment();
        Test.stopTest();

        System.assertEquals(true, slingshot.isDeploymentSettingsChanged, 'Deployments with a changed source instance be marked as changed');
    }

    static testMethod void isDeploymentSettingsChanged_changedTarget() {
        setup();

        Build__c completedBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        completedBuild.Target__c = instance.Id;
        update completedBuild;

        Deployment__c savedDeployment = new Deployment__c(Completed_Build__c = completedBuild.Id, Name='d', Release__c = release.Id);
        savedDeployment.Target__c = instance2.Id;
        insert savedDeployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Test.startTest();
            slingshot.selectedDeploymentId = savedDeployment.Id;
            slingshot.loadDeployment();
        Test.stopTest();

        System.assertEquals(true, slingshot.isDeploymentSettingsChanged, 'Deployments with a changed target instance be marked as changed');
    }

    static testMethod void isDeploymentSettingsChanged_noChanges() {
        setup();

        Build__c completedBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        completedBuild.Source__c = instance.Id;
        completedBuild.Target__c = instance2.Id;
        update completedBuild;

        Deployment__c savedDeployment = new Deployment__c(Completed_Build__c = completedBuild.Id, Name='d', Release__c = release.Id);
        savedDeployment.Source__c = instance.Id;
        savedDeployment.Target__c = instance2.Id;
        insert savedDeployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Test.startTest();
            slingshot.selectedDeploymentId = savedDeployment.Id;
            slingshot.loadDeployment();
        Test.stopTest();

        System.assertEquals(false, slingshot.isDeploymentSettingsChanged, 'Deployments with no changes should be marked as not changed');
    }





    static testMethod void cancelDeployment_validSetup() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.DEPLOYMENTS_CANCEL_ACTION));
        setup();
        TestingUtils.createOAuthSettings();
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        Build__c completedBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        completedBuild.Source__c = instance.Id;
        completedBuild.Target__c = instance2.Id;
        update completedBuild;

        Auth_User__c authUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        Deployment_Attempt__c deploymentAttempt = new Deployment_Attempt__c(
            Build__c = completedBuild.Id,
            Status__c = DeploymentServices.STATUS_IN_PROGRESS,
            Target_Instance__c = instance.Id
        );
        insert deploymentAttempt;

        Deployment__c savedDeployment = new Deployment__c(Completed_Build__c = completedBuild.Id, Name='d', Release__c = release.Id);
        savedDeployment.Source__c = instance.Id;
        savedDeployment.Target__c = instance2.Id;
        savedDeployment.Build__c = completedBuild.Id;
        savedDeployment.Deployment_Attempt__c = deploymentAttempt.Id;
        insert savedDeployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.deployment = savedDeployment;

        Test.startTest();
            slingshot.cancelDeployment();
        Test.stopTest();

        System.assert(!ApexPages.hasMessages(), 'The request should be submitted successfully (no page messages)');
    }

    static testMethod void cancelDeployment_noDeploymentsAvailable_addsMessage() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.DEPLOYMENTS_CANCEL_ACTION));
        setup();

        Build__c completedBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        completedBuild.Source__c = instance.Id;
        completedBuild.Target__c = instance2.Id;
        update completedBuild;

        Deployment_Attempt__c deploymentAttempt = new Deployment_Attempt__c(
            Build__c = completedBuild.Id,
            Status__c = DeploymentServices.STATUS_SUCCESS,
            Target_Instance__c = instance.Id
        );
        insert deploymentAttempt;

        Deployment__c savedDeployment = new Deployment__c(Completed_Build__c = completedBuild.Id, Name='d', Release__c = release.Id);
        savedDeployment.Source__c = instance.Id;
        savedDeployment.Target__c = instance2.Id;
        savedDeployment.Build__c = completedBuild.Id;
        savedDeployment.Deployment_Attempt__c = deploymentAttempt.Id;
        insert savedDeployment;

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.deployment = savedDeployment;

        Test.startTest();
            slingshot.cancelDeployment();
        Test.stopTest();

        ApexPages.Message[] messages = ApexPages.getMessages();
        System.assert(!messages.isEmpty(), 'The request should not be successful');
        System.assert(TestingUtils.pageMessageContains(System.Label.Slingshot_cancel_error), 'The request should fail due to no in progress deployments');
    }

    static testMethod void handleUpdatePackageUrlFailure() {
        setup();

        Build__c validBuild = new Build__c(Release__c=release.Id);
        validBuild.Manual_Upload__c = true;

        Build__c invalidBuild = new Build__c(Release__c=release.Id);
        invalidBuild.Manual_Upload__c = true;
        insert new List<Build__c>{validBuild, invalidBuild};

        Deployment__c validDeployment = new Deployment__c(Name = 'valid.zip', Release__c = release.Id, Build__c = validBuild.Id);
        Deployment__c invalidDeployment = new Deployment__c(Name = 'invalid.zip', Release__c = release.Id, Build__c = invalidBuild.Id);
        insert new List<Deployment__c> {validDeployment, invalidDeployment};

        Test.startTest();

            SlingshotControllerExt2.handleUpdatePackageUrlFailure(invalidBuild.Id);

        Test.stopTest();

        System.assertEquals(null, BuildServices.getBuild(invalidBuild.Id), 'The invalid build should have been deleted.');
        System.assertEquals(null, DeploymentServices.getDeploymentByBuildId(invalidBuild.Id), 'The invalid deployment should have been deleted.');
    }

    static void createErrors(Integer buildErrorsSize, Integer componentErrorsSize, Integer apexErrorsSize, Deployment_Attempt__c deploymentAttempt, Build__c build) {
        List<ALM_Error__c> buildErrors = new List<ALM_Error__c>();
        for (Integer i = 0; i < buildErrorsSize; ++i) {
            buildErrors.add(new ALM_Error__c(Description__c='ALM Build Error' + i, Build__c=build.Id));
        }
        insert buildErrors;

        Id componentRecordTypeId = ALM_Error__c.sObjectType.getDescribe().getRecordTypeInfosByName().get('Component').getRecordTypeId();
        List<ALM_Error__c> componentErrors = new List<ALM_Error__c>();
        for (Integer i = 0; i < componentErrorsSize; ++i) {
            componentErrors.add(new ALM_Error__c(Description__c='ALM Component Error' + i, Deployment_Attempt__c=deploymentAttempt.Id, RecordTypeId=componentRecordTypeId));
        }
        insert componentErrors;

        Id apexRecordTypeId = ALM_Error__c.sObjectType.getDescribe().getRecordTypeInfosByName().get('Apex').getRecordTypeId();
        List<ALM_Error__c> apexErrors = new List<ALM_Error__c>();
        for (Integer i = 0; i < apexErrorsSize; ++i) {
            apexErrors.add(new ALM_Error__c(Error_Message__c='ALM Apex Error' + i, Deployment_Attempt__c=deploymentAttempt.Id, RecordTypeId=apexRecordTypeId));
        }
        insert apexErrors;
    }

    static void chunkDeploymentErrors(Integer buildErrorsSize, Integer componentErrorsSize, Integer apexErrorsSize, Integer chunkSize) {
        setup();

        Deployment_Attempt__c deploymentAttempt = TestingUtils.createDeploymentAttempt(release.Id, instance.Id, 0, 0, 0, false);
        Build__c build = TestingUtils.createBuild(release.Id, false);
        Deployment__c deployment = TestingUtils.createDeployment(release.Id);
        deployment.Deployment_Attempt__c = deploymentAttempt.Id;
        deployment.Build__c = build.Id;
        update deployment;

        createErrors(buildErrorsSize, componentErrorsSize, apexErrorsSize, deploymentAttempt, build);

        SlingshotControllerExt2 testSlingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testSlingshot.deployment = deployment;
        testSlingshot.selectedDeploymentId = deployment.Id;
        testSlingshot.loadDeployment();

        // Get the chunked errors.
        Test.startTest();
            List<List<ALM_Error__c>> chunkedBuildErrors = testSlingshot.chunkList(testSlingshot.deploymentErrors.buildErrors, chunkSize);
            List<List<ALM_Error__c>> chunkedComponentErrors = testSlingshot.chunkList(testSlingshot.deploymentErrors.componentErrors, chunkSize);
            List<List<ALM_Error__c>> chunkedApexErrors = testSlingshot.chunkList(testSlingshot.deploymentErrors.apexErrors, chunkSize);
        Test.stopTest();

        // Assert that the chunked lists are the proper size.
        Integer chunkedBuildErrorsSize = 0;
        for (Integer i = 0; i < chunkedBuildErrors.size(); ++i) {
            chunkedBuildErrorsSize += chunkedBuildErrors.get(i).size();
        }
        Integer chunkedComponentErrorsSize = 0;
        for (Integer i = 0; i < chunkedComponentErrors.size(); ++i) {
            chunkedComponentErrorsSize += chunkedComponentErrors.get(i).size();
        }
        Integer chunkedApexErrorsSize = 0;
        for (Integer i = 0; i < chunkedApexErrors.size(); ++i) {
            chunkedApexErrorsSize += chunkedApexErrors.get(i).size();
        }
        System.assertEquals(testSlingshot.deploymentErrors.buildErrors.size(), chunkedBuildErrorsSize, 'The build errors chunked list should be the correct size.');
        System.assertEquals(testSlingshot.deploymentErrors.componentErrors.size(), chunkedComponentErrorsSize, 'The component errors chunked list should be the correct size.');
        System.assertEquals(testSlingshot.deploymentErrors.apexErrors.size(), chunkedApexErrorsSize, 'The apex errors chunked list should be the correct size.');

        // Assert that the chunked lists are properly-chunked version of their respective unchunked counterparts.
        for (Integer i = 0; i < chunkedBuildErrors.size(); ++i) {
            for (Integer j = 0; j < chunkedBuildErrors.get(i).size(); ++j) {
                System.assertEquals(chunkedBuildErrors.get(i).get(j).Description__c, testSlingshot.deploymentErrors.buildErrors[(i * chunkSize) + j].Description__c, 'The build error descriptions should match.');
            }
        }
        for (Integer i = 0; i < chunkedComponentErrors.size(); ++i) {
            for (Integer j = 0; j < chunkedComponentErrors.get(i).size(); ++j) {
                System.assertEquals(chunkedComponentErrors.get(i).get(j).Description__c, testSlingshot.deploymentErrors.componentErrors[(i * chunkSize) + j].Description__c, 'The component error descriptions should match.');
            }
        }
        for (Integer i = 0; i < chunkedApexErrors.size(); ++i) {
            for (Integer j = 0; j < chunkedApexErrors.get(i).size(); ++j) {
                System.assertEquals(chunkedApexErrors.get(i).get(j).Error_Message__c, testSlingshot.deploymentErrors.apexErrors[(i * chunkSize) + j].Error_Message__c, 'The apex error messages should match.');
            }
        }
    }

    static testMethod void chunkDeploymentErrors_emptyErrors() {
        chunkDeploymentErrors(0, 0, 0, 10);
    }

    static testMethod void chunkDeploymentErrors_totalUnderChunkSize() {
        chunkDeploymentErrors(3, 3, 3, 10);
    }

    static testMethod void chunkDeploymentErrors_totalEqualsChunkSize() {
        chunkDeploymentErrors(3, 4, 3, 10);
    }

    static testMethod void chunkDeploymentErrors_totalOverChunkSize() {
        chunkDeploymentErrors(5, 5, 5, 10);
    }

    static testMethod void validateAuth_valid() {
        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();

        setup();

        Auth_User__c almAuth = TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        SlingshotControllerExt2 testSlingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Integer beforeSize = testSlingshot.pageMessageManager.messages.size();

        System.assert(testSlingshot.isAuthValid, 'Auth validity should initialize to true.');

        Test.startTest();

            testSlingshot.validateAuth();

        Test.stopTest();

        System.assert(testSlingshot.isAuthValid, 'Auth validity should still be true.');
        System.assertEquals(beforeSize, testSlingshot.pageMessageManager.messages.size(), 'No further page messages should be added.');
    }

    static testMethod void validateAuth_invalid_noALMInstance() {
        setup();

        delete almInstance;

        SlingshotControllerExt2 testSlingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Integer beforeSize = testSlingshot.pageMessageManager.messages.size();

        Test.startTest();

            testSlingshot.validateAuth();

        Test.stopTest();

        System.assertEquals(false, testSlingshot.isAuthValid, 'Auth validity should be false when no ALM instance exists.');
        System.assertEquals(beforeSize + 1, testSlingshot.pageMessageManager.messages.size(), 'One further page message should be added.');
    }

    static testMethod void validateAuth_invalid_noALMInstanceAuthUser() {
        setup();

        SlingshotControllerExt2 testSlingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Integer beforeSize = testSlingshot.pageMessageManager.messages.size();

        Test.startTest();

            testSlingshot.validateAuth();

        Test.stopTest();

        System.assertEquals(false, testSlingshot.isAuthValid, 'Auth validity should be false when no ALM instance auth user exists.');
        System.assertEquals(beforeSize + 1, testSlingshot.pageMessageManager.messages.size(), 'One further page message should be added.');
    }

    static testMethod void validateAuth_invalid_badHTTP() {
        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();

        setup();

        Auth_User__c almAuth = TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        SlingshotControllerExt2 testSlingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Integer beforeSize = testSlingshot.pageMessageManager.messages.size();

        Test.startTest();

            testSlingshot.validateAuth();

        Test.stopTest();

        System.assertEquals(false, testSlingshot.isAuthValid, 'Auth validity should be false when a bad HTTP response is received.');
        System.assertEquals(beforeSize + 1, testSlingshot.pageMessageManager.messages.size(), 'One further page message should be added.');
    }

    static testMethod void removePageMessage_ID() {
        setup();

        String testMessageId = 'Test Message ID';
        String testMessageContent = 'Test Message Content';
        PageMessage testMessage = new PageMessage(testMessageId, ApexPages.Severity.ERROR, testMessageContent, false);

        SlingshotControllerExt2 testSlingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testSlingshot.pageMessageManager.addMessage(testMessage);
        Integer beforeSize = testSlingshot.pageMessageManager.messages.size();

        Test.startTest();

            try {
                testSlingshot.pageMessageToRemove = testMessageId;
                testSlingshot.removePageMessage();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(beforeSize - 1, testSlingshot.pageMessageManager.messages.size(), 'There should one fewer message after removing a message.');
    }

    static testMethod void removePageMessage_null() {
        setup();

        SlingshotControllerExt2 testSlingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Integer beforeSize = testSlingshot.pageMessageManager.messages.size();

        Test.startTest();

            try {
                testSlingshot.pageMessageToRemove = null;
                testSlingshot.removePageMessage();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertEquals(beforeSize, testSlingshot.pageMessageManager.messages.size(), 'All messages should remain after not removing a message.');
    }

    private static testMethod void getAuthInfo_authUserIsForTools() {
        setup();

        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();

        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id, true);

        Test.startTest();

            OAuthRequest.UserInfoResponse response = SlingshotControllerExt2.getAuthInfo(instance.Id);

        Test.stopTest();

        System.assertEquals(false, response.isAuthorized, 'No matching auth user should be found.');
    }

    private static testMethod void retrieveBranches() {
        final String TEST_BRANCH_NAME = 'feature-branch';
        String successGitListResponse = MockVCAPI.setupGitListSuccessResponse( new List<String> { TEST_BRANCH_NAME } );
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(successGitListResponse));

        setupGitSSHSettings();

        VC_Repository__c vcRepository = new VC_Repository__c(
            Repository_URL__c = 'https://some-repo.com'
        );
        insert vcRepository;

        Test.startTest();

            List<String> branches = SlingshotControllerExt2.retrieveBranches(vcRepository.Id);

        Test.stopTest();

        System.assertNotEquals(null, branches, 'The branches result should be returned.');
        System.assertEquals(1, branches.size(), 'The branches result should be returned.');
        System.assertEquals(TEST_BRANCH_NAME, branches[0], 'The branches result should be returned.');
    }

    private static testMethod void retrieveBranches_errorResult() {
        final String TEST_LIST_FAILURE_REASON = 'Test Failure Reason';

        String failureResponse = MockVCAPI.setupGitListFailureResponse(TEST_LIST_FAILURE_REASON);
        Test.setMock(HttpCalloutMock.class, new MockVCAPI(failureResponse));

        setupGitSSHSettings();

        VC_Repository__c vcRepository = new VC_Repository__c(
            Repository_URL__c = 'https://some-repo.com'
        );
        insert vcRepository;

        Test.startTest();

            try {
                List<String> branches = SlingshotControllerExt2.retrieveBranches(vcRepository.Id);
                System.assert(false, 'An exception should be thrown when the request is not successful');
            } catch (Exception ae) {
                System.assert(ae instanceof ALMException, 'An ALMException be returned as the message.');
                System.assertEquals(TEST_LIST_FAILURE_REASON, ae.getMessage(), 'The failure reason should be set as the exception message.');
            }
        Test.stopTest();
    }


    private static testMethod void getCurrentPageStateMap_deployment_nullDeployment() {
        setup();

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.selectedDeploymentId = null;
        testController.loadDeployment();

        Test.startTest();

            Map<String, Object> actualPageStateMap = testController.getCurrentPageStateMap();

        Test.stopTest();

        System.assertEquals(0, actualPageStateMap.size(), 'The proper number of state elements should be retrieved properly.');
    }

    private static testMethod void getCurrentPageStateMap_deployment_nullDeploymentId() {
        setup();

        Deployment__c testDeployment = TestingUtils.createDeployment(release.Id);

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.selectedDeploymentId = testDeployment.Id;
        testController.loadDeployment();
        testController.deployment.Id = null;

        Test.startTest();

            Map<String, Object> actualPageStateMap = testController.getCurrentPageStateMap();

        Test.stopTest();

        System.assertEquals(0, actualPageStateMap.size(), 'The proper number of state elements should be retrieved properly.');
    }

    private static testMethod void getCurrentPageStateMap_deployment_valid() {
        setup();

        Deployment__c testDeployment = TestingUtils.createDeployment(release.Id);

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.selectedDeploymentId = testDeployment.Id;
        testController.loadDeployment();

        Test.startTest();

            Map<String, Object> actualPageStateMap = testController.getCurrentPageStateMap();

        Test.stopTest();

        System.assertEquals(1, actualPageStateMap.size(), 'The proper number of state elements should be retrieved properly.');
        System.assertEquals(testDeployment.Id, actualPageStateMap.get('deploymentId'), 'The deployment ID should be retrieved properly.');
    }

    private static testMethod void getCurrentPageStateMap_sourceInstanceId_null() {
        setup();

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.sourceInstanceId = null;

        Test.startTest();

            Map<String, Object> actualPageStateMap = testController.getCurrentPageStateMap();

        Test.stopTest();

        System.assertEquals(0, actualPageStateMap.size(), 'The proper number of state elements should be retrieved properly.');
    }

    private static testMethod void getCurrentPageStateMap_sourceInstanceId_valid() {
        setup();

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.sourceInstanceId = instance.Id;

        Test.startTest();

            Map<String, Object> actualPageStateMap = testController.getCurrentPageStateMap();

        Test.stopTest();

        System.assertEquals(1, actualPageStateMap.size(), 'The proper number of state elements should be retrieved properly.');
        System.assertEquals(instance.Id, actualPageStateMap.get('sourceInstanceId'), 'The source instance ID should be retrieved properly.');
    }

    private static testMethod void getCurrentPageStateMap_targetInstanceId_null() {
        setup();

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.targetInstanceId = null;

        Test.startTest();

            Map<String, Object> actualPageStateMap = testController.getCurrentPageStateMap();

        Test.stopTest();

        System.assertEquals(0, actualPageStateMap.size(), 'The proper number of state elements should be retrieved properly.');
    }

    private static testMethod void getCurrentPageStateMap_targetInstanceId_valid() {
        setup();

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.targetInstanceId = instance.Id;

        Test.startTest();

            Map<String, Object> actualPageStateMap = testController.getCurrentPageStateMap();

        Test.stopTest();

        System.assertEquals(1, actualPageStateMap.size(), 'The proper number of state elements should be retrieved properly.');
        System.assertEquals(instance.Id, actualPageStateMap.get('targetInstanceId'), 'The target instance ID should be retrieved properly.');
    }

    private static testMethod void getCurrentPageStateMap_bothInstanceIds_valid() {
        setup();

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.sourceInstanceId = instance.Id;
        testController.targetInstanceId = instance2.Id;

        Test.startTest();

            Map<String, Object> actualPageStateMap = testController.getCurrentPageStateMap();

        Test.stopTest();

        System.assertEquals(2, actualPageStateMap.size(), 'The proper number of state elements should be retrieved properly.');
        System.assertEquals(instance.Id, actualPageStateMap.get('sourceInstanceId'), 'The source instance ID should be retrieved properly.');
        System.assertEquals(instance2.Id, actualPageStateMap.get('targetInstanceId'), 'The target instance ID should be retrieved properly.');
    }

    private static testMethod void restorePageState_deployment_null() {
        setup();

        Map<String, Object> testPageStateMap = new Map<String, Object>{
            'deploymentId' => null
        };

        State.store(new PageState(SlingshotControllerExt2.PAGE_STATE_TOKEN, testPageStateMap));

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.loadDeployment();

        Id originalDeploymentId = testController.deployment.Id;

        Test.startTest();

            testController.restorePageState();

        Test.stopTest();

        System.assertEquals(originalDeploymentId, testController.deployment.Id, 'The deployment ID should not be restored.');
    }

    private static testMethod void restorePageState_deployment_valid() {
        setup();

        Deployment__c testDeployment = TestingUtils.createDeployment(release.Id);

        Map<String, Object> testPageStateMap = new Map<String, Object>{
            'deploymentId' => testDeployment.Id
        };

        State.store(new PageState(SlingshotControllerExt2.PAGE_STATE_TOKEN, testPageStateMap));

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        Test.startTest();

            testController.restorePageState();

        Test.stopTest();

        System.assertEquals(testDeployment.Id, testController.deployment.Id, 'The deployment ID should be restored properly.');
    }

    private static testMethod void restorePageState_sourceInstanceId() {
        setup();

        Map<String, Object> testPageStateMap = new Map<String, Object>{
            'sourceInstanceId' => instance.Id
        };

        State.store(new PageState(SlingshotControllerExt2.PAGE_STATE_TOKEN, testPageStateMap));

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        Test.startTest();

            testController.restorePageState();

        Test.stopTest();

        System.assertEquals(instance.Id, testController.sourceInstanceId, 'The source instance ID should be restored properly.');
    }

    private static testMethod void restorePageState_targetInstanceId() {
        setup();

        Map<String, Object> testPageStateMap = new Map<String, Object>{
            'targetInstanceId' => instance.Id
        };

        State.store(new PageState(SlingshotControllerExt2.PAGE_STATE_TOKEN, testPageStateMap));

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        Test.startTest();

            testController.restorePageState();

        Test.stopTest();

        System.assertEquals(instance.Id, testController.targetInstanceId, 'The target instance ID should be restored properly.');
    }

    private static testMethod void restorePageState_bothInstanceIds() {
        setup();

        Map<String, Object> testPageStateMap = new Map<String, Object>{
            'sourceInstanceId' => instance.Id,
            'targetInstanceId' => instance2.Id
        };

        State.store(new PageState(SlingshotControllerExt2.PAGE_STATE_TOKEN, testPageStateMap));

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));

        Test.startTest();

            testController.restorePageState();

        Test.stopTest();

        System.assertEquals(instance.Id, testController.sourceInstanceId, 'The source instance ID should be restored properly.');
        System.assertEquals(instance2.Id, testController.targetInstanceId, 'The target instance ID should be restored properly.');
    }

    private static testMethod void savePageState_deployment() {
        setup();

        Deployment__c testDeployment = TestingUtils.createDeployment(release.Id);

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.selectedDeploymentId = testDeployment.Id;
        testController.loadDeployment();

        Test.startTest();

            testController.savePageState();

        Test.stopTest();

        PageState actualPageState = new PageState(SlingshotControllerExt2.PAGE_STATE_TOKEN);
        State.retrieve(actualPageState);

        System.assertEquals(1, actualPageState.stateMap.size(), 'The proper number of state elements should be saved properly.');
        System.assertEquals(actualPageState.stateMap.get('deploymentId'), testController.deployment.Id, 'The deployment ID should be saved properly.');
    }

    private static testMethod void savePageState_instances() {
        setup();

        SlingshotControllerExt2 testController = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        testController.sourceInstanceId = instance.Id;
        testController.targetInstanceId = instance2.Id;

        Test.startTest();

            testController.savePageState();

        Test.stopTest();

        PageState actualPageState = new PageState(SlingshotControllerExt2.PAGE_STATE_TOKEN);
        State.retrieve(actualPageState);

        System.assertEquals(2, actualPageState.stateMap.size(), 'The proper number of state elements should be saved properly.');
        System.assertEquals(actualPageState.stateMap.get('sourceInstanceId'), testController.sourceInstanceId, 'The source instance ID should be saved properly.');
        System.assertEquals(actualPageState.stateMap.get('targetInstanceId'), testController.targetInstanceId, 'The target instance ID should be restored properly.');
    }

    private static testMethod void loadPageState_deployment() {
        setup();

        Deployment__c testDeployment = TestingUtils.createDeployment(release.Id);

        Map<String, Object> testPageStateMap = new Map<String, Object>{
            'selectedDeploymentId' => testDeployment.Id
        };

        State.store(new PageState(SlingshotControllerExt2.PAGE_STATE_TOKEN, testPageStateMap));

        Test.startTest();

            Map<String, Object> actualPageStateMap = new SlingshotControllerExt2(new ApexPages.StandardController(release)).loadPageState();

        Test.stopTest();

        System.assertEquals(testPageStateMap.size(), actualPageStateMap.size(), 'The proper number of state elements should be loaded properly.');
        System.assertEquals(testPageStateMap.get('selectedDeploymentId'), actualPageStateMap.get('selectedDeploymentId'), 'The selected deployment ID should be loaded properly.');
    }

    private static testMethod void loadPageState_instances() {
        setup();

        Map<String, Object> testPageStateMap = new Map<String, Object>{
            'sourceInstanceId' => instance.Id,
            'targetInstanceId' => instance2.Id
        };

        State.store(new PageState(SlingshotControllerExt2.PAGE_STATE_TOKEN, testPageStateMap));

        Test.startTest();

            Map<String, Object> actualPageStateMap = new SlingshotControllerExt2(new ApexPages.StandardController(release)).loadPageState();

        Test.stopTest();

        System.assertEquals(testPageStateMap.size(), actualPageStateMap.size(), 'The proper number of state elements should be loaded properly.');
        System.assertEquals(testPageStateMap.get('sourceInstanceId'), actualPageStateMap.get('sourceInstanceId'), 'The source instance ID should be loaded properly.');
        System.assertEquals(testPageStateMap.get('targetInstanceId'), actualPageStateMap.get('targetInstanceId'), 'The target instance ID should be loaded properly.');
    }

    private static testMethod void expirePageState() {
        setup();

        PageState testPageState = new PageState(SlingshotControllerExt2.PAGE_STATE_TOKEN);

        State.store(testPageState);

        System.assertEquals(1, [SELECT Count() FROM State__c WHERE Token__c = :testPageState.getStateToken()], 'The page state should exist.');

        Test.startTest();

            new SlingshotControllerExt2(new ApexPages.StandardController(release)).expirePageState();

        Test.stopTest();

        System.assertEquals(0, [SELECT Count() FROM State__c WHERE Token__c = :testPageState.getStateToken()], 'The page state should not exist.');
    }

    private static testMethod void loadAvailableTestClasses_withoutSpecifiedTests() {
        setup();

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.targetInstanceId = instance2.id;

        List<String> testClasses = new List<String> {'TestAssembler', 'TestRevisions', 'TestSlingshot'};
        setupTestApexComponents(testClasses, instance2);

        Test.startTest();

            slingshot.loadAvailableTestClasses();

        Test.stopTest();

        System.assertEquals(3, slingshot.availableTestClasses.split(',').size(),
                        'There should be three available test classes.');
        System.assert(slingshot.availableTestClasses.contains(testClasses[0]),
                        testClasses[0] + ' should belong in available test classes.');
        System.assert(slingshot.availableTestClasses.contains(testClasses[1]),
                        testClasses[1] + ' should belong in available test classes.');
        System.assert(slingshot.availableTestClasses.contains(testClasses[2]),
                        testClasses[2] + ' should belong in available test classes.');
    }

    private static testMethod void loadAvailableTestClasses_withSpecifiedTests() {
        setup();

        SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        slingshot.targetInstanceId = instance2.id;

        List<String> testClasses = new List<String> {'TestAssembler', 'TestRevisions', 'TestSlingshot'};
        setupTestApexComponents(testClasses, instance2);

        slingshot.specifiedTestClasses = testClasses[0] + ',' + testClasses[1];

        Test.startTest();
            slingshot.loadAvailableTestClasses();
        Test.stopTest();

        System.assertEquals(1, slingshot.availableTestClasses.split(',').size(),
                        'There should only be one available test class.');
        System.assertEquals(testClasses[2], slingshot.availableTestClasses,
                        testClasses[2] + ' should belong in available test classes.');
    }

    private static testMethod void loadAvailableSources_noSources() {
        release = new Release__c(Name='VC deployment');
        insert release;

        Test.startTest();
            SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Test.stopTest();

        System.assertEquals(0, slingshot.availableSources.size(), 'The available sources list should be empty when there are no sources');
    }

    private static testMethod void loadAvailableSources_onlyInstances() {
        release = new Release__c(Name='VC deployment');
        insert release;

        Instances__c instance = TestingUtils.buildInstance('src');
        instance.Type__c='Sandbox';
        insert instance;

        Test.startTest();
            SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Test.stopTest();

        System.assertEquals(1, slingshot.instancesCount, 'The available instance count should be set');
        System.assertEquals(0, slingshot.reposCount, 'The available repos count should be set');
        System.assertEquals(1, slingshot.availableSources.size(), 'The available sources list should contain the existing instances');
        System.assertEquals(instance.Id, slingshot.availableSources[0].id, 'The available instance should have its id populated');
        System.assertEquals(instance.Name, slingshot.availableSources[0].name, 'The available instance should have its name');
        System.assertEquals(instance.Type__c, slingshot.availableSources[0].instanceType, 'The available instance should have its instance type');
        System.assertEquals(true, slingshot.availableSources[0].isInstance, 'The available instance should be marked as an instance');
    }

    private static testMethod void loadAvailableSources_onlyRepos() {
        release = new Release__c(Name='VC deployment');
        insert release;

        VC_Repository__c repo = TestingUtils.createVcRepository('git-repo1', 'http://www.git.com/one', 'GitHub', 'bw-org');
        Test.startTest();
            SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Test.stopTest();

        System.assertEquals(0, slingshot.instancesCount, 'The available instance count should be set');
        System.assertEquals(1, slingshot.reposCount, 'The available repos count should be set');
        System.assertEquals(1, slingshot.availableSources.size(), 'The available sources list should contain the existing repos');
        System.assertEquals(repo.Id, slingshot.availableSources[0].id, 'The available repo should have its id populated');
        System.assertEquals(repo.Name, slingshot.availableSources[0].name, 'The available repo should have its name populated');
        System.assertEquals(repo.Repository_URL__c, slingshot.availableSources[0].repoUrl, 'The available instance should have its instance type populated');
        System.assertEquals(false, slingshot.availableSources[0].isInstance, 'The available repo should not be marked as an instance');
    }

    private static testMethod void loadAvailableSources() {
        release = new Release__c(Name='VC deployment');
        insert release;

        Instances__c instance1 = TestingUtils.buildInstance('za');
        instance1.Type__c='Sandbox';

        Instances__c instance2 = TestingUtils.buildInstance('Zz');
        instance2.Type__c='Sandbox';
        insert new List<Instances__c>{ instance1, instance2 };

        VC_Repository__c repo = TestingUtils.createVcRepository('git-repo1', 'http://www.git.com/one', 'GitHub', 'bw-org');
        Test.startTest();
            SlingshotControllerExt2 slingshot = new SlingshotControllerExt2(new ApexPages.StandardController(release));
        Test.stopTest();

        System.assertEquals(2, slingshot.instancesCount, 'The available instance count should be set');
        System.assertEquals(1, slingshot.reposCount, 'The available repos count should be set');
        System.assertEquals(3, slingshot.availableSources.size(), 'The available sources list should contain the existing repos and instances');
        System.assertEquals(repo.Id, slingshot.availableSources[0].id, 'The sources should be returned in alphabetical order');
        System.assertEquals(instance1.Id, slingshot.availableSources[1].id, 'The sources should be returned in alphabetical order');
        System.assertEquals(instance2.Id, slingshot.availableSources[2].id, 'The sources should be returned in alphabetical order');
    }

    private static testMethod void updateBuildWithVCInfo() {
        setup();

        Build__c build = new Build__c(Release__c=release.Id);
        insert build;

        Build__c build2 = new Build__c(Release__c=release.Id);
        insert build2;

        Deployment__c deployment = new Deployment__c(Release__c=release.Id, Name='saved deployment', Build__c=build2.Id);
        insert deployment;

        VC_Repository__c repo = TestingUtils.createVcRepository('git-repo1', 'http://www.git.com/one',
                'GitHub', 'GitTest1', Date.newInstance(2016, 2, 17), Date.newInstance(2017, 2, 17));

        Test.startTest();
            Id buildId = SlingshotControllerExt2.updateBuildWithVCInfo(release.Id, repo.Id, TestingUtils.TEST_BRANCH);
        Test.stopTest();

        Build__c buildFromDb = [select Source_Repository__r.Repository_URL__c, Source_Repository_Location__c from Build__c where Id = :buildId ];

        System.assertEquals(repo.Id, buildFromDb.Source_Repository__c);
        System.assertEquals(TestingUtils.TEST_BRANCH, buildFromDb.Source_Repository_Location__c);
    }

    private static testMethod void updateBuildWithVCInfo_Error_BadRepoId() {
        setup();

        Build__c build = new Build__c(Release__c=release.Id);
        insert build;

        Deployment__c deployment = new Deployment__c(Release__c=release.Id, Name='saved deployment', Build__c=build.Id);
        insert deployment;

        Test.startTest();
            try {
                // call updateBuildWithVCInfo passing in the release.Id instead of the repo.id
                Id buildId = SlingshotControllerExt2.updateBuildWithVCInfo(release.Id, release.Id, 'cool Branch');
                System.assert(false, 'We expect an Exception to have been thrown.');
            } catch (Exception ae) {
                System.assert(ae instanceof AuraHandledException, 'An AuraHandledException be returned as the message.');
            }
        Test.stopTest();
    }

    private static testMethod void updateBuildWithVCInfo_Error_EmptyRepoLocation() {
        setup();

        Build__c build = new Build__c(Release__c=release.Id);
        insert build;

        Deployment__c deployment = new Deployment__c(Release__c=release.Id, Name='saved deployment', Build__c=build.Id);
        insert deployment;

        Test.startTest();
            try {
                // call updateBuildWithVCInfo with empty repoLocation
                Id buildId = SlingshotControllerExt2.updateBuildWithVCInfo(release.Id, build.Id, '');
                System.assert(false, 'We expect an Exception to have been thrown.');
            } catch (Exception ae) {
                System.assert(ae instanceof AuraHandledException, 'An AuraHandledException be returned as the message.');
            }
        Test.stopTest();
    }

    // TODO: Reimplement this test when implementing the non-polling method and remove current assert in try
    private static testMethod void parseManualBuildPackage_invalidBuildId() {
        Test.startTest();
            try {
                SlingshotControllerExt2.parseManualBuildPackage('abc123-always-fail');
                //System.assert(false, 'An Exception should have been caught.');
                System.assert(true, 'No Exception should have been caught.');
            } catch (ALMException ae) {
                //System.assertEquals(SlingshotControllerExt2.INVALID_BUILD_ID_ERROR, ae.getMessage(),
                //    'The caught ALMException should have the invalid build id error message.');
            }
        Test.stopTest();
    }

    // TODO: Reimplement this test when implementing the non-polling method and remove current assert in try
    private static testMethod void parseManualBuildPackage_emptyBuildId() {
        Test.startTest();
            try {
                SlingshotControllerExt2.parseManualBuildPackage('');
                //System.assert(false, 'An Exception should have been caught.');
                System.assert(true, 'No Exception should have been caught.');
            } catch (ALMException ae) {
                //System.assertEquals(SlingshotControllerExt2.INVALID_BUILD_ID_ERROR, ae.getMessage(),
                //    'The caught ALMException should have the invalid build id error message.');
            }
        Test.stopTest();
    }

    private static testMethod void parseManualBuildPackage_badPostRequest() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.PARSE_BUILD_PACKAGE_FAIL_ACTION));
        TestingUtils.createOAuthSettings();
        Build__c build = new Build__c( Package_URL__c='space-man/on/roadster' );
        insert build;

        Test.startTest();
            try {
                SlingshotControllerExt2.parseManualBuildPackage(build.Id);
            } catch (ALMException ae) {
                System.assert(false, 'No Exception should have been caught.');
            }
        Test.stopTest();

        List<Build__c> queriedBuild = [ SELECT Id, Is_Manual_Package_Parsed__c, Manual_Package_Parse_Failure_Reason__c
                                        FROM Build__c 
                                        WHERE Id =:build.Id ];

        System.assertEquals(1, queriedBuild.size(), 
            'There should be one build returned with the provided Id.');
        
        String failureReason = queriedBuild[0].Manual_Package_Parse_Failure_Reason__c;
        System.assert(failureReason.startsWith(System.Label.Generic_Error) ,
            'The Manual_Package_Parse_Failure_Reason__c field should begin with the generic error value.');
        System.assert(failureReason.contains(MockWebAssemblerAPI.FAILURE_REASON),
            'The Manual_Package_Parse_Failure_Reason__c field should contain the post request failure reason.');
        System.assert(queriedBuild[0].Is_Manual_Package_Parsed__c , 
            'The Is_Manual_Package_Parsed__c field should have been set to true.');
    }
}
