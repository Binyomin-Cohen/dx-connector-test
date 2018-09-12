@isTest
private class TestAssemblerServices {

    static Release__c release;
    static Instances__c instance;
    static Instances__c almInstance;
    static Backlog__c backlog;
    static Component__c parentComponent;
    static Component__c component;
    static Backlog_Component__c backlogComponent;
    static List<List<String>> buildPackageComponents = MockWebAssemblerAPI.BUILD_PACKAGE_COMPONENTS;

    static void setup() {
        release = new Release__c(Name='Summer 14');
        insert release;

        instance = new Instances__c(Name='dev');
        insert instance;

        almInstance = new Instances__c(Name='ALM Instance', Is_ALM_Instance__c=true);
        insert almInstance;

        backlog = new Backlog__c(Release__c=release.Id, Status__c='Complete');
        insert backlog;

        FieldModifiedData envData1 = new FieldModifiedData( instance.Name,  Datetime.now().addDays(-1), null, null, null);

        parentComponent = new Component__c(Name='Test parent', Type__c='Object');
        insert parentComponent;
        component = new Component__c(Name='Test field', Type__c='Field', Parent_Component__c = parentComponent.Id);
        component.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData1 } );
        insert component;

        backlogComponent = new Backlog_Component__c(Backlog__c = backlog.Id,
             Component__c = component.Id, Source_Instance__c = instance.Id, Notes__c = 'a note');
        insert backlogComponent;
    }

    private static AssemblerServices.ParsedPackageModel createParsedPackageModel(Boolean isSuccess, String failureReason) {
        return new AssemblerServices.ParsedPackageModel(isSuccess, failureReason, buildPackageComponents, new List<List<String>>());
    }

    private static List<Component__c> createPackageTestComponents() {
        Component__c parentComponent = new Component__c(Name='ParentComponent', Type__c='Object');
        insert parentComponent;
        List<Component__c> components = new List<Component__c> {
            new Component__c(Name=buildPackageComponents[0][0], Type__c=buildPackageComponents[0][1], Is_Test_Class__c=false),
            new Component__c(Name=buildPackageComponents[1][0], Type__c=buildPackageComponents[1][1], Is_Test_Class__c=false),
            new Component__c(Name=buildPackageComponents[2][0], Type__c=buildPackageComponents[2][1], Is_Test_Class__c=false),
            new Component__c(Name=buildPackageComponents[3][0], Type__c=buildPackageComponents[3][1], Is_Test_Class__c=true),
            new Component__c(Name=buildPackageComponents[4][0], Type__c=buildPackageComponents[4][1], Parent_Component__c=parentComponent.Id)
        };
        insert components;
        Set<Id> componentIds = Pluck.ids(components);
        components = [ SELECT Id, Name, Type__c, Parent_Component__c, Parent_Component__r.Name FROM Component__c WHERE Id IN :componentIds ];
        return components;
    }

    static testMethod void getManifest() {

        setup();

        Test.startTest();
            List<AssemblerManifestRecord> records = AssemblerServices.getManifest(release.Id);
        Test.stopTest();

        System.assertEquals(1, records.size(), 'Components from the selected release should be in the manifest');
        System.assertEquals(backlogComponent.Id, records[0].getBuildComponent().Backlog_Component__c, 'The Backog Component Id should be set');
        System.assertEquals(backlog.Status__c, records[0].backlogStatus, 'The Backog status should be set');
        System.assertEquals(instance.Name, records[0].instance, 'The instance should be set');
        System.assertEquals(backlogComponent.Notes__c, records[0].notes, 'The instance should be set');
        System.assertEquals(component.Name, records[0].getName(), 'The instance should be set');
        System.assertEquals(component.Type__c, records[0].getType(), 'The instance should be set');
        System.assertEquals(parentComponent.Name, records[0].getParent(), 'The instance should be set');
    }

    static testMethod void getManifest_excludesProfiles() {

        setup();

        Component__c profile1 = TestingUtils.buildComponent('Profile 1', 'Profile', instance.Id);
        Component__c profile2 = TestingUtils.buildComponent('Profile 2', 'Profile', instance.Id);
        insert new List<Component__c> { profile1, profile2 };

        Backlog_Component__c profileWithIncludeDocumentedPermissions = TestingUtils.buildDocumentedProfile(backlog.Id, profile1, instance.Id);
        Backlog_Component__c profileWithoutIncludeDocumentedPermissions = TestingUtils.buildDocumentedProfile(backlog.Id, profile2, instance.Id);
        profileWithoutIncludeDocumentedPermissions.Profile_Permission__c = false;

        insert new List<Backlog_Component__c> { profileWithIncludeDocumentedPermissions, profileWithoutIncludeDocumentedPermissions };

        Test.startTest();
            List<AssemblerManifestRecord> manifest = AssemblerServices.getManifest(release.Id);
        Test.stopTest();

        System.assertEquals(1, manifest.size(), 'Only non profile components should be returned');
        System.assertEquals(backlogComponent.Id, manifest[0].getBuildComponent().Backlog_Component__c, 'Only non profile components should be returned');
    }

    static testMethod void getManifest_withMultipleReleases() {

        setup();

        Backlog_Component__c profilePermission = new Backlog_Component__c(Backlog__c = backlog.Id,
            Component__c = component.Id, Source_Instance__c = instance.Id, Profile_Permission__c = true );

        Release__c otherRelease = new Release__c(Name='Summer 15');
        insert otherRelease;

        Backlog__c backlog2 = new Backlog__c(Release__c=otherRelease.Id, Status__c='Complete');
        insert backlog2;

        FieldModifiedData envData1 = new FieldModifiedData( instance.Name,  Datetime.now().addDays(-1), null, null, null);

        Component__c component2 = new Component__c(Name='Test field', Type__c='Field');
        component2.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData1 } );
        insert component2;

        Backlog_Component__c backlogComponent2 = new Backlog_Component__c(Backlog__c = backlog2.Id,
             Component__c = component.Id, Source_Instance__c = instance.Id );
        insert new List<Backlog_Component__c> { profilePermission, backlogComponent2 };

        Test.startTest();
            List<AssemblerManifestRecord> records = AssemblerServices.getManifest(release.Id);
        Test.stopTest();

        System.assertEquals(1, records.size(), 'Only components from the selected release which are not profile permissions should be in the manifest');
        System.assertEquals(backlogComponent.Id, records[0].getBuildComponent().Backlog_Component__c, 'Only components from the selected release should be in the manifest');
    }

    static testMethod void getManifest_FilterInstances() {

        setup();

        Test.startTest();

            List<String> selectedInstances = new List<String>();
            List<String> emptyList = new List<String>();
            List<AssemblerManifestRecord> records = AssemblerServices.getManifest(release.Id, selectedInstances, emptyList, emptyList, emptyList);
        Test.stopTest();

        System.assertEquals(1, records.size(), 'All components should be returned when there are no filters selected');
        System.assertEquals(backlogComponent.Id, records[0].getBuildComponent().Backlog_Component__c, 'Only components from the selected release should be in the manifest');

        selectedInstances.add( 'bogusId');
        records = AssemblerServices.getManifest(release.Id, selectedInstances, emptyList, emptyList, emptyList);

        System.assertEquals(0, records.size(), 'No components should be returned when there are no records with matching instances');

        selectedInstances.add( instance.Id);
        records = AssemblerServices.getManifest(release.Id, selectedInstances, emptyList, emptyList, emptyList);

        System.assertEquals(1, records.size(), 'All components should be returned when the records match the filters');
    }

    static testMethod void getManifest_FilterComponentTypes() {

        setup();

        Test.startTest();

            List<String> selectedComponentTypes = new List<String>();
            List<String> emptyList = new List<String>();
            List<AssemblerManifestRecord> records = AssemblerServices.getManifest(release.Id, emptyList, selectedComponentTypes, emptyList, emptyList);
        Test.stopTest();

        System.assertEquals(1, records.size(), 'All components should be returned when there are no filters selected');
        System.assertEquals(backlogComponent.Id, records[0].getBuildComponent().Backlog_Component__c, 'Only components from the selected release should be in the manifest');

        selectedComponentTypes.add( 'bogusType');
        records = AssemblerServices.getManifest(release.Id, emptyList, selectedComponentTypes, emptyList, emptyList);

        System.assertEquals(0, records.size(), 'No components should be returned when there are no records with matching component types');

        selectedComponentTypes.add( component.Type__c );
        records = AssemblerServices.getManifest(release.Id, emptyList, selectedComponentTypes, emptyList, emptyList);

        System.assertEquals(1, records.size(), 'All components should be returned when the records match the filters');
    }

    static testMethod void getManifest_FilterBacklogStatus() {

        setup();

        Test.startTest();

            List<String> selectedStatuses = new List<String>();
            List<String> emptyList = new List<String>();
            List<AssemblerManifestRecord> records = AssemblerServices.getManifest(release.Id, emptyList, emptyList, selectedStatuses, emptyList);
        Test.stopTest();

        System.assertEquals(1, records.size(), 'All components should be returned when there are no filters selected');
        System.assertEquals(backlogComponent.Id, records[0].getBuildComponent().Backlog_Component__c, 'Only components from the selected release should be in the manifest');

        selectedStatuses.add( 'bogusStatus');
        records = AssemblerServices.getManifest(release.Id, emptyList, emptyList, selectedStatuses, emptyList);

        System.assertEquals(0, records.size(), 'No components should be returned when there are no records with matching backlog statuses');

        selectedStatuses.add( backlog.Status__c );
        records = AssemblerServices.getManifest(release.Id, emptyList, emptyList, selectedStatuses, emptyList);

        System.assertEquals(1, records.size(), 'All components should be returned when the records match the filters');
    }

    static testMethod void getManifest_FilterByBacklog() {

        setup();

        Test.startTest();

            List<String> selectedBacklogItems = new List<String>();
            List<String> emptyList = new List<String>();
            List<AssemblerManifestRecord> records = AssemblerServices.getManifest(release.Id, emptyList, emptyList, emptyList, selectedBacklogItems);
        Test.stopTest();

        System.assertEquals(1, records.size(), 'All components should be returned when there are no filters selected');
        System.assertEquals(backlogComponent.Id, records[0].getBuildComponent().Backlog_Component__c, 'Only components from the selected release should be in the manifest');

        selectedBacklogItems.add( 'bogusBacklog');
        records = AssemblerServices.getManifest(release.Id, emptyList, emptyList, emptyList, selectedBacklogItems);

        System.assertEquals(0, records.size(), 'No components should be returned when there are no records with matching backlog items');

        selectedBacklogItems.add( backlog.Id );
        records = AssemblerServices.getManifest(release.Id, emptyList, emptyList, emptyList, selectedBacklogItems);

        System.assertEquals(1, records.size(), 'All components should be returned when the records match the filters');
    }

    static testMethod void getUndocumentedProfiles_noDocumentedProfiles() {
         setup();

        Component__c profile1 = new Component__c(Name='a profile 1', Type__c='Profile');
        Component__c profile2 = new Component__c(Name='b profile 2', Type__c='Profile');
        insert new List<Component__c>{profile1, profile2};

        Test.startTest();

            List<ProfileManifestRecord> undocumented = AssemblerServices.getUndocumentedProfiles(release.Id);

        Test.stopTest();

        System.assertEquals(2, undocumented.size(), 'All undocumented profiles should be returned');
        System.assertEquals(profile1.Name, undocumented[0].profileName, 'Undocumented profiles should be returned in alphabetical order');
        System.assertEquals(true, undocumented[0].getIsUndocumented(), 'Undocumented profiles should be marked as undocumented');
        System.assertEquals(profile2.Name, undocumented[1].profileName, 'Undocumented profiles should be returned in alphabetical order');
        System.assertEquals(true, undocumented[1].getIsUndocumented(), 'Undocumented profiles should be marked as undocumented');
    }

    static testMethod void getUndocumentedProfiles_someDocumentedProfiles() {
         setup();

        Component__c profile1 = new Component__c(Name='a profile 1', Type__c='Profile');
        Component__c profile2 = new Component__c(Name='b profile 1', Type__c='Profile');
        Component__c profile3 = new Component__c(Name='c profile 2', Type__c='Profile');
        insert new List<Component__c>{profile1, profile2, profile3};

        Backlog_Component__c documentedProfile = TestingUtils.createDocumentedProfile(backlog.Id, profile2, instance.Id);

        Test.startTest();

            List<ProfileManifestRecord> undocumented = AssemblerServices.getUndocumentedProfiles(release.Id);

        Test.stopTest();

        System.assertEquals(2, undocumented.size(), 'Only undocumented profiles should be returned');
        System.assertEquals(profile1.Name, undocumented[0].profileName, 'Undocumented profiles should be returned in alphabetical order');
        System.assertEquals(profile3.Name, undocumented[1].profileName, 'Undocumented profiles should be returned in alphabetical order');
    }

    static testMethod void getDocumentedProfiles() {
        setup();

        Component__c profile1 = new Component__c(Name='a profile 1', Type__c='Profile');
        Component__c profile2 = new Component__c(Name='c profile 2', Type__c='Profile');
        Component__c profile3 = new Component__c(Name='d profile 3', Type__c='Profile');
        insert new List<Component__c>{profile1, profile2, profile3};

        Backlog_Component__c documentedProfile = TestingUtils.createDocumentedProfile(backlog.Id, profile1, instance.Id);
        Backlog_Component__c documentedProfile2 = TestingUtils.createDocumentedProfile(backlog.Id, profile3, instance.Id);
        Backlog_Component__c documentedProfile3 = TestingUtils.createDocumentedProfile(backlog.Id, profile3, instance.Id);

        Test.startTest();

            List<ProfileManifestRecord> documented = AssemblerServices.getDocumentedProfiles(release.Id);

        Test.stopTest();

        System.assertEquals(2, documented.size(), 'Only documented profiles should be returned');
        System.assertEquals(profile1.Name, documented[0].profileName, 'documented profiles should be returned in alphabetical order');
        System.assertEquals(profile3.Name, documented[1].profileName, 'documented profiles should be returned in alphabetical order');
        System.assert(String.isNotEmpty(documented[0].selectedPermissions), 'permissions should be documented when include entire profile is false');
        System.assert(String.isNotEmpty(documented[1].selectedPermissions), 'permissions should be documented when include entire profile is false');
        System.assertEquals(false, documented[0].includeEntireProfile,
            'includeEntireProfile should be false when no documented profiles have Include_Entire_Profile__c set to true');
        System.assertEquals(false, documented[1].includeEntireProfile,
            'includeEntireProfile should be false when no documented profiles have Include_Entire_Profile__c set to true');
    }

    static testMethod void getDocumentedProfiles_includeEntireProfile() {
        setup();

        Component__c profile1 = new Component__c(Name='a profile 1', Type__c='Profile');
        Component__c profile2 = new Component__c(Name='c profile 2', Type__c='Profile');
        Component__c profile3 = new Component__c(Name='d profile 3', Type__c='Profile');
        insert new List<Component__c>{profile1, profile2, profile3};

        Backlog_Component__c documentedProfile = TestingUtils.createDocumentedProfile(backlog.Id, profile1, instance.Id);
        Backlog_Component__c documentedProfile2 = TestingUtils.createDocumentedProfile(backlog.Id, profile3, instance.Id);
        Backlog_Component__c documentedProfile3 = TestingUtils.buildDocumentedProfile(backlog.Id, profile3, instance.Id);
        documentedProfile3.Include_Entire_Profile__c = true;
        insert documentedProfile3;

        Test.startTest();

            List<ProfileManifestRecord> documented = AssemblerServices.getDocumentedProfiles(release.Id);

        Test.stopTest();

        System.assertEquals(2, documented.size(), 'Only documented profiles should be returned');
        System.assertEquals(profile1.Name, documented[0].profileName, 'documented profiles should be returned in alphabetical order');
        System.assertEquals(profile3.Name, documented[1].profileName, 'documented profiles should be returned in alphabetical order');
        System.assert(String.isNotEmpty(documented[0].selectedPermissions), 'permissions should not be documented when include entire profile is false');
        System.assert(String.isEmpty(documented[1].selectedPermissions), 'permissions should not be documented when include entire profile is false');
        System.assertEquals(false, documented[0].includeEntireProfile,
            'includeEntireProfile should be false when no documented profiles have Include_Entire_Profile__c set to true');
        System.assertEquals(true, documented[1].includeEntireProfile,
            'includeEntireProfile should be true when any documented profile has Include_Entire_Profile__c set to true');
    }

    static testMethod void getDocumentedProfiles_mergePermissions() {
        setup();
        Component__c profile = TestingUtils.createComponent('Admin', 'Profile', instance.Id);
        Component__c profile2 = TestingUtils.createComponent('Admin2', 'Profile', instance.Id);
        Backlog_Component__c profileComponent1 = TestingUtils.buildDocumentedProfile(backlog.Id, profile, instance.Id);
        Backlog_Component__c profileComponent2 = TestingUtils.buildDocumentedProfile(backlog.Id, profile, instance.Id);
        Backlog_Component__c otherProfileComponent = TestingUtils.buildDocumentedProfile(backlog.Id, profile2, instance.Id);

        ProfilePermissions perms1 = new ProfilePermissions();
        ProfilePermissions.Section section = new ProfilePermissions.Section();
        section.apiName = 's1';
        section.permissions = new List<String> {'permission1'};

        perms1.sections.add(section);

        profileComponent1.Profile_Data_1__c = JSON.serialize(perms1);

        ProfilePermissions perms2 = new ProfilePermissions();
        ProfilePermissions.Section section2 = new ProfilePermissions.Section();
        section2.apiName = 's2';
        section2.permissions = new List<String> {'permission2'};

        perms2.sections.add(section2);

        profileComponent2.Profile_Data_1__c = JSON.serialize(perms2);

        insert new List<Backlog_Component__c> {profileComponent1, profileComponent2, otherProfileComponent};

        Map<String, ProfilePermissions.Section> sectionMap = new Map<String, ProfilePermissions.Section>{
            section.apiName => section,
            section2.apiName => section2
        };

        Test.startTest();

            List<ProfileManifestRecord> documented = AssemblerServices.getDocumentedProfiles(release.Id);

        Test.stopTest();

        System.assertEquals(2, documented.size(), 'Only unique documented profiles should be returned');
        System.assertEquals(profile.Name, documented[0].profileName, 'Only unique documented profiles should be returned');
        System.assertEquals(profile2.Name, documented[1].profileName, 'Only unique documented profiles should be returned');

        ProfilePermissions mergedProfile = ProfilePermissions.valueOf(documented[0].selectedPermissions);

        System.assertEquals(2, mergedProfile.sections.size(), 'The sections from all profiles should be merged');

        ProfilePermissions.Section expectedMergedSection1 = sectionMap.get(mergedProfile.sections[0].apiName);
        System.assertNotEquals(null, expectedMergedSection1, 'The sections from all profiles should be merged');

        System.assertEquals(1, mergedProfile.sections[0].permissions.size(), 'The sections from all profiles should be merged');
        System.assertEquals(expectedMergedSection1.permissions[0], mergedProfile.sections[0].permissions[0], 'The sections from all profiles should be merged');

        ProfilePermissions.Section expectedMergedSection2 = sectionMap.get(mergedProfile.sections[1].apiName);

        System.assertNotEquals(null, expectedMergedSection2, 'The sections from all profiles should be merged');
        System.assertEquals(1, mergedProfile.sections[1].permissions.size(), 'The sections from all profiles should be merged');
        System.assertEquals(expectedMergedSection2.permissions[0], mergedProfile.sections[1].permissions[0], 'The sections from all profiles should be merged');
    }


    static Id getManifestByBuildId_profileNameSetup(Boolean deleteBacklogComponent) {
        String testProfileName = 'testProfile';

        setup();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Component__c profileComponent = TestingUtils.createComponent(testProfileName, 'Profile', instance.Id);

        Backlog_Component__c profileBacklogComponent = TestingUtils.createDocumentedProfile(backlog.Id, profileComponent, instance.Id);

        Build_Component__c profileBuildComponent = TestingUtils.buildDocumentedBuildComponent(profileComponent, build.Id, instance.Name);
        profileBuildComponent.Is_Profile__c = true;
        profileBuildComponent.Component_Name__c = null;
        insert profileBuildComponent;

        if (deleteBacklogComponent) {
            delete profileBacklogComponent;
        }

        return build.Id;
    }

    static testMethod void getManifestByBuildId_profileName_blankComponentName() {
        String testProfileName = 'testProfile';
        Id buildId = getManifestByBuildId_profileNameSetup(false);

        Test.startTest();
            List<AssemblerManifestRecord> assemblerManifestRecords = AssemblerServices.getManifestByBuildId(buildId);
        Test.stopTest();

        System.assertEquals(1, assemblerManifestRecords.size(), 'There should be one assembler manifest record.');
        System.assertEquals(testProfileName, ((ProfileManifestRecord)(assemblerManifestRecords[0])).profileName, 'The profile names should match.');
    }

    static testMethod void getManifestByBuildId_profileName_blankComponentName_backlogComponentDeleted() {
        String testProfileName = 'testProfile';
        Id buildId = getManifestByBuildId_profileNameSetup(true);

        Test.startTest();
            List<AssemblerManifestRecord> assemblerManifestRecords = AssemblerServices.getManifestByBuildId(buildId);
        Test.stopTest();

        System.assertEquals(1, assemblerManifestRecords.size(), 'There should be one assembler manifest record.');
        System.assertEquals(testProfileName, ((ProfileManifestRecord)(assemblerManifestRecords[0])).profileName, 'The profile names should match.');
    }

    static testMethod void getManifestByBuildId_includesAllProfileComponents() {
        String testProfileName = 'testProfile';
        Id buildId = getManifestByBuildId_profileNameSetup(false);

        Component__c profile = TestingUtils.createComponent('Admin Profile', 'Profile', instance.Id);

        Backlog_Component__c profileWithoutIncludeDocumentedPermissions = TestingUtils.buildDocumentedProfile(backlog.Id, profile, instance.Id);
        profileWithoutIncludeDocumentedPermissions.Profile_Permission__c = false;
        insert profileWithoutIncludeDocumentedPermissions;

        Build_Component__c profileBuildComponent = TestingUtils.buildDocumentedBuildComponent(profile, buildId, instance.Name);
        profileBuildComponent.Backlog_Component__c = profileWithoutIncludeDocumentedPermissions.Id;
        insert profileBuildComponent;

        Test.startTest();
            List<AssemblerManifestRecord> assemblerManifestRecords = AssemblerServices.getManifestByBuildId(buildId);
        Test.stopTest();

        System.assertEquals(2, assemblerManifestRecords.size(), 'All profile components hsould be returned as assembler manifest records.');

        for (AssemblerManifestRecord record : assemblerManifestRecords) {
            System.assert(record instanceof ProfileManifestRecord, 'Profiles should be returned as profile manifest records');
        }
    }

    static testMethod void getBuildStatus() {
        setup();
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        build.UUID__c = MockWebAssemblerAPI.JOB_ID;

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_GET_ACTION));
            AssemblerServices.BuildStatus buildStatus  = AssemblerServices.getBuildStatus(build);
        Test.stopTest();

        System.assertEquals(MockWebAssemblerAPI.JOB_ID, buildStatus.jobId, 'The build should set the job Id from the statusresponse');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, buildStatus.status, 'The build should be updated with the status from the assemble response');
        System.assertEquals(null, buildStatus.failureReason, 'The failure reason should be set with the status from the assemble response');
    }

    static testMethod void getBuildStatus_throwsExceptionOnFailure() {
        setup();
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        build.UUID__c = MockWebAssemblerAPI.JOB_ID;

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_GET_FAILED_ACTION));
            AssemblerServices.BuildStatus buildStatus  = AssemblerServices.getBuildStatus(build);
        Test.stopTest();

        System.assertEquals(MockWebAssemblerAPI.JOB_ID, buildStatus.jobId, 'The build should set the job Id from the statusresponse');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, buildStatus.status, 'The build should be updated with the status from the assemble response');
        System.assertEquals(MockWebAssemblerAPI.FAILURE_REASON, buildStatus.failureReason, 'The failure reason should be set with the status from the assemble response');
    }

    static testMethod void makeAssembleRequest() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id);
        insert build;

        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        TestingUtils.createOAuthSettings();

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));
            AssemblerServices.BuildResult buildResult  = AssemblerServices.makeAssembleRequest(build, instance.Id, instance.Id, false);
        Test.stopTest();

        System.assertEquals(MockWebAssemblerAPI.JOB_ID, buildResult.jobId, 'The build should be updated with the job Id from the assemble response');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, buildResult.result, 'The build should be updated with the status from the assemble response');
    }

    static testMethod void makeAssembleRequest_failure() {
        setup();
        Build__c build = new Build__c(Release__c=release.Id);
        insert build;

        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_FAILURE_ACTION));
            try {
                AssemblerServices.BuildResult buildResult  = AssemblerServices.makeAssembleRequest(build, instance.Id, instance.Id, false);
                System.assert(false, 'An exception should be thrown when there is an error response');
            } catch(Exception ex) {
                System.assert(ex instanceof AssemblerException, 'An assembler exception should be thrown when an invalid response comes back');
            }

        Test.stopTest();

        List<ALM_Error__c> errors = [SELECT Id FROM ALM_Error__c WHERE Build__c = :build.Id];
        System.assertEquals(1, errors.size(), 'A build error should be created when a failure is returned');
    }

    static testMethod void makeAssembleRequest_refreshTokenInvalid() {
        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST));

        setup();
        TestingUtils.createOAuthSettings();
        Build__c build = new Build__c(Release__c=release.Id);
        insert build;

        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        Auth_User__c almAuth = TestingUtils.buildAuthUser(UserInfo.getUserId(), almInstance.Id, true);
        almAuth.Is_Refresh_Token_Valid__c = false;
        insert almAuth;

        Test.startTest();
            try {
                AssemblerServices.BuildResult buildResult = AssemblerServices.makeAssembleRequest(build, instance.Id, instance.Id, false);
                System.assert(false, 'An exception should be thrown when instance authorization is invalid.');
            } catch (Exception ex) {
                System.assert(ex instanceof AssemblerException, 'An assembler exception should be thrown when instance authorization is invalid.');
                System.assertEquals(AssemblerServices.ERROR_INSTANCE_AUTH_INVALID, ex.getMessage(), 'The exception message should be correct.');
            }
        Test.stopTest();

        List<ALM_Error__c> errors = [SELECT Error_Cause__c FROM ALM_Error__c WHERE Build__c = :build.Id];

        System.assertEquals(1, errors.size(), 'A build error should be created when a failure is returned, despite a successful HTTP response.');
        System.assertEquals(AssemblerServices.ERROR_INSTANCE_AUTH_INVALID, errors[0].Error_Cause__c, 'The build error cause should be correct.');
    }

    static testMethod void makeAssembleRequest_authUserIsForTools() {
        setup();

        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));

        TestingUtils.createOAuthSettings();
        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id, true);
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        Build__c testBuild = new Build__c(Release__c = release.Id);
        insert testBuild;

        Test.startTest();

            try {
                AssemblerServices.makeAssembleRequest(testBuild, instance.Id, instance.Id, false);

                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assert(e.getMessage().contains(AssemblerServices.ERROR_MISSING_AUTH_USERS), 'The proper exception should be thrown.');
            }

        Test.stopTest();
    }

    static testMethod void makeGitAssemblerRequest() {
        setup();

        TestingUtils.createOAuthSettings();
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        Auth_User__c targetAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        TestingUtils.setupSSH();

        VC_Repository__c repo = TestingUtils.createVcRepository('git-repo', 'http://www.git.com', 'GitHub', 'GitTest');

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        build.Source_Repository_Location__c = 'master';
        build.Source_Repository__c = repo.Id;

        Test.startTest();
            MockWebAssemblerAPI mockAPI = new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION);
            Test.setMock(HttpCalloutMock.class, mockAPI);
            AssemblerServices.BuildResult buildResult  = AssemblerServices.makeGitAssembleRequest(build, instance.Id, false);
        Test.stopTest();

        System.assertEquals(MockWebAssemblerAPI.JOB_ID, buildResult.jobId, 'The build should be updated with the job Id from the assemble response');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, buildResult.result, 'The build should be updated with the status from the assemble response');

        AssemblerGitSourceRequest request = 
            (AssemblerGitSourceRequest)JSON.deserialize(mockAPI.requestBody, AssemblerGitSourceRequest.class);
        
        System.assertNotEquals(null, request.versionControlSource, 'The version control source should be set on the request');
        System.assertEquals(build.Source_Repository__c, request.versionControlSource.repoId, 'The repo from the build should be set on the request');
        
        //The first row is a header row which will always be included
        System.assertEquals(1, request.components.size(), 
            'The manifest should be empty when no build components are created');
    }
 
    static testMethod void makeJenkinsAssemblerRequest() {
        setup();

        TestingUtils.createOAuthSettings();
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        Auth_User__c targetAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);

        TestingUtils.setupSSH();

        VC_Repository__c repo = TestingUtils.createVcRepository('git-repo', 'http://www.git.com', 'GitHub', 'GitTest');

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        build.Source_Repository_Location__c = 'master';
        build.Source_Repository__c = repo.Id;

        Test.startTest();
            MockWebAssemblerAPI mockAPI = new MockWebAssemblerAPI(MockWebAssemblerAPI.VC_ASSEMBLE_ACTION);
            Test.setMock(HttpCalloutMock.class, mockAPI);
            AssemblerServices.BuildResult buildResult  = AssemblerServices.makeJenkinsAssembleRequest(build, instance.Id, false);
        Test.stopTest();

        System.assertEquals(MockWebAssemblerAPI.JOB_ID, buildResult.jobId, 'The build should be updated with the job Id from the assemble response');
        System.assertEquals(MockWebAssemblerAPI.STATUS_RESULT, buildResult.result, 'The build should be updated with the status from the assemble response');
        
        AssemblerJenkinsBuildRequest request = 
            (AssemblerJenkinsBuildRequest)JSON.deserialize(mockAPI.requestBody, AssemblerJenkinsBuildRequest.class);
        
        System.assertNotEquals(null, request.versionControlSource, 'The version control source should be set on the request');
        System.assertEquals(build.Source_Repository__c, request.versionControlSource.repoId, 'The repo from the build should be set on the request');
        
        System.assertEquals(2, request.components.size(), 
            'Components documented against the release should be returned in the manifest');
        //skip index 0 as this is a header row
        System.assertEquals(component.Name, request.components[1][0],
            'Components documented against the release should be returned in the manifest');
    }

    static testMethod void makeGitAssembleRequest_failure_noRepository() {
        setup();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        TestingUtils.createOAuthSettings();
        TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id);
        TestingUtils.createAuthUser(UserInfo.getUserId(), almInstance.Id, true);

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.ASSEMBLE_ACTION));
            try {
                AssemblerServices.BuildResult buildResult  = AssemblerServices.makeGitAssembleRequest(build, instance.Id, false);
                System.assert(false, 'An exception should be thrown when there is no repository');
            } catch(Exception ex) {
                System.assert(ex instanceof AssemblerException, 'An assembler exception should be thrown when there is no repository specified');
                System.assert(ex.getMessage().contains(AssemblerServices.ERROR_MISSING_REPO), 'The repo missing exception should be thrown.');
            }

        Test.stopTest();
    }


    static testMethod void diffBuildAndRelease_noDiffs() {
        setup();
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        // Add documented component
        Build_Component__c buildComp = new Build_Component__c(
            Backlog_Component__c = backlogComponent.Id,
            Build__c = build.Id
        );
        insert buildComp;

        Test.startTest();
            List<AssemblerServices.ManifestDiff> diffs = AssemblerServices.diffBuildAndRelease(build.Id, release.Id);
        Test.stopTest();

        System.assertEquals(0, diffs.size(), 'There should be no differences between the build and release');
    }

    static testMethod void diffBuildAndRelease_buildMissingDocComponent() {
        setup();

        // Create a build with no documented components
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Test.startTest();
            List<AssemblerServices.ManifestDiff> diffs = AssemblerServices.diffBuildAndRelease(build.Id, release.Id);
        Test.stopTest();

        System.assertEquals(1, diffs.size(), 'There should be a single difference between the build and release');
        System.assertEquals(AssemblerServices.DiffType.ADDED, diffs[0].type, 'The release difference should be "added" type');
        System.assertEquals(
            backlogComponent.Id,
            diffs[0].manifestRecord.getBuildComponent().Backlog_Component__c,
            'The backlog component on the diff record should be the one missing from the build.'
        );
    }

    static testMethod void diffBuildAndRelease_releaseMissingDocComponent() {
        setup();

        // Create a build with no documented components
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        // Add documented component
        Build_Component__c buildComp = TestingUtils.createDocumentedBuildComponent(backlogComponent, build.Id, instance.Name);

        // Remove documented component from release
        delete backlogComponent;

        Test.startTest();
            List<AssemblerServices.ManifestDiff> diffs = AssemblerServices.diffBuildAndRelease(build.Id, release.Id);
        Test.stopTest();

        // Need to remove backlog component ref so that the key is correct
        buildComp.Backlog_Component__c = null;

        System.assertEquals(1, diffs.size(), 'There should be a single difference between the build and release');
        System.assertEquals(AssemblerServices.DiffType.REMOVED, diffs[0].type, 'The release difference should be "removed" type');
        System.assertEquals(
            (new AssemblerManifestRecord(buildComp)).getKey(),
            diffs[0].manifestRecord.getKey(),
            'The backlog component on the diff record should be the one missing from the release.'
        );
    }

    /**
    * Tests that a Build with a documented build component that is removed, will be marked as a removed component if the documented
    * backlog component is deleted
    */
    static testMethod void diffBuildAndRelease_releaseMissingDocComponent_removedOnBuild() {
        setup();

        // Create a build with no documented components
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        // Add documented component
        Build_Component__c buildComp = TestingUtils.createDocumentedBuildComponent(backlogComponent, build.Id, instance.Name);
        buildComp.Type__c = AssemblerManifestRecord.REMOVED;
        update buildComp;

        // Remove documented component from release
        delete backlogComponent;

        Test.startTest();
            List<AssemblerServices.ManifestDiff> diffs = AssemblerServices.diffBuildAndRelease(build.Id, release.Id);
        Test.stopTest();

        // Need to remove backlog component ref so that the key is correct
        buildComp.Backlog_Component__c = null;

        System.assertEquals(1, diffs.size(), 'There should be a single difference between the build and release');
        System.assertEquals(AssemblerServices.DiffType.REMOVED, diffs[0].type, 'The release difference should be "removed" type');
        System.assertEquals(
            (new AssemblerManifestRecord(buildComp)).getKey(),
            diffs[0].manifestRecord.getKey(),
            'The backlog component on the diff record should be the one missing from the release.'
        );
    }

    static testMethod void diffBuildAndRelease_releaseReplacesBuildComponent() {
        setup();

        // Create a build with no documented components
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        // Add undocumented component
        Build_Component__c buildComp = TestingUtils.createUndocumentedBuildComponent(component, build.Id, instance.Name);

        Test.startTest();
            List<AssemblerServices.ManifestDiff> diffs = AssemblerServices.diffBuildAndRelease(build.Id, release.Id);
        Test.stopTest();

        System.assertEquals(1, diffs.size(), 'There should be a single difference between the build and release');
        System.assertEquals(AssemblerServices.DiffType.ADDED, diffs[0].type, 'The release difference should be "added" type');
        System.assertEquals(
            backlogComponent.Id,
            diffs[0].manifestRecord.getBuildComponent().Backlog_Component__c,
            'The backlog component on the diff record should be the one missing from the build.'
        );

    }

    static testMethod void diffBuildAndRelease_newProfileOnRelease() {
        setup();

        // Create a build with no documented components
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        // Add documented component
        Build_Component__c buildComp = new Build_Component__c(
            Backlog_Component__c = backlogComponent.Id,
            Build__c = build.Id
        );
        insert buildComp;

        // Add documented profile to the release
        Component__c profile = new Component__c(Name='test profile', Type__c='Profile');
        insert profile;
        Backlog_Component__c documentedProfile = TestingUtils.createDocumentedProfile(backlog.Id, profile, instance.Id);

        Test.startTest();
            List<AssemblerServices.ManifestDiff> diffs = AssemblerServices.diffBuildAndRelease(build.Id, release.Id);
        Test.stopTest();

        System.assertEquals(1, diffs.size(), 'There should be a single difference between the build and release');
        System.assertEquals(AssemblerServices.DiffType.ADDED, diffs[0].type, 'The release difference should be "added" type');
        System.assertEquals(
            profile.Id,
            diffs[0].manifestRecord.getBuildComponent().Component__c,
            'The profile on the diff record should be the one missing from the build.'
        );

    }

    static testMethod void manifestFilterable_findByKey() {
        setup();

        Backlog_Component__c testBacklogComponent = [
            SELECT
                Component__c, Backlog__r.Name, Source_Instance__r.Name, Deleted__c,
                Backlog__r.Status__c, Notes__c, Deploy_Manually__c, Component__r.Parent_Component__r.Name,
                Component__r.Full_Name__c, Component__r.Name, Component__r.Type__c
            FROM Backlog_Component__c
            WHERE Id = :backlogComponent.Id
        ][0];
        AssemblerManifestRecord testAssemblerManifestRecord = new AssemblerManifestRecord(testBacklogComponent);
        List<AssemblerManifestRecord> testAssemblerManifestRecordList = new List<AssemblerManifestRecord>{ testAssemblerManifestRecord };
        AssemblerServices.ManifestFilterable filterable = new AssemblerServices.ManifestFilterable(testAssemblerManifestRecordList);

        Test.startTest();

            AssemblerManifestRecord documentedResult = filterable.findByKey(testAssemblerManifestRecord.getDocumentedKey());
            AssemblerManifestRecord undocumentedResult = filterable.findByKey(testAssemblerManifestRecord.getKey());

        Test.stopTest();

        System.assertNotEquals(null, documentedResult, 'The manifest record should be found by the documented key.');
        System.assertEquals(null, undocumentedResult, 'The manifest record should not be found by the undocumented key.');

        System.assertEquals(testBacklogComponent.Id, documentedResult.getBuildComponent().Backlog_Component__c, 'The backlog component ID should match.');
    }

    private static testMethod void createBuildComponentsFromBuildPackage_withComponents() {
        Build__c packageBuild = new Build__c();
        insert packageBuild;
        AssemblerServices.ParsedPackageModel packageModel = createParsedPackageModel(true, '');
        List<Component__c> components = createPackageTestComponents();

        Test.startTest();
            List<Build_Component__c> buildComponents = AssemblerServices.createBuildComponentsFromBuildPackage(packageBuild.Id, packageModel);
        Test.stopTest();

        System.assertEquals(buildPackageComponents.size(), buildComponents.size(), 
            'The number of build components created should match the number of components in the build package.');

        Map<Id, Component__c> componentsMap = new Map<Id, Component__c>(components);
        for (Build_Component__c buildComponent : buildComponents) {
            if (componentsMap.keySet().contains(buildComponent.Component__c)) {
                Component__c compRecord = componentsMap.get(buildComponent.Component__c);
                System.assertEquals(compRecord.Name, buildComponent.Component_Name__c, 
                    'The component name on the build component record should match.');
                System.assertEquals(compRecord.Type__c, buildComponent.Component_Type__c, 
                    'The component type on the build component record should match.');
                System.assertEquals(compRecord.Parent_Component__r.Name, buildComponent.Parent_Component__c, 
                    'The parent component field on the build component record should match.');
            }
            System.assertEquals((buildComponent.Component_Type__c == AssemblerServices.PROFILE_TYPE),
                 buildComponent.Is_Profile__c, 'The profile property should be set on the sobject');
            System.assertEquals(false, buildComponent.Is_Deletion__c,
                  'components in the package.xml should not be marked as deleted');
        }

        List<Build_Component__c> queriedBuildComponents = [ SELECT Id FROM Build_Component__c WHERE Build__c =: packageBuild.Id ];
        System.assertEquals(buildComponents.size(), queriedBuildComponents.size(), 
            'The number of build components returned from the database should match the count returned from the method.');
    }
    
    private static testMethod void createBuildComponentsFromBuildPackage_withDestructiveChanges() {
        Build__c packageBuild = new Build__c();
        insert packageBuild;
        AssemblerServices.ParsedPackageModel packageModel = new AssemblerServices.ParsedPackageModel(true, '',
             new List<List<String>>(), new List<List<String>> { buildPackageComponents[1] });
        List<Component__c> components = createPackageTestComponents();

        Test.startTest();
            List<Build_Component__c> buildComponents = AssemblerServices.createBuildComponentsFromBuildPackage(packageBuild.Id, packageModel);
        Test.stopTest();

        System.assertEquals(1, buildComponents.size(), 
            'The number of build components created should match the number of components in the package model.');

        Build_Component__c actualBuildComponent = buildComponents[0];
        System.assertEquals(buildPackageComponents[1][0], actualBuildComponent.Component_Name__c, 
                'The component name on the build component record should match.');
        System.assertEquals(buildPackageComponents[1][1], actualBuildComponent.Component_Type__c, 
                'The component type on the build component record should match.');
        System.assertEquals(null, actualBuildComponent.Parent_Component__c, 
                'The parent component field should be blank when the component did not have a parent.');
        
        System.assertEquals(false,
                actualBuildComponent.Is_Profile__c, 'The profile property should be set on the sobject');
        System.assertEquals(true, actualBuildComponent.Is_Deletion__c,
                'Components in the destructive changes list should be marked as deleted');

        List<Build_Component__c> queriedBuildComponents = [ SELECT Id FROM Build_Component__c WHERE Build__c =: packageBuild.Id ];
        System.assertEquals(buildComponents.size(), queriedBuildComponents.size(), 'The build components should be inserted.');
    }

    private static testMethod void createBuildComponentsFromBuildPackage_emptyBuildPackage() {
        Build__c build = new Build__c();
        insert build;
        createPackageTestComponents();
        AssemblerServices.ParsedPackageModel packageModel = new AssemblerServices.ParsedPackageModel(true, '',
            new List<List<String>>(), new List<List<String>>());

        Test.startTest();
            List<Build_Component__c> buildComponents = AssemblerServices.createBuildComponentsFromBuildPackage(build.Id, packageModel);
        Test.stopTest();

        System.assertEquals(0, buildComponents.size(), 
            'There should be no build components created in an empty build package.');
    }

    private static testMethod void createBuildComponentsFromBuildPackage_parseUnsuccessful() {
        Build__c build = new Build__c();
        insert build;
        AssemblerServices.ParsedPackageModel packageModel = new AssemblerServices.ParsedPackageModel(
            false, 'Failed to find components.', new List<List<String>>(), new List<List<String>>());

        Test.startTest();
            List<Build_Component__c> buildComponents = AssemblerServices.createBuildComponentsFromBuildPackage(build.Id, packageModel);
        Test.stopTest();
        
        System.assertEquals(0, buildComponents.size(), 
            'An unsuccessful parsing of the package should return an empty list of build components.');
    }

    private static testMethod void makeParsePackageRequest_withBuildComponents() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(AssemblerServices.PARSE_PACKAGE_PATH));
        List<Component__c> components = createPackageTestComponents();
        TestingUtils.createOAuthSettings();
        Build__c packageBuild = new Build__c( Package_URL__c='space-man/on/roadster' );
        insert packageBuild;

        Test.startTest();
            try {
                AssemblerServices.makeParsePackageRequest(packageBuild);
            } catch (ALMException ae) {
                System.assert(false, 'No exception should have been thrown.');
            }
        Test.stopTest();

        List<Build_Component__c> buildComponents = [ SELECT Id, Name, Build__c, Component__c, Component_Name__c, 
                                                            Component_Type__c, Parent_Component__c
                                                     FROM Build_Component__c 
                                                     WHERE Build__c = :packageBuild.Id ];

        System.assertEquals(buildPackageComponents.size(), buildComponents.size(), 
            'The build component size should match the size of buildPackageComponents.');

        Map<Id, Component__c> componentsMap = new Map<Id, Component__c>(components);
        for (Build_Component__c buildComponent : buildComponents) {
            if (componentsMap.keySet().contains(buildComponent.Component__c)) {
                Component__c compRecord = componentsMap.get(buildComponent.Component__c);
                System.assertEquals(compRecord.Name, buildComponent.Component_Name__c, 
                    'The component name on the build component record should match.');
                System.assertEquals(compRecord.Type__c, buildComponent.Component_Type__c, 
                    'The component type on the build component record should match.');
                System.assertEquals(compRecord.Parent_Component__r.Name, buildComponent.Parent_Component__c, 
                    'The parent component field on the build component record should match.');
                System.assertEquals(false, buildComponent.Is_Deletion__c, 
                    'Components in the package.xml should not be considered deleted.');
            }
        }
    
        List<Build__c> queriedBuild = [ SELECT Id, Name, Is_Manual_Package_Parsed__c, Manual_Package_Parse_Failure_Reason__c
                                        FROM Build__c 
                                        WHERE Id = :packageBuild.Id ];
        System.assertEquals(1, queriedBuild.size(), 
            'There should be one build queried from the database.');
        System.assert(queriedBuild[0].Is_Manual_Package_Parsed__c, 
            'Is_Manual_Package_Parsed__c field should be set to true.');
        System.assert(String.isBlank(queriedBuild[0].Manual_Package_Parse_Failure_Reason__c),
            'Manual_Package_Parse_Failure_Reason__c field should be blank.');
    }

    private static testMethod void makeParsePackageRequest_badPostRequest() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.PARSE_BUILD_PACKAGE_FAIL_ACTION));
        TestingUtils.createOAuthSettings();
        Build__c packageBuild = new Build__c( Package_URL__c='space-man/on/roadster' );
        insert packageBuild;

        Test.startTest();
            try {
                AssemblerServices.makeParsePackageRequest(packageBuild);
            } catch (ALMException ae) {
                System.assert(false, 'No Exception should have been caught.');
            }
        Test.stopTest();

        List<Build__c> queriedBuild = [ SELECT Id, Is_Manual_Package_Parsed__c, Manual_Package_Parse_Failure_Reason__c
                                        FROM Build__c 
                                        WHERE Id =:packageBuild.Id ];

        System.assertEquals(1, queriedBuild.size(), 
            'There should be one build returned with the provided Id.');

        String failureReason = queriedBuild[0].Manual_Package_Parse_Failure_Reason__c;
        System.assert(failureReason.startsWith(System.Label.Generic_Error),
            'The Manual_Package_Parse_Failure_Reason__c field should begin with the generic error value.');
        System.assert(failureReason.contains(MockWebAssemblerAPI.FAILURE_REASON),
            'The Manual_Package_Parse_Failure_Reason__c field should contain the post request failure reason.');
        System.assert(queriedBuild[0].Is_Manual_Package_Parsed__c , 
            'The Is_Manual_Package_Parsed__c field should have been set to true.');
    }

    private static testMethod void makeParsePackageRequest_badPostResponse() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.PARSE_BUILD_PACKAGE_BAD_RESPONSE));
        TestingUtils.createOAuthSettings();
        Build__c packageBuild = new Build__c( Package_URL__c='space-man/on/roadster' );
        insert packageBuild;

        Test.startTest();
            try {
                AssemblerServices.makeParsePackageRequest(packageBuild);
            } catch (ALMException ae) {
                System.assert(false, 'No Exception should have been caught.');
            }
        Test.stopTest();

        List<Build__c> queriedBuild = [ SELECT Id, Is_Manual_Package_Parsed__c, Manual_Package_Parse_Failure_Reason__c
                                        FROM Build__c 
                                        WHERE Id =:packageBuild.Id ];

        System.assertEquals(1, queriedBuild.size(), 
            'There should be one build returned with the provided Id.');

        String failureReason = queriedBuild[0].Manual_Package_Parse_Failure_Reason__c;
        System.assert(failureReason.startsWith(System.Label.Generic_Error),
            'The Manual_Package_Parse_Failure_Reason__c field should begin with the generic error value.');
        // The "Unexpected character" message is specific to the response from the Mock. Other errors may not have this specific message inside.
        System.assert(failureReason.contains( 'Unexpected character' ),
            'The Manual_Package_Parse_Failure_Reason__c field should contain the post request failure reason.');
        System.assert(queriedBuild[0].Is_Manual_Package_Parsed__c , 
            'The Is_Manual_Package_Parsed__c field should have been set to true.');
    }

    private static testMethod void makeParsePackageRequest_badBuildRecord() {
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(AssemblerServices.PARSE_PACKAGE_PATH));
        TestingUtils.createOAuthSettings();
        Build__c packageBuild = new Build__c( Package_URL__c='space-man/on/roadster' );

        Test.startTest();
            try {
                AssemblerServices.makeParsePackageRequest(packageBuild);
                System.assert(false, 'An Exception should have been caught.');
            } catch (ALMException ae) {
                System.assertEquals(System.Label.Generic_Error, ae.getMessage(),
                    'The caught ALMException should have the generic error message.');
            }
        Test.stopTest();
    }
}