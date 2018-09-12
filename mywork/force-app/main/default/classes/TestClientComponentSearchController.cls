@isTest
private class TestClientComponentSearchController {
    static ClientComponentSearchController controller;

    static ClientComponentSearchController.ComponentSearchResult
        doPageSearchWithEmptySearchParams(Integer pageNumber, Integer pageSize) {

        ClientComponentSearchController.SearchParameters searchParams =
            new ClientComponentSearchController.SearchParameters();
        searchParams.currentPage = pageNumber;
        searchParams.pageSize = pageSize;
        return ClientComponentSearchController.doPageSearch(JSON.serialize(searchParams));
    }

    static List<Component__c> createComps(Integer numComps, DateTime overallLastModifiedDate, String namePrefix,
                                          Id instanceId) {
        List<Component__c> comps = new List<Component__c>();
        for(Integer i = 0; i < numComps; i++){
            Component__c comp = TestingUtils.buildComponent(namePrefix + String.valueOf(i), 'testType', instanceId);
            comp.Overall_Last_Modified_Date__c = overallLastModifiedDate;
            comp.Instance__c = instanceId;
            comps.add(comp);
        }
        insert comps;
        return comps;
    }

    static testMethod void userRequestedPageSize_NoValueSet() {
        Test.startTest();
            controller = new ClientComponentSearchController();
        Test.stopTest();

        System.assertEquals(ClientComponentSearchController.defaultPageSize,
                              controller.userRequestedPageSize,
                                'When no user preferences are set, the page size should be ' + ClientComponentSearchController.defaultPageSize);
    }

    static testMethod void userRequestedPageSize_ValueSet() {
        Integer expectedSize = 50;

        User_Preferences__c preference = new User_Preferences__c();
        preference.SetupOwnerId = UserInfo.getUserId();
        preference.Comp_Search_Page_Size__c = expectedSize;

        insert preference;

        Test.startTest();
            controller = new ClientComponentSearchController();
        Test.stopTest();

        System.assertEquals(expectedSize, controller.userRequestedPageSize,
                                'The page size in the custom setting should be returned for the user.');
    }

    static testMethod void userRequestedPageSize_valueNotSetForUser() {
        User_Preferences__c preference = new User_Preferences__c();
        preference.SetupOwnerId = UserInfo.getUserId();
        insert preference;

        Test.startTest();
            controller = new ClientComponentSearchController();
        Test.stopTest();

        System.assertEquals(ClientComponentSearchController.defaultPageSize, controller.userRequestedPageSize,
                                'When a page size is not set for a user, the page size should be the default page size');
    }

    static testMethod void updateUserPreferences_Error() {
        User_Preferences__c preference = new User_Preferences__c();
        preference.SetupOwnerId = UserInfo.getUserId();
        preference.Comp_Search_Page_Size__c = 10;
        insert preference;

        Test.startTest();
            try {
              ClientComponentSearchController.updateUserPreferences(1000);
              System.assert(false, 'The expected exception was never thrown');
            } catch (ALMException e) {
                System.assert(true, 'An ALMException should be thrown when the custom setting fails to update.');
            }
        Test.stopTest();
    }

    static testMethod void updateUserPreferences_Valid() {
        User_Preferences__c preference = new User_Preferences__c();
        preference.SetupOwnerId = UserInfo.getUserId();
        preference.Comp_Search_Page_Size__c = 10;
        insert preference;

        controller = new ClientComponentSearchController();

        Integer expectedSize = 50;

        Test.startTest();
            try {
                ClientComponentSearchController.updateUserPreferences(expectedSize);
            } catch (ALMException e) {
                System.assert(false, 'An exception should not have been thrown.');
            }
        Test.stopTest();

        System.assertEquals(expectedSize, controller.userRequestedPageSize,
                                'The page size in the custom setting should have been updated.');
    }

    static testMethod void getSearchResults_noBacklogComponent() {
        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c component = TestingUtils.createComponent('Test trigger', 'Trigger', instance.Id);

        Test.startTest();

            ClientComponentSearchController.ComponentSearchResult searchResults
                = ClientComponentSearchController.getSearchResults(component.Name, component.Type__c, null, null, '', null);

        Test.stopTest();

         System.assertEquals(1, searchResults.results.size(), 'The component searched for should be returned');
         System.assertEquals(false, searchResults.results[0].checked, 'Components without backlog components should be marked as such.');
         System.assertEquals(false, searchResults.results[0].isUnsupportedType, 'The isunsupported flag should be accurately set.');
         System.assertEquals(false, searchResults.results[0].deployManually, 'the deploymanually flag should be accurately set.');
    }

    static testMethod void getSearchResults_noBacklogComponentUnsupportedTypes() {
        final String UNSUPPORTED_TYPE = 'Trigger';
        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c component = TestingUtils.createComponent('Test trigger', UNSUPPORTED_TYPE, instance.Id);

        UnsupportedMetadataTypes__c rec = new UnsupportedMetadataTypes__c();
        rec.Name = UNSUPPORTED_TYPE;
        rec.Name__c = UNSUPPORTED_TYPE;
        insert rec;

        Test.startTest();

            ClientComponentSearchController.ComponentSearchResult searchResults
                = ClientComponentSearchController.getSearchResults(component.Name, component.Type__c, null, null, '', null);

        Test.stopTest();

         System.assertEquals(1, searchResults.results.size(), 'The component searched for should be returned');
         System.assertEquals(false, searchResults.results[0].checked, 'Components without backlog components should be marked as such.');
         System.assertEquals(true, searchResults.results[0].isUnsupportedType, 'The isunsupported flag should be accurately set.');
         System.assertEquals(true, searchResults.results[0].deployManually, 'the deploymanually flag should be accurately set.');
    }

    static testMethod void getSearchResults_pageTwo() {

        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c component1 = TestingUtils.buildComponent('Test trigger', 'Trigger', instance.Id);
        Component__c component2 = TestingUtils.buildComponent('User', 'Trigger', instance.Id);

        FieldModifiedData lastModifiedData1 = new FieldModifiedData(instance.Name, Datetime.now(), null, null, 'somebody');
        FieldModifiedData lastModifiedData2 = new FieldModifiedData(instance.Name, Datetime.now().addDays(1), null, null, 'somebody');
        component1.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{lastModifiedData1});
        component2.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{lastModifiedData2});

        insert new List<Component__c> { component1, component2 };

        ClientComponentSearchController.SearchParameters searchParams
            = new ClientComponentSearchController.SearchParameters();
        searchParams.currentPage = 2;
        searchParams.pageSize = 1;

        Test.startTest();

            ClientComponentSearchController.ComponentSearchResult searchResults
                = ClientComponentSearchController.doPageSearch(JSON.serialize(searchParams));

        Test.stopTest();

         System.assertEquals(1, searchResults.results.size(),
             'The second page should be returned');
         System.assertEquals(component1.Id, searchResults.results[0].component.Id,
             'The second page should be returned');

    }

    static testMethod void getSearchResults_filterByUser() {
        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c componentNoUser = TestingUtils.createComponent('Test trigger', 'Trigger', instance.Id);
        Component__c componentWithUser = TestingUtils.buildComponent('User', 'Trigger', instance.Id);

        String USERNAME = 'Target User';

        FieldModifiedData lastModifiedData = new FieldModifiedData(instance.Name, null, USERNAME, null, 'somebody');
        componentWithUser.Last_Modified_Users__c = USERNAME;
        componentWithUser.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{lastModifiedData});
        insert componentWithUser;

        Test.startTest();

            ClientComponentSearchController.ComponentSearchResult searchResults
                = ClientComponentSearchController.getSearchResults(
                    null, componentNoUser.Type__c, null, null, '', new List<String>{USERNAME});

        Test.stopTest();

         System.assertEquals(1, searchResults.results.size(),
             'The component with matching last modified by user should be returned');
         System.assertEquals(componentWithUser.Id, searchResults.results[0].component.Id,
             'The component with matching last modified by user should be returned');
    }

    static testMethod void getCachedSearchResults_CacheIsOnlyCalledForFirstPageWithNoFilterCriteria() {
        ComponentDocServices.RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT = 5;
        Instances__c instance = TestingUtils.createInstance('testInstanceName');

        String cachedCompNamePrefix = 'cachedComps';
        String uncachedCompNamePrefix = 'uncachedComps';

        // Create components with old LAST_MODIFIED_DATEs and add them to the cache.
        // If they surface in a comp search for page 1, we'll know they're from the cache
        List<Component__c> cachedComps = createComps(5, DateTime.now().addDays(-10), cachedCompNamePrefix, instance.Id);
        Set<Id> cachedCompIds = (new Map<Id, SObject>(cachedComps)).keySet();
        ComponentDocServices.cacheRecentlyModifiedComponents(new List<Id>(cachedCompIds));

        List<Component__c> unCachedComps = createComps(10, DateTime.now().addDays(-1), uncachedCompNamePrefix, instance.Id);

        // Set up search params with filter criteria for a page one search
        ClientComponentSearchController.SearchParameters paramsWithFilter_page1 =
            new ClientComponentSearchController.SearchParameters();
        paramsWithFilter_page1.currentPage = 1;
        paramsWithFilter_page1.pageSize = 5;
        paramsWithFilter_page1.instances = instance.name;

        Test.startTest();
            List<ComponentSearchWrapper> resultsPage1_withParams =
                           ClientComponentSearchController.doPageSearch(JSON.serialize(paramsWithFilter_page1)).results;
            List<ComponentSearchWrapper> resultsPage1_noParams = doPageSearchWithEmptySearchParams(1, 5).results;
            List<ComponentSearchWrapper> resultsPage2_noParams = doPageSearchWithEmptySearchParams(2, 5).results;
        Test.stopTest();

        System.assertEquals(5, resultsPage1_withParams.size(),
                            'The correct number of results should be returned for resultsPage1_noParams');
        System.assertEquals(5, resultsPage1_noParams.size(),
                            'The correct number of results should be returned for resultsPage1_noParams');
        System.assertEquals(5, resultsPage2_noParams.size(),
                            'The correct number of results should be returned for resultsPage2_noParams');


        for(ComponentSearchWrapper wrapper : resultsPage1_withParams) {
            System.assert(wrapper.component.name.startsWith(uncachedCompNamePrefix),
                          'Searches with params should BYPASS the Recently Modified Components cache');
        }

        for(ComponentSearchWrapper wrapper : resultsPage2_noParams) {
            System.assert(wrapper.component.name.startsWith(uncachedCompNamePrefix),
                          'Searches with no params should BYPASS the Recently Modified Components cache');
        }

        for(ComponentSearchWrapper wrapper : resultsPage1_noParams) {
            System.assert(wrapper.component.name.startsWith(cachedCompNamePrefix),
                          'Searches for page 1 with no params SHOULD hit the Recently Modified Components cache');
        }
    }

    static testMethod void getCachedSearchResults_CacheRefreshedWhenEmpty() {
        ComponentDocServices.RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT = 5;
        Instances__c instance = TestingUtils.createInstance('testInstanceName');
        createComps(10, DateTime.now().addDays(-1), 'namePrefix', instance.Id);

        System.assertEquals(0, ComponentDocServices.getCachedRecentlyModifiedComponents().size(),
                            'No components should exist in the cache prior to component search being run');

        Test.startTest();
            doPageSearchWithEmptySearchParams(1, 5);
        Test.stopTest();

        System.assertEquals(ComponentDocServices.RECENTLY_MODIFIED_COMPONENTS_CACHE_LIMIT,
                            ComponentDocServices.getCachedRecentlyModifiedComponents().size(),
                            'Running doPageSearch should add components to the previously empty cache');
    }

    static testMethod void getSearchResults_filterByUser_multipleInstances() {
        Instances__c instance = TestingUtils.createInstance('dev');
        Instances__c instance2 = TestingUtils.createInstance('dev2');
        Component__c componentNoUser = TestingUtils.createComponent('Test trigger', 'Trigger', instance.Id);
        Component__c componentWithUser = TestingUtils.buildComponent('User', 'Trigger', instance.Id);

        String USERNAME = 'Target User';

        FieldModifiedData lastModifiedDataTarget = new FieldModifiedData(instance.Name, null, USERNAME, null, 'somebody');
        FieldModifiedData lastModifiedDataOther = new FieldModifiedData(instance2.Name, null, 'Other Name', null, 'somebody');
        componentWithUser.Last_Modified_Users__c = USERNAME + ';' + lastModifiedDataOther.lastModifiedByName;
        componentWithUser.Field_Modified_Data__c = JSON.serialize(
            new List<FieldModifiedData>{ lastModifiedDataTarget, lastModifiedDataOther }
        );
        insert componentWithUser;

        Test.startTest();

            ClientComponentSearchController.ComponentSearchResult searchResults
                = ClientComponentSearchController.getSearchResults(
                    null, componentNoUser.Type__c, null, null, '', new List<String>{USERNAME});

        Test.stopTest();

         System.assertEquals(1, searchResults.results.size(),
             'The component with matching last modified by user should be returned');
         System.assertEquals(componentWithUser.Id, searchResults.results[0].component.Id,
             'The component with matching last modified by user should be returned');
         System.assertEquals(lastModifiedDataTarget.environmentName, searchResults.results[0].environment,
             'The component with matching last modified by user should be returned');
    }

    static testMethod void getSearchResults_filterByUsers() {
        Instances__c instance = TestingUtils.createInstance('dev');
        Instances__c instance2 = TestingUtils.createInstance('dev2');
        Component__c componentNoUser = TestingUtils.createComponent('Test trigger', 'Trigger', instance.Id);
        Component__c componentWithUsers = TestingUtils.buildComponent('User', 'Trigger', instance.Id);

        String USERNAME = 'Target User';
        String USERNAME2 = 'Target User2';

        FieldModifiedData lastModifiedDataTarget1 = new FieldModifiedData(instance.Name, null, USERNAME, null, 'somebody');
        FieldModifiedData lastModifiedDataTarget2 = new FieldModifiedData(instance2.Name, null, USERNAME2, null, 'somebody');
        FieldModifiedData lastModifiedDataOther = new FieldModifiedData(instance2.Name, null, 'Other Name', null, 'somebody');
        componentWithUsers.Last_Modified_Users__c = USERNAME + ';' + USERNAME2;
        componentWithUsers.Field_Modified_Data__c = JSON.serialize(
            new List<FieldModifiedData>{ lastModifiedDataTarget1, lastModifiedDataTarget2, lastModifiedDataOther }
        );
        insert componentWithUsers;

        Test.startTest();

            ClientComponentSearchController.ComponentSearchResult searchResults
                = ClientComponentSearchController.getSearchResults(
                    null, componentNoUser.Type__c, null, null, '', new List<String>{USERNAME, USERNAME2});

        Test.stopTest();

         System.assertEquals(2, searchResults.results.size(),
             'The component with matching last modified by user should be returned');

         System.assertEquals(componentWithUsers.Id, searchResults.results[0].component.Id,
             'The component with matching last modified by user should be returned');
         System.assertEquals(componentWithUsers.Id, searchResults.results[1].component.Id,
             'The component with matching last modified by user should be returned');

         Set<String> expectedUserNames = new Set<String>{ USERNAME, USERNAME2};
         System.assertEquals(true, expectedUserNames.contains(searchResults.results[0].lastModifiedBy),
             'The component with matching last modified by user should be returned');
         System.assertEquals(true, expectedUserNames.contains(searchResults.results[1].lastModifiedBy),
             'The component with matching last modified by user should be returned');
    }

    static testMethod void getSearchResults_withExistingBacklogComponent_noEnvironment() {
        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c component = TestingUtils.createComponent('Test trigger', 'Trigger', instance.Id);
        Backlog__c item = TestingUtils.createBacklogItem();

        Backlog_Component__c backlogComponent = new Backlog_Component__c(
            Backlog__c = item.Id,
            Component__c = component.Id,
            Source_Instance__c = instance.Id
        );
        insert backlogComponent;

        String key = instance.Name + '|' + backlogComponent.Component__c;

        Test.startTest();

            ClientComponentSearchController.ComponentSearchResult searchResults
                = ClientComponentSearchController.getSearchResults(component.Name, component.Type__c, null, null, key, null);

        Test.stopTest();

         System.assertEquals(1, searchResults.results.size(), 'The component searched for should be returned');
         System.assertEquals(true, searchResults.results[0].checked, 'Components with backlog components should be marked as such.');
    }

    static testMethod void getSearchResults_withExistingBacklogComponent_withEnvironment() {
        Instances__c instance = TestingUtils.createInstance('dev');
        Backlog__c item = TestingUtils.createBacklogItem();
        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(item.Id, instance);
        String key = instance.Name + '|' + backlogComponent.Component__c;
        Test.startTest();

            ClientComponentSearchController.ComponentSearchResult searchResults
                = ClientComponentSearchController.getSearchResults('test', 'Object', null, null, key, null);

        Test.stopTest();

         System.assertEquals(1, searchResults.results.size(), 'The component searched for should be returned');
         System.assertEquals(true, searchResults.results[0].checked, 'Components with backlog components should be marked as such.');
    }
    
    static testMethod void getSearchResults_excludesProfiles() {
        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c profileComponent = TestingUtils.createComponent('ProfileToExclude', 
            ComponentDocServices.PROFILE_COMPONENT_TYPE, instance.Id);
        Test.startTest();

            ClientComponentSearchController.ComponentSearchResult searchResults
                = ClientComponentSearchController.getSearchResults(null, null, null, null, null, null);

        Test.stopTest();

        System.assertEquals(0, searchResults.results.size(), 
            'Any profile components should not be returned in the results');
    }

    static testMethod void createSelectedComponents() {
        Instances__c instance = TestingUtils.createInstance('Dev');
        Backlog__c item = TestingUtils.createBacklogItem();

        Component__c testComponent = new Component__c(Name='Test Component', Type__c='Static Resource', Instance__c=instance.Id);
        testComponent.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{
            new FieldModifiedData(instance.Name, Datetime.now().addDays(-1), null, null, null, false)
        });
        insert testComponent;

        String note = 'deploy this manually';
        String selectedComponentIdString = instance.Name + '|' + testComponent.Id;
        Test.startTest();
            ClientComponentSearchController.createSelectedComponents(selectedComponentIdString, item.Id, note);
        Test.stopTest();

        List<Backlog_Component__c> createdComponents = [
             SELECT Id, Component__c, Name, Source_Instance__c, Source_Sandbox__c, Notes__c, Deploy_Manually__c
              FROM Backlog_Component__c
              WHERE Backlog__c = :item.Id
        ];

        System.assertEquals(1, createdComponents.size(), 'The backlog component should be created.');
        System.assertEquals(testComponent.Id, createdComponents[0].Component__c, 'The component Id should be set.');
        System.assertEquals(instance.Id, createdComponents[0].Source_Instance__c, 'The instance lookup should be set.');
        System.assertEquals(instance.Name, createdComponents[0].Source_Sandbox__c, 'The legacy instance name should be set.');
        System.assertEquals(note, createdComponents[0].Notes__c, 'The notes field should be set.');
        System.assertEquals(false, createdComponents[0].Deploy_Manually__c, 'The deploy manually field should be false');
    }

    static testMethod void createSelectedComponents_unsupportedtype() {
        final String UNSUPPORTED_TYPE = 'Static Resource';
        Instances__c instance = TestingUtils.createInstance('Dev');
        Backlog__c item = TestingUtils.createBacklogItem();

        UnsupportedMetadataTypes__c rec = new UnsupportedMetadataTypes__c();
        rec.Name = UNSUPPORTED_TYPE;
        rec.Name__c = UNSUPPORTED_TYPE;
        insert rec;


        Component__c testComponent = new Component__c(Name='Test Component', Type__c=UNSUPPORTED_TYPE, Instance__c=instance.Id);
        testComponent.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{
            new FieldModifiedData(instance.Name, Datetime.now().addDays(-1), null, null, null, false)
        });
        insert testComponent;

        String note = 'deploy this manually';
        String selectedComponentIdString = instance.Name + '|' + testComponent.Id;
        Test.startTest();
            ClientComponentSearchController.createSelectedComponents(selectedComponentIdString, item.Id, note);
        Test.stopTest();

        List<Backlog_Component__c> createdComponents = [
             SELECT Id, Component__c, Name, Source_Instance__c, Source_Sandbox__c, Notes__c, Deploy_Manually__c
              FROM Backlog_Component__c
              WHERE Backlog__c = :item.Id
        ];

        System.assertEquals(1, createdComponents.size(), 'The backlog component should be created.');
        System.assertEquals(testComponent.Id, createdComponents[0].Component__c, 'The component Id should be set.');
        System.assertEquals(instance.Id, createdComponents[0].Source_Instance__c, 'The instance lookup should be set.');
        System.assertEquals(instance.Name, createdComponents[0].Source_Sandbox__c, 'The legacy instance name should be set.');
        System.assertEquals(note, createdComponents[0].Notes__c, 'The notes field should be set.');
        System.assertEquals(true, createdComponents[0].Deploy_Manually__c, 'The deploy manually field should be true');
    }

    static testMethod void createSelectedComponents_selectProfiles() {
        Instances__c instance = TestingUtils.createInstance('Dev');
        Backlog__c item = TestingUtils.createBacklogItem();

        Component__c profileComponent = new Component__c(Name='Admin', Type__c='Profile', Instance__c=instance.Id);
        insert profileComponent;

        String selectedComponentIdString = instance.Name + '|' + profileComponent.Id;

        Test.startTest();

            ClientComponentSearchController.createSelectedComponents(selectedComponentIdString, item.Id, '');

        Test.stopTest();

        List<Backlog_Component__c> createdPermissions = [
             SELECT Id, Component__c, Profile__c, Profile_Permission__c, Source_Instance__c
              FROM Backlog_Component__c
              WHERE Backlog__c = :item.Id
        ];

        System.assertEquals(1, createdPermissions.size(), 'A permission should be created for every selected profile');
        System.assertEquals(profileComponent.Id, createdPermissions[0].Component__c, 'The component Id should be set');
        System.assertEquals(profileComponent.Id, createdPermissions[0].Profile__c, 'The profile lookup shoudl be set');
        System.assertEquals(true, createdPermissions[0].Profile_Permission__c, 'All permissions should be only for documented components by default');
        System.assertEquals(instance.Id, createdPermissions[0].Source_Instance__c, 'The source instance should be set');
    }
}
