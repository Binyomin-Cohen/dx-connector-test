@isTest
private class TestAssemblerRequest {

    static Build__c build;
    static Release__c release;
    static Instances__c instance;
    static Backlog__c backlog;
    static Auth_User__c authUser;
    static Auth_User__c testSightlineAuthUser;
    static ALM_Private__c almPrivate;

    static Component__c partialProfile;
    static Component__c partialProfile2;
    static Component__c entireProfile;
    static Component__c objectComponent;
    static Component__c manuallyDeployedObjectComponent;
    static Component__c fieldComponent;

    static String MANUALLY_DEPLOYED_COMPONENT_NAME = 'MANUALLY_DEPLOYED_COMPONENT';

    static void setup() {
        release = new Release__c(Name='Summer 14');
        insert release;

        instance = new Instances__c(Name='dev');
        insert instance;

        authUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        backlog = new Backlog__c(Release__c=release.Id, Status__c='Complete');
        insert backlog;

        build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        almPrivate = TestingUtils.createOAuthSettings();
        testSightlineAuthUser = TestingUtils.setupSightlineAuth();
    }

    static void setupProfilesWithDocumentedComponents(){
        setup();

        // Components
        partialProfile = TestingUtils.createComponent('Admin', 'Profile', instance.Id);
        partialProfile2 = TestingUtils.createComponent('Admin3', 'Profile', instance.Id);
        entireProfile = TestingUtils.createComponent('Admin2', 'Profile', instance.Id);
        objectComponent = TestingUtils.createComponent('Account', 'Object', instance.Id);
        manuallyDeployedObjectComponent =
            TestingUtils.createComponent(MANUALLY_DEPLOYED_COMPONENT_NAME, 'Object', instance.Id);
        fieldComponent = TestingUtils.buildComponent('Status__c', ComponentServices.FIELD_ALM_NAME, instance.Id);
        fieldComponent.Parent_Component__c = objectComponent.Id;
        fieldComponent.Parent_Component__r = objectComponent;
        insert fieldComponent;

        // Documented Components
        Backlog_Component__c partialProfileComp =
            TestingUtils.buildDocumentedProfile(backlog.Id, partialProfile, instance.Id);
        Backlog_Component__c partialProfileCompNoInclude =
            TestingUtils.buildDocumentedProfile(backlog.Id, partialProfile2, instance.Id);
        Backlog_Component__c entireProfileComp =
            TestingUtils.buildDocumentedProfile(backlog.Id, entireProfile, instance.Id);
        Backlog_Component__c objectBackComp =
            TestingUtils.buildDocumentedProfile(backlog.Id, objectComponent, instance.Id);
        Backlog_Component__c manualObjectBackComp =
            TestingUtils.buildDocumentedProfile(backlog.Id, manuallyDeployedObjectComponent, instance.Id);
        manualObjectBackComp.Deploy_Manually__c = true;

        insert new List<Backlog_Component__c> {partialProfileComp, partialProfileCompNoInclude,
                entireProfileComp, objectBackComp, manualObjectBackComp};

        // Create and add build components to the build
        Build_Component__c profileBuildComponent1 =
            TestingUtils.buildProfileBuildComponent(build.Id, partialProfileComp, null, false, true);
        Build_Component__c profileBuildComponent2 =
            TestingUtils.buildProfileBuildComponent(build.Id, entireProfileComp, null, true, false);
        Build_Component__c profileBuildComponent3 =
            TestingUtils.buildProfileBuildComponent(build.Id, partialProfileCompNoInclude, null, false, false);

        AssemblerManifestRecord acountObjManifestRecord =  new AssemblerManifestRecord(objectBackComp);
        Build_Component__c objectBuildComponent = acountObjManifestRecord.getBuildComponent();
        objectBuildComponent.Build__c = build.Id;

        AssemblerManifestRecord manualDepAcountObjManifestRecord =  new AssemblerManifestRecord(manualObjectBackComp);
        Build_Component__c manualDepObjectBuildComponent = manualDepAcountObjManifestRecord.getBuildComponent();
        manualDepObjectBuildComponent.Build__c = build.Id;
        manualDepObjectBuildComponent.Type__c = AssemblerManifestRecord.REMOVED;

        // Add one undocumented field
        AssemblerManifestRecord acountFieldManifestRecord =  new AssemblerManifestRecord(new ComponentSearchWrapper(fieldComponent, instance.Name, '', Datetime.now(), 'admin', false));
        Build_Component__c fieldBuildComponent = acountFieldManifestRecord.getBuildComponent();
        fieldBuildComponent.Build__c = build.Id;
        fieldBuildComponent.Type__c = AssemblerManifestRecord.UNDOCUMENTED;

        insert new List<Build_Component__c>{profileBuildComponent1, fieldBuildComponent, profileBuildComponent2, profileBuildComponent3, objectBuildComponent, manualDepObjectBuildComponent};
    }

    static testMethod void assemblerRequest_constructor() {
        String testTargetRefreshToken = 'Test Target Refresh Token';
        String testTargetInstanceURL = 'Test Target Instance URL';

        setup();
        OAuthServices.AppSettings testPrivateSettings = new OAuthServices.AppSettings(almPrivate);

        Auth_User__c targetAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        targetAuthUser.Refresh_Token__c = testTargetRefreshToken;
        targetAuthUser.Instance_URL__c = testTargetInstanceURL;

        Test.startTest();

            AssemblerRequest testRequest = new AssemblerRequest(build, targetAuthUser, false);

        Test.stopTest();

        System.assertEquals(build.Id, testRequest.buildId, 'The build ID should match.');
        System.assertEquals(targetAuthUser.Refresh_Token__c, testRequest.targetRefreshToken, 'The target refresh token should match.');
        System.assertEquals(targetAuthUser.Instance_URL__c + AssemblerRequest.SOAP_ENDPOINT, testRequest.targetEndpoint, 'The target endpoint should match.');
        System.assertEquals(testSightlineAuthUser.Refresh_Token__c, testRequest.sightlineRefreshToken, 'The Sightline refresh token should match.');
        System.assertEquals(testSightlineAuthUser.Instance_URL__c, testRequest.endpoint, 'The Sightline instance url should be set from the auth user.');
        System.assertEquals(testPrivateSettings.consumerKey, testRequest.clientId, 'The client ID should match.');
        System.assertEquals(testPrivateSettings.consumerSecret, testRequest.clientSecret, 'The client secret should match.');
    }

    static testMethod void assemblerRequest_profileData() {
        setup();

        partialProfile = TestingUtils.createComponent('Admin', 'Profile', instance.Id);
        entireProfile = TestingUtils.createComponent('Admin2', 'Profile', instance.Id);
        Backlog_Component__c partialProfileComp = TestingUtils.buildDocumentedProfile(backlog.Id, partialProfile, instance.Id);
        Backlog_Component__c entireProfileComp = TestingUtils.buildDocumentedProfile(backlog.Id, entireProfile, instance.Id);

        ProfilePermissions perms1 = new ProfilePermissions();
        TestingUtils.buildProfilePermissionsSection(perms1, 's1', new List<String> {'permission1'});
        ProfilePermissions.Section section = perms1.sections[0];

        insert new List<Backlog_Component__c> {partialProfileComp, entireProfileComp};

        Build_Component__c profileBuildComponent1 = TestingUtils.buildProfileBuildComponent(build.Id, partialProfileComp, perms1, false, false);
        Build_Component__c profileBuildComponent2 = TestingUtils.buildProfileBuildComponent(build.Id, entireProfileComp, null, true, false);

        insert new List<Build_Component__c>{profileBuildComponent1, profileBuildComponent2};

        Test.startTest();

            AssemblerRequest request = new AssemblerRequest(build, authUser, false);

        Test.stopTest();

        System.assertEquals(2, request.components.size(), 'The profile marked as include entire profile should be treated as a normal component');
        System.assertEquals(entireProfile.Name, request.components[1][0], 'The profile marked as include entire profile should be treated as a normal component');
        System.assertEquals(entireProfile.Type__c, request.components[1][1], 'The profile marked as include entire profile should be treated as a normal component');

        System.assertEquals(1, request.profiles.size(), 'The profile not marked as include entire profile should be treated as a profile component');

        ProfilePermissions storedProfile = request.profiles[0];
        System.assertEquals(partialProfile.Name, storedProfile.Name, 'The profile name should be set on the profile JSON');
        System.assertEquals(section.apiName, storedProfile.sections[0].apiName, 'The profile selections should be set on the profile JSON');
    }

    static testMethod void assemblerRequest_profileFieldLevelSecurity() {
        setup();

        Component__c profile = TestingUtils.createComponent('Admin', 'Profile', instance.Id);
        Component__c parentObjectComponent = TestingUtils.createComponent('Backlog__c', ComponentServices.OBJECT_ALM_NAME, instance.Id);
        Component__c fieldComponent1 = TestingUtils.buildComponent('Status__c', ComponentServices.FIELD_ALM_NAME, instance.Id);
        fieldComponent1.Parent_Component__c = parentObjectComponent.Id;

        Component__c fieldComponent2 = TestingUtils.buildComponent('Status2__c', ComponentServices.FIELD_ALM_NAME, instance.Id);
        fieldComponent2.Parent_Component__c = parentObjectComponent.Id;

        insert new List<Component__c> {fieldComponent1, fieldComponent2};

        Backlog_Component__c profileComp = TestingUtils.buildDocumentedProfile(backlog.Id, profile, instance.Id);
        Backlog_Component__c documentedField1 = TestingUtils.buildDocumentedComponent(backlog.Id, fieldComponent1, instance.Id);
        Backlog_Component__c documentedField2 = TestingUtils.buildDocumentedComponent(backlog.Id, fieldComponent2, instance.Id);

        insert new List<Backlog_Component__c> {profileComp, documentedField1, documentedField2};

        ProfilePermissions selectedPermissions = new ProfilePermissions();
        TestingUtils.buildProfilePermissionsSection(selectedPermissions,
             ProfileServices.FIELD_API_NAME, new List<String> {parentObjectComponent.Name});

        Build_Component__c profileBuildComponent = TestingUtils.buildProfileBuildComponent(build.Id, profileComp, selectedPermissions, false, false);

        Build_Component__c field1BuildComponent = (new AssemblerManifestRecord(documentedField1)).getBuildComponent();
        field1BuildComponent.Build__c = build.Id;

        Build_Component__c field2BuildComponent = (new AssemblerManifestRecord(documentedField2)).getBuildComponent();
        field2BuildComponent.Build__c = build.Id;

        insert new List<Build_Component__c> { profileBuildComponent, field1BuildComponent, field2BuildComponent };

        Test.startTest();

            AssemblerRequest request = new AssemblerRequest(build, authUser, false);

        Test.stopTest();

        System.assertEquals(1, request.profiles.size(), 'The documented profile should be included in the request');

        ProfilePermissions actualPermissions = request.profiles[0];

        System.assertEquals(profile.Name, actualPermissions.name, 'The documented profile should be included in the request');

        System.assertEquals(1, actualPermissions.sections.size(), 'The FLS section should be included in the profile');
        System.assertEquals(selectedPermissions.sections[0].apiName, actualPermissions.sections[0].apiName, 'The FLS section should be included in the profile');

        ProfilePermissions.Section actualFLSSection = actualPermissions.sections[0];

        System.assertEquals(2, actualFLSSection.permissions.size(), 'The object permissions should be expanded to the documented fields');

        Set<String> expectedFieldNames = new Set<String> {
            parentObjectComponent.Name + '.' + fieldComponent1.Name,
            parentObjectComponent.Name + '.' + fieldComponent2.Name
        };

        System.assert(expectedFieldNames.containsAll(actualFLSSection.permissions), 'The object permissions should be expanded to the documented fields');
    }

    static testMethod void assemblerRequestProfileData_populateDocumentedComponents() {

        String EXPECTED_OBJ_SECTION_NAME = 'objectPermissions';
        String EXPECTED_FIELD_SECTION_NAME = 'fieldPermissions';

        setupProfilesWithDocumentedComponents();

        Test.startTest();

            AssemblerRequest request = new AssemblerRequest(build, authUser, false);

        Test.stopTest();

        System.assertEquals(4, request.components.size(), 'The profile marked as include entire profile should be treated as a normal component');
        Map<String, List<String>> componentMap = new Map<String, List<String>>();
        for (Integer i = 1; i < request.components.size(); i++){
            componentMap.put(request.components[i][0], request.components[i]);
        }
        System.assert(componentMap.containsKey(entireProfile.Name), 'We expect the entire profile to be documented');
        System.assert(componentMap.containsKey(objectComponent.Name), 'We expect the object to be documented');
        System.assertEquals(entireProfile.Name, componentMap.get(entireProfile.Name)[0],
            'The profile marked as include entire profile should be treated as a normal component');
        System.assertEquals(entireProfile.Type__c, componentMap.get(entireProfile.Name)[1],
            'The profile marked as include entire profile should be treated as a normal component');
        System.assertEquals(objectComponent.Name, componentMap.get(objectComponent.Name)[0],
            'The object should be treated as a normal component');
        System.assertEquals(objectComponent.Type__c, componentMap.get(objectComponent.Name)[1],
            'The object should be treated as a normal component');
        System.assertEquals(fieldComponent.Name, componentMap.get(fieldComponent.Name)[0],
            'The object should be treated as a normal component');
        System.assertEquals(fieldComponent.Type__c, componentMap.get(fieldComponent.Name)[1],
            'The object should be treated as a normal component');

        System.assertEquals(2, request.profiles.size(), 'The profile not marked as include entire profile should be treated as a profile component');

        Map<String, ProfilePermissions> storedProfileMap = new Map<String, ProfilePermissions>();
        for (ProfilePermissions profilePerm : request.profiles){
            storedProfileMap.put(profilePerm.Name, profilePerm);
        }

        System.assert(storedProfileMap.containsKey(partialProfile.Name), 'We expect the partial profiles to be present.');
        System.assert(storedProfileMap.containsKey(partialProfile2.Name), 'We expect the partial profiles to be present.');
        System.assertEquals(partialProfile.Name, storedProfileMap.get(partialProfile.Name).Name,
            'The profile name should be set on the profile JSON');
        System.assertEquals(partialProfile2.Name, storedProfileMap.get(partialProfile2.Name).Name,
            'The profile name should be set on the profile JSON');


        ProfilePermissions storedProfile = storedProfileMap.get(partialProfile.Name);
        ProfilePermissions storedProfileWithNoInclude = storedProfileMap.get(partialProfile2.Name);

        System.assert(storedProfileWithNoInclude.sections.isEmpty(), 'We do NOT expect to have documented sections in the build.' + storedProfileWithNoInclude.sections);

        System.assert(!storedProfile.sections.isEmpty(), 'We expect to have documented sections in the build.');
        Map<String, ProfilePermissions.Section> sectionMap = new Map<String, ProfilePermissions.Section>();
        for (ProfilePermissions.Section sect : storedProfile.sections){
            sectionMap.put(sect.apiName, sect);
        }
        System.assert(sectionMap.containsKey(EXPECTED_OBJ_SECTION_NAME), 'We expect to have documented objects in the profile build');
        System.assert(sectionMap.containsKey(EXPECTED_FIELD_SECTION_NAME), 'We expect to have documented fields in the profile build');

        List<String> EXPECTED_OBJ_PERMISSIONS = NEW List<String>{'Account'};
        List<String> EXPECTED_FIELD_PERMISSIONS = NEW List<String>{'Account.Status__c'};
        System.assert((new Set<String>(sectionMap.get(EXPECTED_OBJ_SECTION_NAME).permissions)).containsAll(EXPECTED_OBJ_PERMISSIONS),
            'The profile selection permissions should be set on the profile JSON');
        System.assert((new Set<String>(sectionMap.get(EXPECTED_FIELD_SECTION_NAME).permissions)).containsAll(EXPECTED_FIELD_PERMISSIONS),
            'The profile selection permissions should be set on the profile JSON');

    }

    static testMethod void manuallyDeployedBacklogComponentsAreFiltered() {
        setupProfilesWithDocumentedComponents();

        Test.startTest();
            AssemblerRequest request = new AssemblerRequest(build, authUser, false);
        Test.stopTest();

        System.assert(request.components.size() > 0, 'The request should have components');

        // Attempt to find the manually deployed component in the manifest.
        Boolean foundManuallyDeployedComponent = false;
        for (List<String> component : request.components) {
            if (component[0].equals(MANUALLY_DEPLOYED_COMPONENT_NAME)) {
                foundManuallyDeployedComponent = true;
            }
        }
        System.assert(!foundManuallyDeployedComponent,
                      'We should not find the manually deployed component in the AssemblerRequest components');
    }

    static testMethod void manuallyDeployedBacklogComponentsCanBeDeployed() {
        setupProfilesWithDocumentedComponents();

        Build_Component__c manualDepObjectBuildComponent = [SELECT Id, Type__c FROM Build_Component__c WHERE Backlog_Component__r.Component__c = :manuallyDeployedObjectComponent.Id];
        manualDepObjectBuildComponent.Type__c = AssemblerManifestRecord.DOCUMENTED;
        update manualDepObjectBuildComponent;

        Test.startTest();
            AssemblerRequest request = new AssemblerRequest(build, authUser, false);
        Test.stopTest();

        System.assert(request.components.size() > 0, 'The request should have components');

        // Attempt to find the manually deployed component in the manifest.
        Boolean foundManuallyDeployedComponent = false;
        for (List<String> component : request.components) {
            if (component[0].equals(MANUALLY_DEPLOYED_COMPONENT_NAME)) {
                foundManuallyDeployedComponent = true;
            }
        }
        System.assert(foundManuallyDeployedComponent,
                      'The manually deployed component should be in the AssemblerRequest components when it is not marked as removed');
    }

    static testMethod void deletedBuildComponentsExistInDestructiveChanges() {
        setup();

        Component__c component = TestingUtils.createComponent('Lead', 'Object', instance.Id);
        Component__c deletedComponent = TestingUtils.createComponent('DeleteMe', 'Object', instance.Id);
        
        Backlog_Component__c documentedComponent =
             TestingUtils.buildDocumentedComponent(backlog.Id, component, instance.Id);
        Backlog_Component__c documentedDeletedComponent =
             TestingUtils.buildDocumentedComponent(backlog.Id, deletedComponent, instance.Id);

        insert new List<Backlog_Component__c> { documentedComponent, documentedDeletedComponent };

        Build_Component__c buildComponent = TestingUtils.buildDocumentedBuildComponent(component, build.Id, instance.Id);
        buildComponent.Backlog_Component__c = documentedComponent.Id;

        Build_Component__c deletedBuildComponent = TestingUtils.buildDocumentedBuildComponent(deletedComponent, build.Id, instance.Id);
        deletedBuildComponent.Is_Deletion__c = true;
        deletedBuildComponent.Backlog_Component__c = documentedDeletedComponent.Id;

        insert new List<Build_Component__c> { buildComponent, deletedBuildComponent };

        Test.startTest();
            AssemblerRequest request = new AssemblerRequest(build, authUser, false);
        Test.stopTest();

        //the list will contain an extra header component
        System.assertEquals(2, request.components.size(), 'The components list should only contain non deleted components');
        System.assertEquals(AssemblerRequest.COMPONENT_HEADER_NAME, request.components[0][0], 'The components list should contain a header row');
        System.assertEquals(component.Name, request.components[1][0], 'The components list should only contain non deleted components');
        System.assertEquals(2, request.destructiveChangesPre.size(), 'The destructive changes pre list should only contain deleted components');
        System.assertEquals(AssemblerRequest.COMPONENT_HEADER_NAME, request.destructiveChangesPre[0][0], 'The destructive changes pre list should contain a header row');
        System.assertEquals(deletedComponent.Name, request.destructiveChangesPre[1][0], 'The destructive changes pre list should only contain deleted components');
    }
}