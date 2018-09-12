@isTest
private class TestAssembler {

    private static Release__c release;
    private static Instances__c instance;
    private static Backlog__c backlog;
    private static Component__c component;
    private static Backlog_Component__c backlogComponent;
    private static FieldModifiedData envData1;

    private static void setup() {
        release = new Release__c(Name='Summer 14');
        insert release;

        instance = new Instances__c(Name = 'dev');
        insert instance;

        envData1 = new FieldModifiedData( instance.Name,  Datetime.now().addDays(-1), null, null, null);
    }

    private static void setupBacklogItem() {
        backlog = TestingUtils.buildBacklogItem('Complete');
        backlog.Release__c=release.Id;
        insert backlog;
    }

    private static void setupComponent() {
        component = TestingUtils.createComponent('TestField', ComponentServices.APEX_ALM_NAME, instance.Id);
    }

    private static void setupBacklogComponent() {
        backlogComponent = new Backlog_Component__c(Backlog__c = backlog.Id,
             Component__c = component.Id, Source_Instance__c = instance.Id);
        insert backlogComponent;
    }

    private static void setupDocumentedComponent() {
        setupBacklogItem();
        setupComponent();
        setupBacklogComponent();
    }

    private static void setupDocumentedProfile() {
        setupBacklogItem();
        Component__c profileComponent = TestingUtils.createComponent('Test Profile', 'Profile', instance.Id);
        TestingUtils.createDocumentedProfile(backlog.Id, profileComponent, instance.Id);
    }

    private static Assembler setupDeployedAssembler(Release__c testRelease, String status) {
        Assembler testAssembler = new Assembler(testRelease.Id);
        testAssembler.loadManifest();
        testAssembler.saveBuild();
        testAssembler.saveComponents();

        update new Build__c(Id=testAssembler.buildId, Status__c=status);

        return testAssembler;
    }

    private static Build_Component__c buildRemovedBuildComponent(String buildId, Backlog_Component__c backlogComp) {
        Build_Component__c documentedBuildComponent = (new AssemblerManifestRecord(backlogComp)).getBuildComponent();
        documentedBuildComponent.Build__c = buildId;
        documentedBuildComponent.Type__c = AssemblerManifestRecord.REMOVED;

        return documentedBuildComponent;
    }

    private static AssemblerManifestRecord createUndocumentedManifestRecord(Component__c undocumentedComponent, String instanceName) {
        AssemblerManifestRecord record = new AssemblerManifestRecord(
               new ComponentSearchWrapper(undocumentedComponent, instanceName, null, null, null, false)
        );
        record.selected = true;
        return record;
    }

    static testMethod void checkManifestIsStale_manualUpload() {
        setup();
        setupBacklogItem();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        build.Manual_Upload__c = true;
        update build;

        setupComponent();
        setupBacklogComponent();

        Assembler assembler = new Assembler(release.Id, build);

        Test.startTest();

            assembler.checkManifestIsStale();

        Test.stopTest();

        System.assertEquals(false, assembler.isStaleManifest, 'The manifest should not be considered stale when it is a manual upload');

    }

    static testMethod void checkManifestIsStale_staleManifestOnRebuild() {
        setup();
        setupBacklogItem();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        setupComponent();
        setupBacklogComponent();

        Assembler assembler = new Assembler(release.Id, build);

        Test.startTest();

            assembler.checkManifestIsStale();

        Test.stopTest();

        System.assertEquals(true, assembler.isStaleManifest, 'The manifest should be considered stale after a documented component is added');
    }

    static testMethod void checkManifestIsStale_manuallyDeployed() {
        setup();
        setupDocumentedComponent();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        Build_Component__c buildComp = TestingUtils.createDocumentedBuildComponent(backlogComponent, build.Id, instance.Name);

        Assembler assembler = new Assembler(release.Id, build);

        backlogComponent.Deploy_Manually__c = true;
        update backlogComponent;

        Test.startTest();

            assembler.checkManifestIsStale();
        Test.stopTest();

        System.assertEquals(true, assembler.isStaleManifest, 'The manifest should be considered stale when a backlog component is marked as deploy manually');
    }


    static testMethod void filterManifest() {
        setup();
        setupDocumentedComponent();

        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();

        Test.startTest();

            assembler.filteredManifest[0].isRemoved = true;
            assembler.backlogFilters[0].isSelected = true;
            assembler.filterManifest();

        Test.stopTest();

        System.assertEquals(1, assembler.filteredManifest.size(), 'Filtering the manifest by backlog should include the matching component');
        System.assertEquals(true, assembler.manifest[0].isRemoved, 'The state of the component should be maintained after filtering');
        System.assertEquals(true, assembler.filteredManifest[0].isRemoved, 'The state of the component should be maintained after filtering');
    }

    static testMethod void filterManifest_componentsShareComponentIdAndInstanceName() {
        setup();
        setupDocumentedComponent();

        Backlog__c testOtherBacklogItem = new Backlog__c(Release__c = release.Id);
        insert testOtherBacklogItem;
        Backlog_Component__c testOtherBacklogComponent = new Backlog_Component__c(Backlog__c = testOtherBacklogItem.Id, Component__c = component.Id, Source_Instance__c = instance.Id);
        insert testOtherBacklogComponent;

        Assembler testAssembler = new Assembler(release.Id);
        testAssembler.loadManifest();

        Test.startTest();

            testAssembler.filterManifest();

        Test.stopTest();

        System.assertEquals(2, testAssembler.filteredManifest.size(), 'There should be two components in the filtered manifest.');
        System.assertNotEquals(testAssembler.filteredManifest[0].getDocumentedKey(), testAssembler.filteredManifest[1].getDocumentedKey(), 'Both backlog item\'s components should be in the filtered manifest.');
    }

    static testMethod void manifestInstances() {
        setup();
        setupDocumentedComponent();

        Assembler assembler = new Assembler(release.Id);

        System.assertEquals(null, assembler.manifestInstances,
            'Manifest instances should not be initialized before the manifest is loaded');

        assembler.loadManifest();
        Test.startTest();
            System.assertEquals(JSON.serialize(new List<String>{instance.Name}), assembler.manifestInstances,
                 'Manifest instances should be initialized to the json representation of the list of instances in the manifest');
        Test.stopTest();
    }

    static testMethod void manifestInstances_withUndocumentedComponents() {
        setup();
        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();

        Component__c undocumentedComponent = TestingUtils.createUndocumentedComponent('Undocumented', 'Field', instance.Id, envData1);
        ComponentSearchWrapper undocumentedSearchItem = new ComponentSearchWrapper(undocumentedComponent, instance.Name, '', null, '', false);

        Test.startTest();
            String undocumentedKey = undocumentedSearchItem.getKey();
            assembler.selectedComponentIdString = undocumentedKey;
            assembler.addUndocumentedComponents();
        Test.stopTest();

        System.assertEquals(JSON.serialize(new List<String>{instance.Name}), assembler.manifestInstances,
                            'The manifestInstances should contain the instance from the undocumented component');
    }

    static testMethod void manifestInstances_onlyFromProfiles() {
        setup();
        setupDocumentedProfile();

        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();

        System.assertEquals(0, assembler.manifest.size(), 'The manifest should not have any documented components.');
        System.assertEquals(0, assembler.undocumentedComponents.size(), 'There should not be any undocumented components.');
        System.assertEquals(1, assembler.selectedPermissions.size(), 'There should only be one profile in the manifest.');

        Test.startTest();
            System.assertEquals(JSON.serialize(new List<String>{instance.Name}), assembler.manifestInstances,
                'Manifest instances should contain one instance name that equals the instance name of the documented profile instance.');
        Test.stopTest();
    }

    static testMethod void loadManifest_ExistingBuild() {
        setup();
        setupDocumentedComponent();

        Component__c undocumentedComponent = TestingUtils.createUndocumentedComponent('Test field 2', 'Field', instance.Id, envData1);

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Build_Component__c documentedBuildComponent = (new AssemblerManifestRecord(backlogComponent)).getBuildComponent();
        documentedBuildComponent.Build__c = build.Id;

        Build_Component__c undocumentedBuildComponent =
            createUndocumentedManifestRecord(undocumentedComponent, instance.Name).getBuildComponent();
        undocumentedBuildComponent.Build__c = build.Id;

        insert new List<Build_Component__c> { documentedBuildComponent, undocumentedBuildComponent };

        Test.startTest();
            Assembler ass = new Assembler(release.Id, build);
            ass.loadManifest();
        Test.stopTest();

        System.assertEquals(1, ass.manifest.size(), 'There should be 1 documented build component loaded.');
        System.assertEquals(documentedBuildComponent.Id, ass.manifest[0].getBuildComponent().Id,
            'The documented build component loaded should be a documented component.');

        System.assertEquals(1, ass.undocumentedComponents.size(),
            'There should only be 1 undocumented build component loaded.');
        System.assertEquals(undocumentedBuildComponent.Id, ass.undocumentedComponents[0].getBuildComponent().Id,
            'The undocumented build component loaded should be an undocumented component.');

        Map<String, Set<String>> documentedComponentsJSON =
            (Map<String, Set<String>>)JSON.deserialize(ass.documentedComponentsJSON, Map<String, Set<String>>.class);
        System.assertEquals(1, documentedComponentsJSON.size(),
            'Only documented components should be included in the documented components JSON');

        System.assertEquals(true, documentedComponentsJSON.containsKey(ProfileServices.APEX_API_NAME),
            'There should be a section for the documented component');

        System.assertEquals(1, documentedComponentsJSON.get(ProfileServices.APEX_API_NAME).size(),
            'The section should contain the documented component');

        String expectedPermissionName = component.Name + ProfileServices.PROFILE_NAME_INSTANCE_DELIMETER + instance.Name;

        System.assertEquals(true, documentedComponentsJSON.get(ProfileServices.APEX_API_NAME).contains(expectedPermissionName),
            'The section should contain the documented component');
    }

    static testMethod void loadManifest_removedComponent_isExcludedFromDocumentedPermissionsJSON() {
        setup();
        setupDocumentedComponent();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        Build_Component__c documentedBuildComponent = (new AssemblerManifestRecord(backlogComponent)).getBuildComponent();
        documentedBuildComponent.Build__c = build.Id;

        Component__c removedComponent = TestingUtils.createComponent('RemoveMe', ComponentServices.OBJECT_ALM_NAME, instance.Id);
        Backlog_Component__c removedBacklogComponent = TestingUtils.buildDocumentedComponent(backlog.Id, removedComponent, instance.Id);
        insert removedBacklogComponent;

        Build_Component__c removedBuildComponent = buildRemovedBuildComponent(build.Id, removedBacklogComponent);

        insert new List<Build_Component__c> { documentedBuildComponent, removedBuildComponent };


        Test.startTest();
            Assembler ass = new Assembler(release.Id, build);
            ass.loadManifest();
        Test.stopTest();

        Map<String, Set<String>> documentedComponentsJSON =
            (Map<String, Set<String>>)JSON.deserialize(ass.documentedComponentsJSON, Map<String, Set<String>>.class);
        System.assertEquals(1, documentedComponentsJSON.size(),
            'Removed components should be excluded from the documented components JSON');

        System.assertEquals(true, documentedComponentsJSON.containsKey(ProfileServices.APEX_API_NAME),
            'There should be a section for the documented component');

        System.assertEquals(1, documentedComponentsJSON.get(ProfileServices.APEX_API_NAME).size(),
            'The section should contain the documented component');

        String expectedPermissionName = component.Name + ProfileServices.PROFILE_NAME_INSTANCE_DELIMETER + instance.Name;

        System.assertEquals(true, documentedComponentsJSON.get(ProfileServices.APEX_API_NAME).contains(expectedPermissionName),
            'The section should contain the documented component');
    }

    static testMethod void loadManifest_ExistingBuild_reapplyRemovedComponent() {
        setup();
        setupDocumentedComponent();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Build_Component__c removedBuildComponent = buildRemovedBuildComponent(build.Id, backlogComponent);
        insert removedBuildComponent;

        Assembler assembler = new Assembler(release.Id, build);
        assembler.loadManifest();
        Test.startTest();

            assembler.manifest[0].isRemoved = false;
            assembler.saveComponents();

        Test.stopTest();

        removedBuildComponent = [SELECT Id, Type__c FROM Build_Component__c WHERE Id = :removedBuildComponent.Id];

        System.assertEquals(AssemblerManifestRecord.DOCUMENTED, removedBuildComponent.Type__C, 'After being re-added, the build component type should be Documented.');
    }

    static testMethod void loadManifest_ExistingBuild_removedPermission() {
        setup();
        setupBacklogItem();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);


        Component__c documentedProfile = new Component__c(Name='x profile 1', Type__c='Profile');
        insert documentedProfile;

        Backlog_Component__c documentedProfileBacklogComponent = TestingUtils.createDocumentedProfile(backlog.Id, documentedProfile, instance.Id);

        Build_Component__c documentedProfileBuildComponent = buildRemovedBuildComponent(build.Id, documentedProfileBacklogComponent);
        insert documentedProfileBuildComponent;

        Test.startTest();
            Assembler ass = new Assembler(release.Id, build);
            ass.loadManifest();
        Test.stopTest();

        System.assertEquals(1, ass.documentedPermissions.size(), 'There should be 1 documented profile component loaded.');
        System.assertEquals(documentedProfileBuildComponent.Id, ass.documentedPermissions[0].getBuildComponent().Id, 'The documented profile build component should be loaded.');
        System.assertEquals(AssemblerManifestRecord.REMOVED, ass.documentedPermissions[0].getBuildComponent().Type__c, 'The documented profile build component loaded should be marked as removed.');
        System.assertEquals(0, ass.selectedPermissions.size(), 'Selected permissions should not include removed components.');
    }

    static testMethod void loadManifest_Rebuild_removedPermission() {
        setup();
        setupBacklogItem();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Component__c documentedProfile = new Component__c(Name='x profile 1', Type__c='Profile');
        insert documentedProfile;

        Backlog_Component__c documentedProfileBacklogComponent = TestingUtils.createDocumentedProfile(backlog.Id, documentedProfile, instance.Id);

        Build_Component__c documentedProfileBuildComponent = buildRemovedBuildComponent(build.Id, documentedProfileBacklogComponent);
        documentedProfileBuildComponent.Is_Profile__c = true;
        insert documentedProfileBuildComponent;

        Test.startTest();
            Assembler assembler = new Assembler(release.Id, build);
            assembler.loadManifest();
        Test.stopTest();

        System.assertEquals(1, assembler.documentedPermissions.size(), 'There should be 1 documented profile component loaded.');
        System.assertEquals(null, assembler.documentedPermissions[0].getBuildComponent().Id, 'The documented profile build component should be cloned for rebuild.');
        System.assertEquals(false, assembler.documentedPermissions[0].selected, 'The documented profile build component loaded should not be selected.');
        System.assertEquals(AssemblerManifestRecord.REMOVED, assembler.documentedPermissions[0].getBuildComponent().Type__c, 'The documented profile build component loaded should be marked as removed.');
        System.assertEquals(0, assembler.selectedPermissions.size(), 'Selected permissions should not include removed components.');
    }

    static testMethod void loadManifest_Rebuild() {
        setup();
        setupDocumentedComponent();
        Component__c undocumentedComponent = TestingUtils.createUndocumentedComponent('Test field 2', 'Field', instance.Id, envData1);

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Build_Component__c removedBuildComponent = buildRemovedBuildComponent(build.Id, backlogComponent);

        Build_Component__c undocumentedBuildComponent =
            createUndocumentedManifestRecord(undocumentedComponent, instance.Name).getBuildComponent();
        undocumentedBuildComponent.Build__c = build.Id;

        insert new List<Build_Component__c> { removedBuildComponent, undocumentedBuildComponent };

        Test.startTest();
            Assembler ass = new Assembler(release.Id, build);
        Test.stopTest();

        System.assertEquals(1, ass.manifest.size(), 'There should only be 1 documented build component loaded.');
        System.assertEquals(null, ass.manifest[0].getBuildComponent().Id, 'The documented build component loaded should be cloned.');

        System.assertEquals(true, ass.manifest[0].isRemoved, 'The removed build component should be marked as removed.');
        System.assertEquals(1, ass.undocumentedComponents.size(), 'There should only be 1 undocumented build component loaded.');
        System.assertEquals(null, ass.undocumentedComponents[0].getBuildComponent().Id, 'The undocumented build component loaded should be cloned component.');
    }

    static testMethod void loadManifest_Rebuild_buildWithRepoSource() {
        setup();

        VC_Repository__c repo = TestingUtils.createVcRepository('git-repo', 'http://www.git.com', 'GitHub', 'GitTest');

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        build.Source_Repository__c = repo.Id;
        build.Source_Repository_Location__c = 'some branch';

        Test.startTest();
            Assembler ass = new Assembler(release.Id, build);
        Test.stopTest();

        System.assertEquals(build.Source_Repository__c, ass.build.Source_Repository__c, 'The repository should be copied during a rebuild.');
        System.assertEquals(build.Source_Repository_Location__c, ass.build.Source_Repository_Location__c, 'The repository location should be copied during a rebuild.');
    }

    static testMethod void loadManifest_RebuildProfileWithDeletedBuildComponent() {
        setup();

        setupBacklogItem();
        Component__c profileComponent = new Component__c(Name='Admin profile', Type__c='Profile');
        profileComponent.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData1 } );
        insert profileComponent;

        Backlog_Component__c documentedProfile = TestingUtils.createDocumentedProfile(backlog.Id, profileComponent, instance.Id);

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Build_Component__c profileBuildComponent = (new ProfileManifestRecord(documentedProfile)).getBuildComponent();
        profileBuildComponent.Build__c = build.Id;
        insert profileBuildComponent;

        delete documentedProfile;

        Test.startTest();
            Assembler assembler = new Assembler(release.Id, build);
        Test.stopTest();

        System.assertEquals(1, assembler.selectedPermissions.size(), 'There should be 1 selected permission.');
        System.assertEquals(null, assembler.selectedPermissions[0].getBuildComponent().Id, 'The documented profile loaded should be cloned.');
        System.assertEquals(profileComponent.Name, assembler.selectedPermissions[0].profileName, 'The selected permission name should remain the same when the backlog component is deleted.');
    }

    static testMethod void loadManifest_Rebuild_WithUndocumentedProfile() {
        setup();

        Component__c profileComponent = new Component__c(Name='Admin profile', Type__c='Profile');
        profileComponent.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ envData1 } );
        insert profileComponent;

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Build_Component__c profileBuildComponent = createUndocumentedManifestRecord( profileComponent, instance.iD).getBuildComponent();
        profileBuildComponent.Build__c = build.Id;
        profileBuildComponent.Is_Profile__c = true;
        insert profileBuildComponent;

        Test.startTest();
            Assembler assembler = new Assembler(release.Id, build);
        Test.stopTest();

        System.assertEquals(1, assembler.selectedPermissions.size(), 'There should be 1 selected permission.');
        System.assertEquals(true, assembler.undocumentedPermissions[0].selected, 'The undocumented profile should be selected');
    }

    static testMethod void loadManifest_rebuild_addProfiles() {
        setup();
        setupBacklogItem();

        // Create a previous build to prompt the rebuild flow.
        Build__c testBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        String testProfileName = 'Test Profile';
        String otherTestProfileName = 'Other Test Profile';

        Component__c testDocumentedProfileComponent = TestingUtils.createUndocumentedComponent(testProfileName, 'Profile', instance.Id, envData1);
        Component__c testUndocumentedProfileComponent = TestingUtils.createUndocumentedComponent(otherTestProfileName, 'Profile', instance.Id, envData1);

        TestingUtils.createDocumentedProfile(backlog.Id, testUndocumentedProfileComponent, instance.Id);

        Assembler testAssembler = new Assembler(release.Id, testBuild);

        Test.startTest();

            testAssembler.loadManifest();

        Test.stopTest();

        System.assertEquals(0, testAssembler.documentedPermissions.size(), 'The proper number of documented permissions should exist.');
        System.assertEquals(2, testAssembler.undocumentedPermissions.size(), 'The proper number of undocumented permissions should exist.');
        System.assertEquals(otherTestProfileName, testAssembler.undocumentedPermissions[0].profileName, 'The undocumented permissions should be sorted.');
        System.assertEquals(testProfileName, testAssembler.undocumentedPermissions[1].profileName, 'The undocumented permissions should be sorted.');
    }

    static testMethod void loadManifest_rebuild_swapProfiles() {
        setup();
        setupBacklogItem();

        String testInitialProfileName = 'Test Initial Profile';
        String testNewProfileName = 'Test New Profile';

        Component__c testInitialProfileComponent = TestingUtils.createUndocumentedComponent(testInitialProfileName, 'Profile', instance.Id, envData1);
        Component__c testNewProfileComponent = TestingUtils.createUndocumentedComponent(testNewProfileName, 'Profile', instance.Id, envData1);

        Backlog_Component__c testInitialProfileBacklogComponent = TestingUtils.createDocumentedProfile(backlog.Id, testInitialProfileComponent, instance.Id);

        Assembler testAssembler = setupDeployedAssembler(release, BuildServices.STATUS_SUCCESS);

        Test.startTest();

            delete testInitialProfileBacklogComponent;
            TestingUtils.createDocumentedProfile(backlog.Id, testNewProfileComponent, instance.Id);

            Build__c initialBuild = BuildServices.getBuild(testAssembler.buildId);
            testAssembler = new Assembler(release.Id, initialBuild);
            testAssembler.loadManifest();

        Test.stopTest();

        System.assertEquals(1, testAssembler.documentedPermissions.size(), 'The proper number of documented permissions should exist.');
        System.assertEquals(testInitialProfileName, testAssembler.documentedPermissions[0].profileName, 'The documented profile name should match.');
        System.assertEquals(1, testAssembler.undocumentedPermissions.size(), 'The proper number of undocumented permissions should exist.');
        System.assertEquals(testNewProfileName, testAssembler.undocumentedPermissions[0].profileName, 'The undocumented profile name should match.');
    }

    static testMethod void loadManifest_newBuild() {
        setup();
        setupDocumentedComponent();

        Test.startTest();
            Assembler assembler = new Assembler(release.Id);
            assembler.loadManifest();
        Test.stopTest();

        System.assertEquals(1, assembler.manifest.size(), 'There should only be 1 documented build component loaded.');
        System.assertEquals(backlogComponent.Id, assembler.manifest[0].getBuildComponent().Backlog_Component__c, 'The documented component should be loaded.');

        System.assertEquals(0, assembler.undocumentedComponents.size(), 'Undocumented components should be empy when loading new builds.');
        System.assertEquals(1, assembler.componentCount, 'Component count should be the count of documented and unocumented components.');
    }

    static testMethod void removeUndocumentedComponents() {
        setup();
        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();

        Component__c undocumentedComponent = TestingUtils.createUndocumentedComponent(
                'Undocumented', 'Field', instance.Id, envData1);
        AssemblerManifestRecord undocumentedRecord = createUndocumentedManifestRecord(
                undocumentedComponent, instance.Name);

        String undocumentedKey = undocumentedRecord.getKey();

        assembler.selectedComponentIdString = undocumentedKey;
        assembler.undocumentedComponents.add(undocumentedRecord);

        Test.startTest();
            assembler.removeUndocumentedComponents();
        Test.stopTest();

        System.assertEquals(0, assembler.undocumentedComponents.size(),
                'The undocumented component should be removed');
    }

    static testMethod void removeUndocumentedComponents_emptySelectedComponentId() {
        setup();
        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();

        Component__c undocumentedComponent = TestingUtils.createUndocumentedComponent(
                'Undocumented', 'Field', instance.Id, envData1);
        AssemblerManifestRecord undocumentedRecord = createUndocumentedManifestRecord(
                undocumentedComponent, instance.Name);
        assembler.undocumentedComponents.add(undocumentedRecord);

        Test.startTest();
            assembler.removeUndocumentedComponents();
        Test.stopTest();

        System.assertEquals(1, assembler.undocumentedComponents.size(),
                'The undocumented component should not be removed');
        System.assertEquals(0, assembler.removedBuildComps.size(),
                'The removedBuildComps list size should be empty .');
    }

    static testMethod void removeUndocumentedComponents_multipleRemovals() {
        setup();
        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();
        assembler.saveBuild();

        Component__c firstUndocumentedComponent = TestingUtils.createUndocumentedComponent(
                'FirstUndocumented', 'Field', instance.Id, envData1);
        Component__c secondUndocumentedComponent = TestingUtils.createUndocumentedComponent(
                'SecondUndocumented', 'Field', instance.Id, envData1);
        AssemblerManifestRecord firstUndocumentedRecord = createUndocumentedManifestRecord(
                firstUndocumentedComponent, instance.Name);
        AssemblerManifestRecord secondUndocumentedRecord = createUndocumentedManifestRecord(
                secondUndocumentedComponent, instance.Name);

        assembler.undocumentedComponents.add(firstUndocumentedRecord);
        assembler.undocumentedComponents.add(secondUndocumentedRecord);
        assembler.saveComponents();

        Id expectedFirstBuildComponentId = firstUndocumentedRecord.getBuildComponent().Id;
        Id expectedSecondBuildComponentId = secondUndocumentedRecord.getBuildComponent().Id;

        String firstUndocumentedKey = firstUndocumentedRecord.getKey();
        String secondUndocumentedKey = secondUndocumentedRecord.getKey();
        assembler.selectedComponentIdString = firstUndocumentedKey + ',' + secondUndocumentedKey;

        Test.startTest();
            assembler.removeUndocumentedComponents();
        Test.stopTest();

        Set<Id> actualRemovedBuildCompIds = Pluck.ids(assembler.removedBuildComps);

        System.assertEquals(0, assembler.undocumentedComponents.size(),
                'The undocumented components should be removed.');
        System.assertEquals(2, actualRemovedBuildCompIds.size(),
                'The size of removedBuildComps should be 2.');
        System.assert(actualRemovedBuildCompIds.contains(expectedFirstBuildComponentId),
                'The expected set of build component ids should contain the first expected build comp id.');
        System.assert(actualRemovedBuildCompIds.contains(expectedSecondBuildComponentId),
                'The expected set of build component ids should contain the second expected build comp id.');
    }

    static testMethod void addUndocumentedComponents() {
        setup();
        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();

        Component__c undocumentedComponent = TestingUtils.createUndocumentedComponent('Undocumented', 'Field', instance.Id, envData1);

        ComponentSearchWrapper undocumentedSearchItem = new ComponentSearchWrapper(undocumentedComponent, instance.Name, '', null, '', false);
        Test.startTest();
            String undocumentedKey = undocumentedSearchItem.getKey();
            assembler.selectedComponentIdString = undocumentedKey;
            assembler.addUndocumentedComponents();
        Test.stopTest();

        System.assertEquals(1, assembler.undocumentedComponents.size(), 'The component should be added to the undocumented list');
        System.assertEquals(undocumentedKey, assembler.undocumentedComponents[0].getKey(), 'The component should be added to the undocumented list');
    }

    static testMethod void addUndocumentedComponents_profiles() {
        String testComponentName = 'Test Component Name';

        setup();

        Assembler testAssembler = new Assembler(release.Id);
        testAssembler.loadManifest();

        Component__c undocumentedProfile = TestingUtils.createUndocumentedComponent(testComponentName, 'Profile', instance.Id, envData1);
        ComponentSearchWrapper undocumentedProfileWrapper = new ComponentSearchWrapper(undocumentedProfile, instance.Name, '', null, '', false);

        Test.startTest();

            testAssembler.selectedComponentIdString = undocumentedProfileWrapper.getKey();
            testAssembler.addUndocumentedComponents();

        Test.stopTest();

        System.assertEquals(1, testAssembler.undocumentedPermissions.size(), 'There should be one element in the undocumented permissions list.');
        System.assertEquals(undocumentedProfileWrapper.component.Name, testAssembler.undocumentedPermissions[0].getName(), 'The profile should be the only element in the undocumented permissions list.');
        System.assertEquals(1, testAssembler.selectedPermissions.size(), 'There should be one element in the selected permissions list.');
        System.assertEquals(undocumentedProfileWrapper.component.Name, testAssembler.selectedPermissions[0].getName(), 'The profile should be the only element in the selected permissions list.');
    }

    static testMethod void removeComponentProfileData() {
        setup();
        setupDocumentedComponent();

        Backlog_Component__c documentedProfileComponent = TestingUtils.createDocumentedProfile(backlog.Id, 'profile 1', instance.Id);

        Component__c removedComponent = TestingUtils.createComponent('zzRemoveMe', ComponentServices.OBJECT_ALM_NAME, instance.Id);
        Backlog_Component__c removedBacklogComponent = TestingUtils.buildDocumentedComponent(backlog.Id, removedComponent, instance.Id);
        insert removedBacklogComponent;

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Build_Component__c documentedBuildComponent = (new AssemblerManifestRecord(backlogComponent)).getBuildComponent();
        documentedBuildComponent.Build__c = build.Id;

        Build_Component__c buildComponentToRemove = (new AssemblerManifestRecord(removedBacklogComponent)).getBuildComponent();
        buildComponentToRemove.Build__c = build.Id;


        Boolean includeEntireProfile = false;
        Boolean includeOnlyDocumentedComponents = true;
        ProfilePermissions selectedPermissions = new ProfilePermissions();

        final String OTHER_SECTION_NAME = 'adminSection';
        final String MANUAL_SELECTION_NAME = 'permission1';
        String documentedSectionName = ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(component.Type__c);
        String removedComponentSectionName = ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(removedComponent.Type__c);

        TestingUtils.buildProfilePermissionsSection(selectedPermissions, OTHER_SECTION_NAME, new List<String> { MANUAL_SELECTION_NAME });
        TestingUtils.buildProfilePermissionsSection(selectedPermissions, documentedSectionName, new List<String> {component.Name});
        TestingUtils.buildProfilePermissionsSection(selectedPermissions, removedComponentSectionName, new List<String> {removedComponent.Name});

        Build_Component__c profileBuildComponent = TestingUtils.buildProfileBuildComponent(build.Id,
            documentedProfileComponent, selectedPermissions, includeEntireProfile, includeOnlyDocumentedComponents);

        insert new List<Build_Component__c> { documentedBuildComponent, buildComponentToRemove, profileBuildComponent };

        Assembler assembler = new Assembler(release.Id, build);
        assembler.loadManifest();
        //simulate this being a transient property
        assembler.documentedComponentsJSON = null;

        Test.startTest();
            AssemblerManifestRecord recordToRemove = (assembler.manifest[0].getName() == removedComponent.Name)
                ? assembler.manifest[0] : assembler.manifest[1];
            recordToRemove.isRemoved = true;
            assembler.pendingRemovals = recordToRemove.getKey();
            assembler.removeComponentProfileData();
        Test.stopTest();

        ProfilePermissions permissions = ProfilePermissions.valueOf( assembler.documentedPermissions[0].selectedPermissions );
        System.assertEquals(3, permissions.sections.size(), 'the number of sections should be unchanged');

        Map<String, ProfilePermissions.Section> sectionMap = permissions.getSectionMap();
        System.assertEquals(true, sectionMap.containsKey(OTHER_SECTION_NAME), 'Manually selected permissions should be unchanged');
        System.assertEquals(1, sectionMap.get(OTHER_SECTION_NAME).permissions.size(), 'Manually selected permissions should be unchanged');
        System.assertEquals(MANUAL_SELECTION_NAME, sectionMap.get(OTHER_SECTION_NAME).permissions[0], 'Manually selected permissions should be unchanged');

        System.assertEquals(true, sectionMap.containsKey(documentedSectionName), 'The documented section should be unchanged');
        System.assertEquals(1, sectionMap.get(documentedSectionName).permissions.size(), 'The documented section should be unchanged');
        System.assertEquals(component.Name, sectionMap.get(documentedSectionName).permissions[0], 'The documented section should be unchanged');

        System.assertEquals(true, sectionMap.containsKey(removedComponentSectionName), 'The section with the removed component should still exist');
        System.assertEquals(0, sectionMap.get(removedComponentSectionName).permissions.size(), 'The removed component should have its permission removed');

        Map<String, Set<String>> documentedComponentsJSON =
            (Map<String, Set<String>>)JSON.deserialize(assembler.documentedComponentsJSON, Map<String, Set<String>>.class);
        System.assertEquals(1, documentedComponentsJSON.size(), 'the json should be updated to exclude removed components');
    }

    static testMethod void removeComponentProfileData_multipleRemovals() {
        setup();
        setupDocumentedComponent();

        final String PROFILE_1_NAME = 'profile 1';
        final String PROFILE_2_NAME = 'profile 2';
        final String COMPONENT_TO_REMOVE_NAME_PREFIX = 'zzRemoveMe';

        Backlog_Component__c documentedProfileComponent1 = TestingUtils.createDocumentedProfile(backlog.Id, PROFILE_1_NAME, instance.Id);
        Backlog_Component__c documentedProfileComponent2 = TestingUtils.createDocumentedProfile(backlog.Id, PROFILE_2_NAME, instance.Id);

        Component__c removedComponent1 = TestingUtils.createComponent(COMPONENT_TO_REMOVE_NAME_PREFIX + '1', ComponentServices.OBJECT_ALM_NAME, instance.Id);
        Backlog_Component__c removedBacklogComponent1 = TestingUtils.buildDocumentedComponent(backlog.Id, removedComponent1, instance.Id);
        insert removedBacklogComponent1;

        Component__c removedComponent2 = TestingUtils.createComponent(COMPONENT_TO_REMOVE_NAME_PREFIX + '2', ComponentServices.OBJECT_ALM_NAME, instance.Id);
        Backlog_Component__c removedBacklogComponent2 = TestingUtils.buildDocumentedComponent(backlog.Id, removedComponent2, instance.Id);
        insert removedBacklogComponent2;

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Build_Component__c documentedBuildComponent = (new AssemblerManifestRecord(backlogComponent)).getBuildComponent();
        documentedBuildComponent.Build__c = build.Id;

        Build_Component__c buildComponentToRemove1 = (new AssemblerManifestRecord(removedBacklogComponent1)).getBuildComponent();
        buildComponentToRemove1.Build__c = build.Id;

        Build_Component__c buildComponentToRemove2 = (new AssemblerManifestRecord(removedBacklogComponent2)).getBuildComponent();
        buildComponentToRemove2.Build__c = build.Id;

        Boolean includeEntireProfile = false;
        Boolean includeOnlyDocumentedComponents = true;
        ProfilePermissions selectedPermissions = new ProfilePermissions();

        String documentedSectionName = ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(component.Type__c);
        String removedComponentSectionName = ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(removedComponent1.Type__c);

        TestingUtils.buildProfilePermissionsSection(selectedPermissions, documentedSectionName, new List<String> {component.Name});
        TestingUtils.buildProfilePermissionsSection(selectedPermissions, removedComponentSectionName, new List<String> {removedComponent1.Name, removedComponent2.Name});

        Build_Component__c profileBuildComponent1 = TestingUtils.buildProfileBuildComponent(build.Id,
            documentedProfileComponent1, selectedPermissions, includeEntireProfile, includeOnlyDocumentedComponents);

        final String OTHER_SECTION_NAME = 'adminSection';
        final String MANUAL_SELECTION_NAME = 'permission1';
        TestingUtils.buildProfilePermissionsSection(selectedPermissions, OTHER_SECTION_NAME, new List<String> { MANUAL_SELECTION_NAME });

        Build_Component__c profileBuildComponent2 = TestingUtils.buildProfileBuildComponent(build.Id,
            documentedProfileComponent2, selectedPermissions, includeEntireProfile, includeOnlyDocumentedComponents);

        insert new List<Build_Component__c> { documentedBuildComponent, buildComponentToRemove1, buildComponentToRemove2, profileBuildComponent1, profileBuildComponent2 };

        Assembler assembler = new Assembler(release.Id, build);
        assembler.loadManifest();

        Test.startTest();

            List<String> pendingRemovals = new List<String>();
            for(AssemblerManifestRecord record : assembler.manifest) {
                if (record.getName().startsWith(COMPONENT_TO_REMOVE_NAME_PREFIX)) {
                    record.isRemoved = true;
                    pendingRemovals.add(record.getKey());
                }
            }

            assembler.pendingRemovals = String.join(pendingRemovals, ',');
            assembler.removeComponentProfileData();
        Test.stopTest();

        ProfileManifestRecord profileManifestRecord1, profileManifestRecord2;

        if (assembler.documentedPermissions[0].getName() == PROFILE_1_NAME) {
            profileManifestRecord1 = assembler.documentedPermissions[0];
            profileManifestRecord2 = assembler.documentedPermissions[1];
        } else {
            profileManifestRecord1 = assembler.documentedPermissions[1];
            profileManifestRecord2 = assembler.documentedPermissions[0];
        }

        ProfilePermissions permissions1 = ProfilePermissions.valueOf( profileManifestRecord1.selectedPermissions );
        System.assertEquals(2, permissions1.sections.size(), 'the number of sections should be unchanged');
        Map<String, ProfilePermissions.Section> sectionMap1 = permissions1.getSectionMap();

        System.assertEquals(true, sectionMap1.containsKey(documentedSectionName), 'The documented section should be unchanged');
        System.assertEquals(1, sectionMap1.get(documentedSectionName).permissions.size(), 'The documented section should be unchanged');
        System.assertEquals(component.Name, sectionMap1.get(documentedSectionName).permissions[0], 'The documented section should be unchanged');

        System.assertEquals(true, sectionMap1.containsKey(removedComponentSectionName), 'The section with the removed component should still exist');
        System.assertEquals(0, sectionMap1.get(removedComponentSectionName).permissions.size(), 'The removed component should have its permission removed');

        ProfilePermissions permissions2 = ProfilePermissions.valueOf( profileManifestRecord2.selectedPermissions );
        System.assertEquals(3, permissions2.sections.size(), 'the number of sections should be unchanged');
        Map<String, ProfilePermissions.Section> sectionMap2 = permissions2.getSectionMap();

        System.assertEquals(true, sectionMap2.containsKey(OTHER_SECTION_NAME), 'Manually selected permissions should be unchanged');
        System.assertEquals(1, sectionMap2.get(OTHER_SECTION_NAME).permissions.size(), 'Manually selected permissions should be unchanged');
        System.assertEquals(MANUAL_SELECTION_NAME, sectionMap2.get(OTHER_SECTION_NAME).permissions[0], 'Manually selected permissions should be unchanged');

        System.assertEquals(true, sectionMap2.containsKey(documentedSectionName), 'The documented section should be unchanged');
        System.assertEquals(1, sectionMap2.get(documentedSectionName).permissions.size(), 'The documented section should be unchanged');
        System.assertEquals(component.Name, sectionMap2.get(documentedSectionName).permissions[0], 'The documented section should be unchanged');

        System.assertEquals(true, sectionMap2.containsKey(removedComponentSectionName), 'The section with the removed component should still exist');
        System.assertEquals(0, sectionMap2.get(removedComponentSectionName).permissions.size(), 'The removed component should have its permission removed');
    }

    static testMethod void removeComponentProfileData_excludeCompleteProfiles() {
        setup();
        setupDocumentedComponent();

        Backlog_Component__c documentedProfileComponent = TestingUtils.createDocumentedProfile(backlog.Id, 'profile 1', instance.Id);

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Build_Component__c documentedBuildComponent = (new AssemblerManifestRecord(backlogComponent)).getBuildComponent();
        documentedBuildComponent.Build__c = build.Id;

        Boolean includeEntireProfile = true;
        Boolean includeOnlyDocumentedComponents = true;

        Build_Component__c profileBuildComponent = TestingUtils.buildProfileBuildComponent(build.Id,
            documentedProfileComponent, null, includeEntireProfile, includeOnlyDocumentedComponents);

        insert new List<Build_Component__c> { documentedBuildComponent, profileBuildComponent };

        Assembler assembler = new Assembler(release.Id, build);
        assembler.loadManifest();

        Test.startTest();
            AssemblerManifestRecord recordToRemove = assembler.manifest[0];
            recordToRemove.isRemoved = true;
            assembler.pendingRemovals = recordToRemove.getKey();
            assembler.removeComponentProfileData();
        Test.stopTest();

        System.assertEquals(true, assembler.documentedPermissions[0].includeEntireProfile, 'The profile should still be marked to deploy the entire profile');
        System.assertEquals('', assembler.pendingRemovals, 'The pending list of components to be removed should be cleared out');

        ProfilePermissions permissions = ProfilePermissions.valueOf( assembler.documentedPermissions[0].selectedPermissions );
        System.assertEquals(0, permissions.sections.size(), 'Profiles set to include the entire profile should have an empty permissions data field');
    }

    static testMethod void saveComponents_profiles() {
        setup();

        setupDocumentedComponent();

        Component__c documentedProfile = new Component__c(Name='x profile 1', Type__c='Profile');
        Component__c undocumentedProfile = new Component__c(Name='z undocumented profile 2', Type__c='Profile');
        insert new List<Component__c>{documentedProfile, undocumentedProfile};

        Backlog_Component__c documentedProfileComponent = TestingUtils.createDocumentedProfile(backlog.Id, documentedProfile, instance.Id);

        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();
        assembler.saveBuild();

        Test.startTest();

            ProfileManifestRecord undocumentedProfileRecord = assembler.undocumentedPermissions[0];
            undocumentedProfileRecord.selected = true;
            assembler.updateProfileSelection();

            assembler.saveComponents();

        Test.stopTest();

        List<Build__c> builds = [
            Select Id, ( SELECT Is_Profile__c, Backlog_Component__c, Component_Name__c, Component_Type__c, Instance_Name__c, Type__c
                         FROM Build_Components__r
                         Order By Component_Name__c)
            From Build__c
            Where Release__c =: release.Id
        ];

        System.assertEquals(1, builds.size(), 'There should only be one build record created.');

        Build__c actualBuild = builds[0];

        System.assertEquals(3, actualBuild.Build_Components__r.size(), 'There should be 3 build component records created.');

        System.assertEquals(false, actualBuild.Build_Components__r[0].Is_Profile__c, 'Only profile components should be marked as profiles');
        System.assertEquals(true, actualBuild.Build_Components__r[1].Is_Profile__c, 'Only profile components should be marked as profiles');
        System.assertEquals(true, actualBuild.Build_Components__r[2].Is_Profile__c, 'Only profile components should be marked as profiles');

        System.assertEquals(documentedProfileComponent.Id, actualBuild.Build_Components__r[1].Backlog_Component__c, 'The component lookup should be set');
        System.assertEquals(instance.Name, actualBuild.Build_Components__r[1].Instance_Name__c, 'The instance name should be set');
        System.assertEquals(AssemblerManifestRecord.DOCUMENTED, actualBuild.Build_Components__r[1].Type__c, 'The build component type should be documented');

        System.assertEquals(null, actualBuild.Build_Components__r[2].Backlog_Component__c, 'The component lookup should be blank for undocumented profiles');
        System.assertEquals(AssemblerManifestRecord.UNDOCUMENTED, actualBuild.Build_Components__r[2].Type__c, 'The build component type should be undocumented');
        System.assertEquals(undocumentedProfile.Name, actualBuild.Build_Components__r[2].Component_Name__c, 'The component name should be set to the name of the profile ');
    }

    static testMethod void saveComponents_profilesWithPermissions() {
        setup();

        setupBacklogItem();

        Component__c profileComponent = TestingUtils.createComponent('x profile 1', 'Profile', instance.Id);
        Backlog_Component__c documentedProfileComponent = TestingUtils.createDocumentedProfile(backlog.Id, profileComponent, instance.Id);

        ProfilePermissions expectedPermission = new ProfilePermissions();
        ProfilePermissions.Section section = new ProfilePermissions.Section();
        section.apiName = 'test section';
        section.permissions = new List<String> {'permission1'};

        expectedPermission.sections.add(section);
        String selectedPermissionsString = JSON.serialize(expectedPermission);

        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();

        Test.startTest();
            assembler.documentedPermissions[0].selectedPermissions = selectedPermissionsString;

            assembler.saveBuild();
            assembler.saveComponents();

        Test.stopTest();

        List<Build__c> builds = [
            Select Id, ( SELECT Is_Profile__c, Backlog_Component__c, Component_Name__c, Component_Type__c, Instance_Name__c, Type__c,
                        Include_Documented_Components__c, Profile_Data_1__c, Profile_Data_2__c, Include_Entire_Profile__c
                         FROM Build_Components__r
                         Order By Component_Name__c)
            From Build__c
            Where Release__c =: release.Id
        ];

        System.assertEquals(1, builds.size(), 'There should only be one build record created.');

        Build__c actualBuild = builds[0];

        System.assertEquals(1, actualBuild.Build_Components__r.size(), 'A build component should be created for the documented profile.');

        Build_Component__c actualBuildComponent = actualBuild.Build_Components__r[0];

        System.assertEquals(documentedProfileComponent.Id, actualBuildComponent.Backlog_Component__c, 'The component lookup should be set');
        System.assertEquals(instance.Name, actualBuildComponent.Instance_Name__c, 'The instance name should be set');
        System.assertEquals(AssemblerManifestRecord.DOCUMENTED, actualBuildComponent.Type__c, 'The build component type should be documented');

        System.assertEquals(true, actualBuildComponent.Is_Profile__c, 'Only profile components should be marked as profiles');
        System.assertEquals(true, actualBuildComponent.Include_Documented_Components__c, 'Include documented profiles should be true by default');
        System.assertEquals(false, actualBuildComponent.Include_Entire_Profile__c, 'The include entire profile flag should not be set');

        ProfilePermissions savedPermission = ProfilePermissions.valueOf(actualBuildComponent);

        System.assertEquals(expectedPermission.sections.size(), savedPermission.sections.size(), 'The profile selections should be saved on the build component');
        System.assertEquals(expectedPermission.sections[0].apiName, savedPermission.sections[0].apiName, 'The profile selections should be saved on the build component');
        System.assertEquals(expectedPermission.sections[0].permissions.size(), savedPermission.sections[0].permissions.size(), 'The profile selections should be saved on the build component');
        System.assertEquals(expectedPermission.sections[0].permissions[0], savedPermission.sections[0].permissions[0], 'The profile selections should be saved on the build component');
    }

    static testMethod void saveComponents_removedComponents_updateProfileData() {
        setup();
        setupDocumentedComponent();

        Backlog_Component__c documentedProfileComponent = TestingUtils.createDocumentedProfile(backlog.Id, 'profile 1', instance.Id);

        Component__c removedComponent = TestingUtils.createComponent('zzRemoveMe', ComponentServices.OBJECT_ALM_NAME, instance.Id);
        Backlog_Component__c removedBacklogComponent = TestingUtils.buildDocumentedComponent(backlog.Id, removedComponent, instance.Id);
        insert removedBacklogComponent;

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Build_Component__c documentedBuildComponent = (new AssemblerManifestRecord(backlogComponent)).getBuildComponent();
        documentedBuildComponent.Build__c = build.Id;

        Build_Component__c buildComponentToRemove = (new AssemblerManifestRecord(removedBacklogComponent)).getBuildComponent();
        buildComponentToRemove.Build__c = build.Id;


        Boolean includeEntireProfile = false;
        Boolean includeOnlyDocumentedComponents = true;
        ProfilePermissions selectedPermissions = new ProfilePermissions();

        String documentedSectionName = ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(component.Type__c);
        String removedComponentSectionName = ProfileServices.COMPONENT_TYPE_TO_CATEGORY.get(removedComponent.Type__c);

        TestingUtils.buildProfilePermissionsSection(selectedPermissions, documentedSectionName, new List<String> {component.Name});
        TestingUtils.buildProfilePermissionsSection(selectedPermissions, removedComponentSectionName, new List<String> {removedComponent.Name});

        Build_Component__c profileBuildComponent = TestingUtils.buildProfileBuildComponent(build.Id,
            documentedProfileComponent, selectedPermissions, includeEntireProfile, includeOnlyDocumentedComponents);

        insert new List<Build_Component__c> { documentedBuildComponent, buildComponentToRemove, profileBuildComponent };

        Assembler assembler = new Assembler(release.Id, build);
        assembler.loadManifest();

        Test.startTest();
            AssemblerManifestRecord recordToRemove = (assembler.manifest[0].getName() == removedComponent.Name)
                ? assembler.manifest[0] : assembler.manifest[1];
            recordToRemove.isRemoved = true;
            assembler.pendingRemovals = recordToRemove.getKey();
            assembler.saveComponents();
        Test.stopTest();

        Build_Component__c savedProfileComponent = [SELECT Is_Profile__c, Backlog_Component__c, Component_Name__c,
             Component_Type__c, Instance_Name__c, Type__c, Include_Documented_Components__c, Profile_Data_1__c,
             Profile_Data_2__c, Include_Entire_Profile__c
            FROM Build_Component__c
            WHERE Id = :profileBuildComponent.Id];

        ProfilePermissions permissions = ProfilePermissions.valueOf( savedProfileComponent );
        System.assertEquals(2, permissions.sections.size(), 'the number of sections should be unchanged');

        Map<String, ProfilePermissions.Section> sectionMap = permissions.getSectionMap();

        System.assertEquals(true, sectionMap.containsKey(documentedSectionName), 'The documented section should be unchanged');
        System.assertEquals(1, sectionMap.get(documentedSectionName).permissions.size(), 'The documented section should be unchanged');
        System.assertEquals(component.Name, sectionMap.get(documentedSectionName).permissions[0], 'The documented section should be unchanged');

        System.assertEquals(true, sectionMap.containsKey(removedComponentSectionName), 'The section with the removed component should still exist');
        System.assertEquals(0, sectionMap.get(removedComponentSectionName).permissions.size(), 'The removed component should have its permission removed');
    }

    static testMethod void saveComponents_unappliedProfileChanges() {
        setup();

        setupBacklogItem();

        Component__c profileComponent = new Component__c(Name='x profile 1', Type__c='Profile');
        Component__c undocumentedProfile = new Component__c(Name='z undocumented profile 2', Type__c='Profile');
        insert new List<Component__c>{profileComponent, undocumentedProfile};

        Backlog_Component__c documentedProfileComponent = TestingUtils.createDocumentedProfile(backlog.Id, profileComponent, instance.Id);

        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();
        assembler.saveBuild();

        Test.startTest();

            assembler.undocumentedPermissions[0].selected = true;
            assembler.documentedPermissions[0].selected = false;

            assembler.saveComponents();

        Test.stopTest();

        List<Build__c> builds = [
            Select Id, ( SELECT Is_Profile__c, Backlog_Component__c, Component_Name__c, Component_Type__c, Instance_Name__c, Type__c
                         FROM Build_Components__r
                         Order By Component_Name__c)
            From Build__c
            Where Release__c =: release.Id
        ];

        System.assertEquals(1, builds[0].Build_Components__r.size(), 'Only applied profile changes should persist.');
        System.assertEquals(AssemblerManifestRecord.DOCUMENTED, builds[0].Build_Components__r[0].Type__c, 'Only applied profile changes should persist.');
    }

    static testMethod void saveComponents_existingBuild_deleteRemovedUndocumentedProfiles() {
        setup();

        setupBacklogItem();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Component__c documentedProfile = new Component__c(Name='x profile 1', Type__c='Profile');
        Component__c undocumentedProfile = new Component__c(Name='z undocumented profile 2', Type__c='Profile');
        insert new List<Component__c>{documentedProfile, undocumentedProfile};

        Backlog_Component__c documentedProfileComponent = TestingUtils.createDocumentedProfile(backlog.Id, documentedProfile, instance.Id);

        Build_Component__c documentedBuildComponent = (new ProfileManifestRecord(documentedProfileComponent)).getBuildComponent();
        documentedBuildComponent.Build__c = build.Id;

        Build_Component__c undocumentedBuildComponent =
            createUndocumentedManifestRecord(undocumentedProfile, instance.Name).getBuildComponent();
        undocumentedBuildComponent.Build__c = build.Id;
        undocumentedBuildComponent.Is_Profile__c = true;

        insert new List<Build_Component__c> { documentedBuildComponent, undocumentedBuildComponent };

        Assembler assemblerInstance = new Assembler(release.Id, build);
        assemblerInstance.loadManifest();

        Test.startTest();

            assemblerInstance.undocumentedPermissions[0].selected = false;
            assemblerInstance.documentedPermissions[0].selected = false;
            assemblerInstance.updateProfileSelection();

            assemblerInstance.saveComponents();

        Test.stopTest();

        List<Build_Component__c> buildComponents =  [
            SELECT Is_Profile__c, Backlog_Component__c, Component_Name__c, Component_Type__c, Instance_Name__c, Type__c
            FROM Build_Component__c
            WHERE Build__c = :build.Id
        ];

        System.assertEquals(1, buildComponents.size(), 'de-selected undocumented profile components should be deleted');
        System.assertEquals(documentedBuildComponent.Id, buildComponents[0].Id, 'The removed documented profile should not be deleted');
        System.assertEquals(AssemblerManifestRecord.Removed, buildComponents[0].Type__c, 'The removed documented profile should be marked as removed');
    }

    static testMethod void saveComponents_profiles_readdRemoved() {
        setup();
        setupDocumentedComponent();

        Component__c documentedProfile = new Component__c(Name='Test Documented Profile', Type__c='Profile');
        insert documentedProfile;

        Backlog_Component__c documentedProfileComponent = TestingUtils.createDocumentedProfile(backlog.Id, documentedProfile, instance.Id);

        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();

        assembler.documentedPermissions[0].selected = false;
        assembler.updateProfileSelection();

        assembler.saveBuild();
        assembler.saveComponents();

        Test.startTest();

            assembler = new Assembler(release.Id, assembler.build);
            assembler.loadManifest();

            assembler.documentedPermissions[0].selected = true;
            assembler.updateProfileSelection();

            assembler.saveComponents();

        Test.stopTest();

        Build_Component__c buildComponent = [
            SELECT Type__c
            FROM Build_Component__c
            WHERE Component__c =: documentedProfile.Id
        ];

        System.assertEquals(AssemblerManifestRecord.DOCUMENTED, buildComponent.Type__c, 'The removed profile should be re-added successfully.');
    }

    static testMethod void syncManifest_compAddedToRelease() {
        // Tests a release with a single backlog component VS a build
        // with no documented component
        setup();
        setupBacklogItem();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Assembler assemblerInstance = new Assembler(release.Id, build);

        System.assertEquals(0, assemblerInstance.manifest.size(), 'Manifest should be empty');

        Test.startTest();
            // Add a new documented component
            setupDocumentedComponent();
            assemblerInstance.syncManifest();
        Test.stopTest();

        System.assertEquals(1, assemblerInstance.manifest.size(), 'Manifest should have a documented component after sync');
    }

    static testMethod void syncManifest_overrideProfileChanges() {
        setup();
        setupBacklogItem();

        Component__c documentedProfile = TestingUtils.createComponent('x profile 1', 'Profile', instance.Id);
        Backlog_Component__c documentedProfileComponent = TestingUtils.createDocumentedProfile(backlog.Id, documentedProfile, instance.Id);

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Assembler assemblerInstance = new Assembler(release.Id, build);
        assemblerInstance.loadManifest();

        Test.startTest();
            documentedProfileComponent.Include_Entire_Profile__c = true;
            update documentedProfileComponent;

            // Add a new documented component to force manifest sync
            setupDocumentedComponent();
            assemblerInstance.syncManifest();
        Test.stopTest();

        System.assertEquals(true, assemblerInstance.documentedPermissions[0].includeEntireProfile, ' All profile attributes should be overridden upon sync');
    }

    /**
    * Tests that syncing the manifest after going through a rebuild flow, any newly documented
    * components will be synced
    */
    static testMethod void syncManifest_afterRebuild() {
        setup();
        setupBacklogItem();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Assembler assembler = new Assembler(release.Id, build);
        assembler.loadManifest();

        System.assertEquals(0, assembler.manifest.size(), 'Manifest should be empty');

        Test.startTest();
            // Add a new documented component
            setupDocumentedComponent();
            assembler.syncManifest();
        Test.stopTest();

        System.assertEquals(1, assembler.manifest.size(), 'Manifest should have a documented component after sync');
        System.assertEquals(backlogComponent.Id, assembler.manifest[0].getBuildComponent().Backlog_Component__c, 'Manifest should have a documented component after sync');
    }

    static testMethod void syncManifest_rebuild_addProfiles() {
        setup();
        setupBacklogItem();

        // Create a previous build to prompt the rebuild flow.
        Build__c testBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        String testProfileName = 'Test Profile';
        String otherTestProfileName = 'Other Test Profile';

        Component__c testDocumentedProfileComponent = TestingUtils.createUndocumentedComponent(testProfileName, 'Profile', instance.Id, envData1);
        Component__c testUndocumentedProfileComponent = TestingUtils.createUndocumentedComponent(otherTestProfileName, 'Profile', instance.Id, envData1);

        TestingUtils.createDocumentedProfile(backlog.Id, testDocumentedProfileComponent, instance.Id);

        Test.startTest();

            Assembler testAssembler = new Assembler(release.Id, testBuild);
            testAssembler.syncManifest();

        Test.stopTest();

        System.assertEquals(1, testAssembler.selectedPermissions.size(), 'The proper number of selected permissions should exist.');
        System.assertEquals(testProfileName, testAssembler.selectedPermissions[0].profileName, 'The selected permission name should match.');
        System.assertEquals(1, testAssembler.documentedPermissions.size(), 'The proper number of selected permissions should exist.');
        System.assertEquals(testProfileName, testAssembler.documentedPermissions[0].profileName, 'The documented permission name should match.');
        System.assertEquals(1, testAssembler.undocumentedPermissions.size(), 'The proper number of undocumented permissions should exist.');
        System.assertEquals(otherTestProfileName, testAssembler.undocumentedPermissions[0].profileName, 'The undocumented permission name should match.');
    }

    static testMethod void syncManifest_rebuild_swapProfiles() {
        setup();
        setupBacklogItem();

        String testInitialProfileName = 'Test Initial Profile';
        String testNewProfileName = 'Test New Profile';

        Component__c testInitialProfileComponent = TestingUtils.createUndocumentedComponent(testInitialProfileName, 'Profile', instance.Id, envData1);
        Component__c testNewProfileComponent = TestingUtils.createUndocumentedComponent(testNewProfileName, 'Profile', instance.Id, envData1);

        Backlog_Component__c testInitialProfileBacklogComponent = TestingUtils.createDocumentedProfile(backlog.Id, testInitialProfileComponent, instance.Id);

        Assembler testAssembler = setupDeployedAssembler(release, BuildServices.STATUS_SUCCESS);

        Test.startTest();

            delete testInitialProfileBacklogComponent;
            TestingUtils.createDocumentedProfile(backlog.Id, testNewProfileComponent, instance.Id);

            Build__c initialBuild = BuildServices.getBuild(testAssembler.buildId);
            testAssembler = new Assembler(release.Id, initialBuild);
            testAssembler.syncManifest();

        Test.stopTest();

        System.assertEquals(1, testAssembler.documentedPermissions.size(), 'The proper number of documented permissions should exist.');
        System.assertEquals(testNewProfileName, testAssembler.documentedPermissions[0].profileName, 'The documented profile name should match.');
        System.assertEquals(1, testAssembler.undocumentedPermissions.size(), 'The proper number of undocumented permissions should exist.');
        System.assertEquals(testInitialProfileName, testAssembler.undocumentedPermissions[0].profileName, 'The undocumented profile name should match.');
    }

    static testMethod void syncManifest_convertUndocComponentToDocumentedComp() {
        // Tests a release with a single backlog component VS a build
        // with no documented component
        setup();
        setupBacklogItem();
        setupComponent();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        // Add undocumented build component
        Build_Component__c undocumentedBuildComp = TestingUtils.createUndocumentedBuildComponent(component, build.Id, instance.Name);

        Assembler assemblerInstance = new Assembler(release.Id, build);
        assemblerInstance.loadManifest();


        System.assertEquals(1, assemblerInstance.getTotalManifest().size(), 'Manifest should have 1 build component');
        System.assertEquals(true, assemblerInstance.getTotalManifest()[0].getIsUndocumented(), 'The component should be undocumented');

        Test.startTest();
            // Add a new documented component
            setupBacklogComponent();
            assemblerInstance.syncManifest();
        Test.stopTest();

        System.assertEquals(1, assemblerInstance.getTotalManifest().size(), 'Manifest should have 1 build component');
        System.assertEquals(true, assemblerInstance.getTotalManifest()[0].getIsDocumented(), 'The component should be a documented build component');
    }

    static testMethod void syncManifest_removeDocumentedComponent() {
        // Tests a release with a single backlog component VS a build
        // with no documented component
        setup();
        setupBacklogItem();
        setupDocumentedComponent();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        // Add documented build component
        Build_Component__c documentedBuildComp = TestingUtils.createDocumentedBuildComponent(backlogComponent, build.Id, instance.Name);

        Assembler assemblerInstance = new Assembler(release.Id, build);
        assemblerInstance.loadManifest();

        System.assertEquals(1, assemblerInstance.getTotalManifest().size(), 'Manifest should have 1 build component');
        System.assertEquals(true, assemblerInstance.getTotalManifest()[0].getIsDocumented(), 'The component should be documented');

        Test.startTest();
            // Remove documented release component and sync
            backlog.Release__c = null;
            update backlog;
            assemblerInstance.syncManifest();
        Test.stopTest();

        System.assertEquals(0, assemblerInstance.getTotalManifest().size(), 'Manifest should have no components');
    }

    static testMethod void syncManifest_duplicateComponents() {
        setup();
        setupDocumentedComponent();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        Build_Component__c documentedBuildComp0 = TestingUtils.createDocumentedBuildComponent(backlogComponent, build.Id, instance.Name);
        Build_Component__c documentedBuildComp1 = TestingUtils.createDocumentedBuildComponent(backlogComponent, build.Id, instance.Name);

        Assembler assemblerInstance = new Assembler(release.Id, build);
        assemblerInstance.loadManifest();

        Test.startTest();
            try {
                backlog.Release__c = null;
                update backlog;
                assemblerInstance.syncManifest();
            } catch (Exception e) {
                System.assert(false, 'An exception should not be thrown.');
            }
        Test.stopTest();

        System.assertEquals(0, assemblerInstance.getTotalManifest().size(), 'Manifest should have 0 build components.');
    }

    static testMethod void syncManifest_buildComponentHasDeletedBacklogComponent() {
        String testDocumentedComponentName = 'Test Documented Component Name';
        String testUndocumentedComponentName = 'Test Undocumented Component Name';

        setup();
        setupDocumentedComponent();

        Component__c testDocumentedComponent = new Component__c(Name = testDocumentedComponentName, Source_Instances__c = instance.Name);
        Component__c testUndocumentedComponent = TestingUtils.createUndocumentedComponent(testUndocumentedComponentName, 'Test Type', instance.Id, envData1);
        testUndocumentedComponent.Source_Instances__c = instance.Name;
        upsert new List<Component__c>{testDocumentedComponent, testUndocumentedComponent};

        Backlog_Component__c testBacklogComponent = new Backlog_Component__c(Backlog__c = backlog.Id, Component__c = testDocumentedComponent.Id, Source_Instance__c = instance.Id);
        insert testBacklogComponent;

        Backlog__c actualBacklogItem = [SELECT Name FROM Backlog__c WHERE Id = :backlog.Id];
        String expectedDocumentedKey = instance.Name + '|' + testDocumentedComponent.Id + '|' + actualBacklogItem.Name;
        String expectedUndocumentedKey = instance.Name + '|' + testUndocumentedComponent.Id;

        Assembler assemblerInstance = new Assembler(release.Id);

        assemblerInstance.loadManifest();

        assemblerInstance.selectedComponentIdString = expectedUndocumentedKey;
        assemblerInstance.addUndocumentedComponents();

        delete backlogComponent;

        Test.startTest();

            try {
                assemblerInstance.syncManifest();
            } catch (Exception e) {
                System.assert(false, 'An exception should not be thrown.');
            }

        Test.stopTest();

        System.assertEquals(2, assemblerInstance.getTotalManifest().size(), 'The manifest should have the proper number of build components.');

        Set<String> actualKeys = new Set<String>();
        for (AssemblerManifestRecord record : assemblerInstance.getTotalManifest()) {
            actualKeys.add(record.getDocumentedKey());
        }
        System.assert(actualKeys.contains(expectedDocumentedKey), 'The proper documented component should remain.');
        System.assert(actualKeys.contains(expectedUndocumentedKey), 'The undocumented component should remain.');
    }

    static testMethod void syncManifest_manuallyDeployed() {
        setup();
        setupDocumentedComponent();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        Build_Component__c documentedBuildComp = TestingUtils.createDocumentedBuildComponent(backlogComponent, build.Id, instance.Name);

        Assembler assemblerInstance = new Assembler(release.Id, build);

        backlogComponent.Deploy_Manually__c = true;
        update backlogComponent;

        Test.startTest();
            assemblerInstance.syncManifest();
        Test.stopTest();

        Build_Component__c syncedBuildComponent = [SELECT ID, Type__c, Is_Manual_Deployment__c FROM Build_Component__c WHERE Id = :documentedBuildComp.Id];

        System.assertEquals(true, syncedBuildComponent.Is_Manual_Deployment__c, 'The synced build component should be updated as deploy manually');
        System.assertEquals(AssemblerManifestRecord.REMOVED, syncedBuildComponent.Type__c, 'The synced build component should be marked as removed');
    }

    static testMethod void isManifestChanged_noCompletedBuild() {
        setup();
        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Assembler assembler = new Assembler(release.Id, build);

        Test.startTest();

            Boolean isChangedResult = assembler.isManifestChanged(null);

        Test.stopTest();

        System.assertEquals(false, isChangedResult, 'When there is no completed build, the assembler should report no changes');
    }

    static testMethod void isManifestChanged_addedComponent() {
        setup();
        setupDocumentedComponent();

        Build__c completedBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        TestingUtils.createDocumentedBuildComponent(backlogComponent, completedBuild.Id, instance.Name);

        Component__c undocumentedComponent = TestingUtils.createUndocumentedComponent('undocumented', 'Field', instance.Id, envData1);
        Assembler assembler = new Assembler(release.Id, completedBuild);

        Test.startTest();

            assembler.selectedComponentIdString = createUndocumentedManifestRecord(undocumentedComponent, instance.Name).getKey();
            assembler.addUndocumentedComponents();
            Boolean isChangedResult = assembler.isManifestChanged(completedBuild.Id);

        Test.stopTest();

        System.assertEquals(true, isChangedResult, 'When an undocumented component is added, the manifest should be marked as changed.');
    }

    static testMethod void isManifestChanged_removedComponent() {
        setup();
        setupDocumentedComponent();

        Build__c completedBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);
        TestingUtils.createDocumentedBuildComponent(backlogComponent, completedBuild.Id, instance.Name);


        Assembler assembler = new Assembler(release.Id, completedBuild);
        Test.startTest();

            assembler.manifest[0].isRemoved = true;
            Boolean isChangedResult = assembler.isManifestChanged(completedBuild.Id);

        Test.stopTest();
        System.assertEquals(true, isChangedResult, 'When a component is removed, the manifest should be marked as changed.');
    }

    static testMethod void isManifestChanged_removeDocumentedProfile() {
        setup();
        setupBacklogItem();

        Build__c completedBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Component__c profile = new Component__c(Name='profile 1', Type__c='Profile');
        insert profile;

        Backlog_Component__c documentedProfile = TestingUtils.createDocumentedProfile(backlog.Id, profile, instance.Id);

        Build_Component__c profileBuildComponent = (new ProfileManifestRecord(documentedProfile)).getBuildComponent();
        profileBuildComponent.Build__c = completedBuild.Id;
        insert profileBuildComponent;

        Assembler assembler = new Assembler(release.Id, completedBuild);
        Test.startTest();

            assembler.documentedPermissions[0].selected = false;
            assembler.updateProfileSelection();
            Boolean isChangedResult = assembler.isManifestChanged(completedBuild.Id);

        Test.stopTest();
        System.assertEquals(true, isChangedResult, 'When a profile component is removed, the manifest should be marked as changed.');
    }

    static testMethod void isManifestChanged_removeUnDocumentedProfile() {
        setup();
        setupBacklogItem();

        Build__c completedBuild = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        Component__c profile = new Component__c(Name='profile 1', Type__c='Profile');
        insert profile;

        Build_Component__c profileBuildComponent = (new ProfileManifestRecord(profile)).getBuildComponent();
        profileBuildComponent.Build__c = completedBuild.Id;
        insert profileBuildComponent;

        Assembler assembler = new Assembler(release.Id, completedBuild);
        Test.startTest();

            assembler.undocumentedPermissions[0].selected = false;
            assembler.updateProfileSelection();
            Boolean isChangedResult = assembler.isManifestChanged(completedBuild.Id);

        Test.stopTest();
        System.assertEquals(true, isChangedResult, 'When an undocumented profile component is removed, the manifest should be marked as changed.');
    }

    static void assertAssemblerManifestRecordCloned(AssemblerManifestRecord original, AssemblerManifestRecord cloned){
        System.assertEquals(null, cloned.getBuildComponent().Id, 'A new Build Component should be created and not inserted.');
        System.assertEquals(null, cloned.getBuildComponent().Build__c, 'The Build Component build lookup should be cleared out.');
        System.assertEquals(original.getBuildComponent().Backlog_Component__c, cloned.getBuildComponent().Backlog_Component__c,
          'The backlog component id property should have the same value.');
        System.assertEquals(original.backlogStatus, cloned.backlogStatus,
          'The backlogStatus property should have the same value.');
        System.assertEquals(original.instance, cloned.instance,
          'The instance property should have the same value.');
        System.assertEquals(original.notes, cloned.notes,
          'The notes property should have the same value.');
        System.assertEquals(original.getName(), cloned.getName(),
          'The name property should have the same value.');
        System.assertEquals(original.getType(), cloned.getType(),
          'The type property should have the same value.');
        System.assertEquals(original.getParent(), cloned.getParent(),
          'The parent property should have the same value.');
        System.assertEquals(original.selected, cloned.selected,
          'The selected property should have the same value.');
        System.assertEquals(original.isRemoved, cloned.isRemoved,
          'The isRemoved property should have the same value.');
    }

    static void assertProfileManifestRecordCloned(ProfileManifestRecord original, ProfileManifestRecord cloned){
        assertAssemblerManifestRecordCloned(original, cloned);
        System.assertEquals(original.profileName, cloned.profileName,
          'The profileName property should have the same value.');
    }

    static testMethod void cloneManifest(){

        setup();
        setupDocumentedComponent();

        Component__c undocumentedComponent = TestingUtils.createUndocumentedComponent('Test field 2', 'Field', instance.Id, envData1);

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);

        Build_Component__c documentedBuildComponent = (new AssemblerManifestRecord(backlogComponent)).getBuildComponent();
        documentedBuildComponent.Build__c = build.Id;

        Build_Component__c undocumentedBuildComponent =
            createUndocumentedManifestRecord(undocumentedComponent, instance.Name).getBuildComponent();
        undocumentedBuildComponent.Build__c = build.Id;

        insert new List<Build_Component__c> { documentedBuildComponent, undocumentedBuildComponent };


        Component__c documentedProfile = new Component__c(Name='x profile 1', Type__c='Profile');
        Component__c undocumentedProfile = new Component__c(Name='z undocumented profile 2', Type__c='Profile');
        insert new List<Component__c>{documentedProfile, undocumentedProfile};

        Backlog_Component__c documentedProfileComponent = TestingUtils.createDocumentedProfile(backlog.Id, documentedProfile, instance.Id);

        Build_Component__c documentedProfileBuildComponent = (new ProfileManifestRecord(documentedProfileComponent)).getBuildComponent();
        documentedProfileBuildComponent.Build__c = build.Id;

        Build_Component__c undocumentedProfileBuildComponent =
            createUndocumentedManifestRecord(undocumentedProfile, instance.Name).getBuildComponent();
        undocumentedProfileBuildComponent.Build__c = build.Id;
        undocumentedProfileBuildComponent.Is_Profile__c = true;

        insert new List<Build_Component__c> { documentedProfileBuildComponent, undocumentedProfileBuildComponent };

        Assembler ass = new Assembler(release.Id, build);
        ass.loadManifest();

        List<AssemblerManifestRecord> manifestClone = ass.manifest.clone();
        List<AssemblerManifestRecord> undocumentedComponentsClone = ass.undocumentedComponents.clone();
        List<AssemblerManifestRecord> filteredManifestClone = ass.filteredManifest.clone(); // populated by loadManifest

        List<ProfileManifestRecord> documentedPermissionsClone = ass.documentedPermissions.clone();
        List<ProfileManifestRecord> undocumentedPermissionsClone = ass.undocumentedPermissions.clone();
        List<ProfileManifestRecord> selectedPermissionsClone = ass.selectedPermissions.clone();

        Test.startTest();
            ass.cloneManifest();
        Test.stopTest();

        System.assertEquals(null, ass.buildId, 'The Build should be cleared out.');
        System.assertEquals(manifestClone.size(), ass.manifest.size(),
                'All documented build components should be cloned. ');
        System.assertEquals(undocumentedComponentsClone.size(), ass.undocumentedComponents.size(),
                'All undocumented build components should be cloned.');
        System.assertEquals(filteredManifestClone.size(), ass.filteredManifest.size(),
                'All filtered manifest build components should be cloned.');
        System.assertEquals(0, ass.removedBuildComps.size(),
                'All build components in removedBuildComps should be removed from the list.');

        System.assertEquals(documentedPermissionsClone.size(), ass.documentedPermissions.size(),
                'All documentedPermissions components should be cloned. ');
        System.assertEquals(undocumentedPermissionsClone.size(), ass.undocumentedPermissions.size(),
                'All undocumentedPermissions components should be cloned.');
        System.assertEquals(selectedPermissionsClone.size(), ass.selectedPermissions.size(),
                'All selectedPermissions components should be cloned.');

        for ( Integer i = 0; i < manifestClone.size(); i++){
            assertAssemblerManifestRecordCloned(manifestClone[i], ass.manifest[i]);
        }
        for ( Integer i = 0; i < undocumentedComponentsClone.size(); i++){
            assertAssemblerManifestRecordCloned(undocumentedComponentsClone[i], ass.undocumentedComponents[i]);
        }
        for ( Integer i = 0; i < filteredManifestClone.size(); i++){
            assertAssemblerManifestRecordCloned(filteredManifestClone[i], ass.filteredManifest[i]);
        }

        for ( Integer i = 0; i < documentedPermissionsClone.size(); i++){
            assertProfileManifestRecordCloned(documentedPermissionsClone[i], ass.documentedPermissions[i]);
        }
        for ( Integer i = 0; i < undocumentedPermissionsClone.size(); i++){
            assertProfileManifestRecordCloned(undocumentedPermissionsClone[i], ass.undocumentedPermissions[i]);
        }
        for ( Integer i = 0; i < selectedPermissionsClone.size(); i++){
            assertProfileManifestRecordCloned(selectedPermissionsClone[i], ass.selectedPermissions[i]);
        }
    }

    static testMethod void cloneManifest_filteredContainsReferences() {
        setup();
        setupDocumentedComponent();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        Build_Component__c documentedBuildComponent = (new AssemblerManifestRecord(backlogComponent)).getBuildComponent();
        documentedBuildComponent.Build__c = build.Id;
        insert documentedBuildComponent;

        Assembler testAssembler = new Assembler(release.Id, build);
        testAssembler.loadManifest();

        Test.startTest();

            testAssembler.cloneManifest();

        Test.stopTest();

        Build_Component__c expectedBuildComponent = testAssembler.manifest[0].getBuildComponent();

        System.assert(expectedBuildComponent === testAssembler.filteredManifest[0].getBuildComponent(),
                'The filtered manifest should contain direct references to elements in the unfiltered manifest.');
    }

    static testMethod void cloneManifest_noFilters_includesDeletedBacklogComponents() {
        setup();
        setupDocumentedComponent();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_NOT_STARTED);
        Build_Component__c documentedBuildComponent = (new AssemblerManifestRecord(backlogComponent)).getBuildComponent();
        documentedBuildComponent.Build__c = build.Id;
        insert documentedBuildComponent;

        delete backlogComponent;

        Assembler testAssembler = new Assembler(release.Id, build);
        testAssembler.loadManifest();

         Test.startTest();

            testAssembler.cloneManifest();

        Test.stopTest();

        System.assertEquals(1, testAssembler.filteredManifest.size(),
            'The build component for the deleted backlog component should be included when there are no filters');
        
        Build_Component__c expectedBuildComponent = testAssembler.manifest[0].getBuildComponent();
        System.assert(expectedBuildComponent === testAssembler.filteredManifest[0].getBuildComponent(),
            'The filtered manifest should contain direct references to elements in the unfiltered manifest.');
    }

    static void buildManifest(Integer undocumentedSize, Integer filteredSize, Id buildId) {
        // Create components and undocumented build components.
        List<Component__c> components = new List<Component__c>();
        List<Build_Component__c> buildComponents = new List<Build_Component__c>();
        for (Integer i = 0; i < undocumentedSize; ++i) {
            component = new Component__c(Name='TestUndocumentedComponent' + i, Type__c='Undocumented Type');
            buildComponents.add(TestingUtils.buildUndocumentedBuildComponent(component, buildId, instance.Name));
        }
        for (Integer i = 0; i < filteredSize; ++i) {
            component = new Component__c(Name='TestDocumentedComponent' + i, Type__c='Documented Type');
            components.add(component);
        }
        insert components;

        // Create documented build components.
        components = [SELECT Name, Type__c, Parent_Component__r.Name FROM Component__c WHERE Type__c='Documented Type'];
        for (Integer i = 0; i < components.size(); ++i) {
            backlogComponent = new Backlog_Component__c(Backlog__c=backlog.Id, Component__c=components.get(i).Id, Source_Instance__c=instance.Id);
            buildComponents.add(TestingUtils.buildDocumentedBuildComponent(component, buildId, instance.Name));
        }
        insert buildComponents;
    }

    static void chunkManifest(Integer undocumentedSize, Integer filteredSize, Integer chunkSize) {
        setup();
        setupBacklogItem();

        Build__c build = TestingUtils.createBuild(release.Id, BuildServices.STATUS_SUCCESS);

        buildManifest(undocumentedSize, filteredSize, build.Id);

        // Get the chunked components.
        Test.startTest();
            Assembler testAssembler = new Assembler(release.Id, build);
            testAssembler.loadManifest();
            List<List<AssemblerManifestRecord>> chunkedUndocumentedComponents = testAssembler.chunkList(testAssembler.undocumentedComponents, chunkSize);
            List<List<AssemblerManifestRecord>> chunkedFilteredManifest = testAssembler.chunkList(testAssembler.filteredManifest, chunkSize);
        Test.stopTest();

        // Assert that the chunked lists are the proper size.
        Integer chunkedUndocumentedComponentsSize = 0;
        for (Integer i = 0; i < chunkedUndocumentedComponents.size(); ++i) {
            chunkedUndocumentedComponentsSize += chunkedUndocumentedComponents.get(i).size();
        }
        Integer chunkedFilteredManifestSize = 0;
        for (Integer i = 0; i < chunkedFilteredManifest.size(); ++i) {
            chunkedFilteredManifestSize += chunkedFilteredManifest.get(i).size();
        }
        System.assertEquals(testAssembler.undocumentedComponents.size(), chunkedUndocumentedComponentsSize, 'The undocumented components chunked list should be the correct size.');
        System.assertEquals(testAssembler.filteredManifest.size(), chunkedFilteredManifestSize, 'The filtered manifest chunked list should be the correct size.');

        // Assert that the chunked lists are properly-chunked version of their respective unchunked counterparts.
        for (Integer i = 0; i < chunkedUndocumentedComponents.size(); ++i) {
            for (Integer j = 0; j < chunkedUndocumentedComponents.get(i).size(); ++j) {
                System.assertEquals(chunkedUndocumentedComponents.get(i).get(j).getName(), testAssembler.undocumentedComponents[(i * chunkSize) + j].getName(), 'The undocumented component names should match.');
            }
        }
        for (Integer i = 0; i < chunkedFilteredManifest.size(); ++i) {
            for (Integer j = 0; j < chunkedFilteredManifest.get(i).size(); ++j) {
                System.assertEquals(chunkedFilteredManifest.get(i).get(j).getName(), testAssembler.filteredManifest[(i * chunkSize) + j].getName(), 'The filtered manifest backlog component names should match.');
            }
        }
    }

    static testMethod void getFilteredManifests() {
        setup();
        setupDocumentedComponent();

        Component__c undocumentedDestructiveComponent = new Component__c(
            Name = 'Test Undocumented Destructive Component',
            Instance__c = instance.Id,
            Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{
                new FieldModifiedData(instance.Name, Datetime.now().addDays(-1), null, null, null, true)
            })
        );
        insert new List<Component__c>{undocumentedDestructiveComponent};

        Backlog_Component__c manuallyDeployedBacklogComponent = new Backlog_Component__c(Backlog__c = backlog.Id,
                             Component__c = component.Id, Source_Instance__c = instance.Id, Deploy_Manually__c = true);
        Backlog_Component__c destructiveDeployedBacklogComponent = new Backlog_Component__c(Backlog__c = backlog.Id,
                             Component__c = component.Id, Source_Instance__c = instance.Id, Deleted__c = true);
        Backlog_Component__c destructiveManuallyDeployedBacklogComponent = new Backlog_Component__c(Backlog__c = backlog.Id,
                             Component__c = component.Id, Source_Instance__c = instance.Id, Deploy_Manually__c = true, Deleted__c = true);
        insert new List<Backlog_Component__c>{manuallyDeployedBacklogComponent, destructiveDeployedBacklogComponent, destructiveManuallyDeployedBacklogComponent};

        Assembler assembler = new Assembler(release.Id);
        assembler.loadManifest();
        assembler.selectedComponentIdString = instance.Name + '|' + component.Id + ',' + instance.Name + '|' + undocumentedDestructiveComponent.Id;
        assembler.addUndocumentedComponents();

        Test.startTest();

            List<List<AssemblerManifestRecord>> undocumentedComponents = assembler.getChunkedUndocumentedComponents();
            List<List<AssemblerManifestRecord>> undocumentedDestructiveComponents = assembler.getChunkedUndocumentedDestructiveComponents();
            List<List<AssemblerManifestRecord>> normallyDeployedComponents = assembler.getChunkedDocumentedComponents();
            List<List<AssemblerManifestRecord>> manuallyDeployedComponents = assembler.getChunkedDocumentedManualComponents();
            List<List<AssemblerManifestRecord>> destructiveDeployedComponents = assembler.getChunkedDocumentedDestructiveComponents();
            List<List<AssemblerManifestRecord>> destructiveManualDeployedComponents = assembler.getChunkedDocumentedDestructiveManualComponents();

        Test.stopTest();

        System.assertEquals(4, assembler.filteredManifest.size(), 'The Assembler Manifest should have the proper number of documented components');
        System.assertEquals(2, assembler.undocumentedComponents.size(), 'The Assembler Manifest should have the proper number of undocumented components');

        System.assertEquals(1, undocumentedComponents.size(),
                            'The manifest record should only have one component list');
        System.assertEquals(1, undocumentedComponents[0].size(),
                            'The first manifest record should only have one component');
        System.assert(!undocumentedComponents[0][0].deployManually,
                      'The Assembler Manifest Record should be not set to deploy manually');
        System.assert(!undocumentedComponents[0][0].isDeletion,
                      'The Assembler Manifest Record should not be set as a destructive change');

        System.assertEquals(1, undocumentedDestructiveComponents.size(),
                            'The manifest record should only have one component list');
        System.assertEquals(1, undocumentedDestructiveComponents[0].size(),
                            'The first manifest record should only have one component');
        System.assert(!undocumentedDestructiveComponents[0][0].deployManually,
                      'The Assembler Manifest Record should be not set to deploy manually');
        System.assert(undocumentedDestructiveComponents[0][0].isDeletion,
                      'The Assembler Manifest Record should be set as a destructive change');

        System.assertEquals(1, manuallyDeployedComponents.size(),
                            'The manifest record should only have one backlog component list');
        System.assertEquals(1, manuallyDeployedComponents[0].size(),
                            'The first manifest record should only have one backlog component');
        System.assert(manuallyDeployedComponents[0][0].deployManually,
                      'The Assembler Manifest Record should be set to deploy manually');
        System.assert(!manuallyDeployedComponents[0][0].isDeletion,
                      'The Assembler Manifest Record should not be set as a destructive change');

        System.assertEquals(1, normallyDeployedComponents.size(),
                            'The manifest record should only have one backlog component list');
        System.assertEquals(1, normallyDeployedComponents[0].size(),
                            'The first manifest record should only have one backlog component');
        System.assert(!normallyDeployedComponents[0][0].deployManually,
                      'The Assembler Manifest Record from a non-manually ' +
                      'deployed component should not be set to deploy manually');
        System.assert(!normallyDeployedComponents[0][0].isDeletion,
                      'The Assembler Manifest Record from a non-manually ' +
                      'deployed component should not not be set as a destructive change');

        System.assertEquals(1, destructiveDeployedComponents.size(),
                            'The manifest record should only have one backlog component list');
        System.assertEquals(1, destructiveDeployedComponents[0].size(),
                            'The first manifest record should only have one backlog component');
        System.assert(!destructiveDeployedComponents[0][0].deployManually,
                      'The Assembler Manifest Record should not be set to deploy manually');
        System.assert(destructiveDeployedComponents[0][0].isDeletion,
                      'The Assembler Manifest Record should be set as a destructive change');

        System.assertEquals(1, destructiveManualDeployedComponents.size(),
                            'The manifest record should only have one backlog component list');
        System.assertEquals(1, destructiveManualDeployedComponents[0].size(),
                            'The first manifest record should only have one backlog component');
        System.assert(destructiveManualDeployedComponents[0][0].deployManually,
                      'The Assembler Manifest Record should not be set to deploy manually');
        System.assert(destructiveManualDeployedComponents[0][0].isDeletion,
                      'The Assembler Manifest Record should be set as a destructive change');
    }

    static testMethod void retrieveAllAvailableTestClasses() {
        setup();
        setupDocumentedComponent();

        String testAssembler = 'TestAssembler';
        String testRevisions = 'TestRevisions';

        Component__c devTestComponent = TestingUtils.createTestApexComponent(testAssembler, instance);
        Backlog_Component__c backlogComponent = TestingUtils.buildDocumentedComponent(backlog.Id, devTestComponent, instance.Id);
        insert backlogComponent;

        Assembler assembler = new Assembler(release.Id);

        Instances__c targetInstance = new Instances__c(Name = 'targetInstance');
        insert targetInstance;

        Component__c testRevisionsComponent = TestingUtils.createTestApexComponent(testRevisions, targetInstance);
        TestingUtils.createComponent('RevisionServices', ComponentServices.APEX_ALM_NAME, targetInstance.Id);

        Test.startTest();
            List<Component__c> testClasses = assembler.retrieveAllAvailableTestClasses();
        Test.stopTest();

        Map<Id, Component__c> testIdsToClasses = new Map<Id, Component__c>(testClasses);

        System.assertEquals(2, testIdsToClasses.keySet().size(), 'There should two test apex classes.');
        System.assert(testIdsToClasses.containsKey(devTestComponent.Id),
                        testAssembler + ' should exist in the results');
        System.assert(testIdsToClasses.containsKey(testRevisionsComponent.Id),
                        testRevisions + ' should exist in the results');
    }

    static testMethod void chunkManifest_emptyManifest() {
        chunkManifest(0, 0, 10);
    }

    static testMethod void chunkManifest_totalUnderChunkSize() {
        chunkManifest(5, 4, 10);
    }

    static testMethod void chunkManifest_totalEqualsChunkSize() {
        chunkManifest(5, 5, 10);
    }

    static testMethod void chunkManifest_totalOverChunkSize() {
        chunkManifest(5, 6, 10);
    }

    static testMethod void chunkManifest_undocumentedOverChunkSize() {
        chunkManifest(11, 5, 10);
    }

    static testMethod void chunkManifest_filteredOverChunkSize() {
        chunkManifest(5, 11, 10);
    }

    static testMethod void chunkManifest_bothOverChunkSize() {
        chunkManifest(11, 11, 10);
    }
}