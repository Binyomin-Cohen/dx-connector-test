@isTest
public class TestComponentDocController {

    static ComponentDocController controller;
    static PageReference p;

    static Backlog__c story;
    static final String INSTANCE_NAME ='dev';
    static Instances__c instance = new Instances__c(Name=INSTANCE_NAME);

    @TestVisible
    private static void assertInstanceRunTimes(Map<String,String> expected, Map<String,String> actual) {
        System.assertEquals(expected.size(), actual.size(), 'The size of the results should be equal to the expected');
        System.assert(expected.keySet().containsAll(actual.keySet()),'The actual should have the same keys as the expected');

        for (String expectedKey : expected.keySet()) {
            DateTime expectedDateTime = DateTime.parse(expected.get(expectedKey));
            DateTime actualFormatedDateTime = DateTime.parse(actual.get(expectedKey));

            System.assertEquals(expectedDateTime, actualFormatedDateTime, 'The actual date should match the expected date');
        }
    }
    private static void setup() {
        setup( true, TestingUtils.ADMIN_USER );
    }

    private static void setup( Boolean setBacklogId, User runningUser ) {
        insert instance;

        Persona__c persona = new Persona__c(Name='Build Manager');
        insert persona;

        story = new Backlog__c(Persona__c=persona.Id, User_Goal__c='to do something');
        insert story;

        PageReference currentPage = new PageReference('/apex/ComponentDocumentationLightning');

        if( setBacklogId )
            currentPage.getParameters().put('id', story.Id);
        else
            currentPage.getParameters().put('id', null);

        Test.setCurrentPage(currentPage);
        
        System.RunAs(runningUser) {
            initializeCompDocController( runningUser );
        }
    }

    private static void initializeCompDocController( User runningUser ) {

        if (!TestingUtils.isUserAssignedToPermissionSet(TestingUtils.ADMIN_USER.Id, TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET.Id)) {
            insert new PermissionSetAssignment(AssigneeId=TestingUtils.ADMIN_USER.Id, PermissionSetId=TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET.Id);
        }
        System.runAs(runningUser) {
            ApexPages.StandardSetController sc = new ApexPages.StandardSetController(new List<Backlog_Component__c>());
            controller = new ComponentDocController(sc);
        }
    }

    private static List<Backlog_Component__c> getStoryMembers() {
        return [Select Backlog__c, Component__c, Source_Sandbox__c, Notes__c From Backlog_Component__c];
    }

    static testMethod void testSetPageContext_validBacklog() {
        Boolean result; 
        setup();

        Test.startTest();

        System.runAs(TestingUtils.ADMIN_USER) {
            result = controller.setPageContext();
        }

        Test.stopTest();
        System.assert( result, 'The controller\'s context should be correctly set because the backlog is valid');

    }

    static testMethod void testSetPageContext_nullBacklog() {
        Boolean setBacklogId = false;

        setup( setBacklogId, TestingUtils.ADMIN_USER );

        Test.startTest();

            Boolean result = controller.setPageContext();

        Test.stopTest();
        System.assert( !result, 'The controller\'s context should not be correctly set because the backlog is invalid');

    }

    static testMethod void testSetPageContext_nonAdminUser() {
        Boolean setBacklogId = true;
        Profile standardUserProfile = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User nonAdminUser = TestingUtils.buildUser(standardUserProfile.Id);

        setup(setBacklogId, nonAdminUser);

        Test.startTest();

            Boolean result = controller.setPageContext();

        Test.stopTest();
        System.assert( !result, 'The controller\'s context should not be correctly set because the running user does not have access to the necesary configuration');

    }

    static testMethod void testGetFormData_DataExists() {
        final String INSTANCE2_NAME ='dev2';
        Instances__c instance2 = new Instances__c(Name=INSTANCE2_NAME);
        insert instance2;

        setup();

        final String OBJECTTYPE = 'Object';
        final String WORKFLOWTYPE = 'Workflow';

        List<Supported_Metadata_Types__c> mdTypes = new List<Supported_Metadata_Types__c>();
        mdTypes.add(new Supported_Metadata_Types__c(Name=OBJECTTYPE));
        mdTypes.add(new Supported_Metadata_Types__c(Name=WORKFLOWTYPE));

        insert mdTypes;

        List<String> expectedSupportedMetadataTypes = new List<String>{OBJECTTYPE, WORKFLOWTYPE};

        DateTime now = DateTime.now();
        TestingUtils.createAlmApplicationResult(now, now.addMinutes(2), 'SuCCesS', 'Success', instance.Id, ALMJobServices.ToolType.SCAN);
        TestingUtils.createAlmApplicationResult(now, now.addMinutes(3), 'SuCCesS', 'Success', instance2.Id, ALMJobServices.ToolType.SCAN);

        Map<String, String> expectedTimesMap = new Map<String, String>{
            INSTANCE_NAME => now.addMinutes(2).format(),
            INSTANCE2_NAME => now.addMinutes(3).format()
        };

        List<String> expectedInstances = new List<String>{INSTANCE_NAME, INSTANCE2_NAME};

        final String VALID_USER1_NAME = 'Steve';
        final String VALID_USER2_NAME = 'Janis';
        final String VALID_USER3_NAME = 'Bob';

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c>();
        settings.add(ALMSettingsServices.buildAvailableComponentUsersSetting(VALID_USER1_NAME, 2));
        settings.add(ALMSettingsServices.buildAvailableComponentUsersSetting(VALID_USER2_NAME, 1));
        settings.add(ALMSettingsServices.buildAvailableComponentUsersSetting(VALID_USER3_NAME, 0));

        List<String> expectedUsers = new List<String>{VALID_USER3_NAME, VALID_USER2_NAME, VALID_USER1_NAME};

        System.runAs(TestingUtils.ADMIN_USER) {
            insert settings;
        }

        Map<String, Object> formDataReturned;
        Test.startTest();
            formDataReturned = ComponentDocController.getFormData();
        Test.stopTest();

        System.assertEquals( expectedSupportedMetadataTypes, formDataReturned.get( ComponentDocController.SUPPORTED_METADATA_TYPES_KEY ), 'The Supported Metadata Types should be populated');
        System.assertEquals( expectedUsers, formDataReturned.get( ComponentDocController.AVAILABLE_USERS_KEY ), 'The Available Users should be populated');
        assertInstanceRunTimes(expectedTimesMap, (Map<String,String>)formDataReturned.get( ComponentDocController.INSTANCES_RUN_TIMES_KEY ));
        System.assertEquals( expectedInstances, formDataReturned.get( ComponentDocController.INSTANCES_KEY ), 'The instances should be correctly populated');

    }

    static testMethod void testGetFormData_DataExists_cached() {
        final String INSTANCE2_NAME ='dev2';
        Instances__c instance2 = new Instances__c(Name=INSTANCE2_NAME);
        insert instance2;

        setup();

        final String OBJECTTYPE = 'Object';
        final String WORKFLOWTYPE = 'Workflow';

        List<Supported_Metadata_Types__c> mdTypes = new List<Supported_Metadata_Types__c>();
        mdTypes.add(new Supported_Metadata_Types__c(Name=OBJECTTYPE));
        mdTypes.add(new Supported_Metadata_Types__c(Name=WORKFLOWTYPE));

        insert mdTypes;

        List<String> expectedSupportedMetadataTypes = new List<String>{OBJECTTYPE, WORKFLOWTYPE};

        DateTime now = DateTime.now();
        TestingUtils.createAlmApplicationResult(now, now.addMinutes(2), 'SuCCesS', 'Success', instance.Id, ALMJobServices.ToolType.SCAN);
        TestingUtils.createAlmApplicationResult(now, now.addMinutes(3), 'SuCCesS', 'Success', instance2.Id, ALMJobServices.ToolType.SCAN);
        TestingUtils.createAlmApplicationResult(now, null, 'SuCCesS', 'Success', instance2.Id, ALMJobServices.ToolType.SCAN);

        Map<String, String> expectedTimesMap = new Map<String, String>{
            INSTANCE_NAME => now.addMinutes(2).format(),
            INSTANCE2_NAME => now.addMinutes(3).format()
        };

        List<String> expectedInstances = new List<String>{INSTANCE_NAME, INSTANCE2_NAME};

        final String VALID_USER1_NAME = 'Steve';
        final String VALID_USER2_NAME = 'Janis';
        final String VALID_USER3_NAME = 'Bob';

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c>();
        settings.add(ALMSettingsServices.buildAvailableComponentUsersSetting(VALID_USER1_NAME, 2));
        settings.add(ALMSettingsServices.buildAvailableComponentUsersSetting(VALID_USER2_NAME, 1));
        settings.add(ALMSettingsServices.buildAvailableComponentUsersSetting(VALID_USER3_NAME, 0));

        List<String> expectedUsers = new List<String>{VALID_USER3_NAME, VALID_USER2_NAME, VALID_USER1_NAME};

        System.runAs(TestingUtils.ADMIN_USER) {
            insert settings;
        }

        Map<String, Object> formDataReturned;
        Map<String, Object> formDataReturned2;

        formDataReturned = ComponentDocController.getFormData();
        ComponentDocController.getFormData();
        List<State__c> stateRecordsCreated = [Select Id from State__c where Token__c = :ALMApplicationResultServices.PAGE_STATE_TOKEN];
        System.assertEquals( 1, stateRecordsCreated.size(), 'Only one state record should be created');

        Test.startTest();
            Integer queriesMadeBefore = Limits.getAggregateQueries();
            formDataReturned2 = ComponentDocController.getFormData();
            Integer queriesMadeAfter = Limits.getAggregateQueries();
        Test.stopTest();

        System.assertEquals( expectedSupportedMetadataTypes, formDataReturned.get( ComponentDocController.SUPPORTED_METADATA_TYPES_KEY ), 'The Supported Metadata Types should be populated');
        System.assertEquals( expectedUsers, formDataReturned.get( ComponentDocController.AVAILABLE_USERS_KEY ), 'The Available Users should be populated');
        assertInstanceRunTimes(expectedTimesMap, (Map<String,String>)formDataReturned.get( ComponentDocController.INSTANCES_RUN_TIMES_KEY ));
        assertInstanceRunTimes(expectedTimesMap, (Map<String,String>)formDataReturned2.get( ComponentDocController.INSTANCES_RUN_TIMES_KEY ));
        System.assertEquals( expectedInstances, formDataReturned.get( ComponentDocController.INSTANCES_KEY ), 'The instances should be correctly populated');
        System.assertEquals( queriesMadeBefore, queriesMadeAfter, 'No queries should be made since we are using the cache');

    }

    static testMethod void testGetFormData_NoDataExists() {

        Map<String, Object> formDataReturned;

        Map<String, Object> expectedformDataReturned = new Map<String, Object>{
            ComponentDocController.SUPPORTED_METADATA_TYPES_KEY => new List<String>(),
            ComponentDocController.AVAILABLE_USERS_KEY => new List<String>(),
            ComponentDocController.INSTANCES_RUN_TIMES_KEY => new Map<String, String>(),
            ComponentDocController.INSTANCES_KEY => new List<String>{}
        };
        Test.startTest();
            formDataReturned = ComponentDocController.getFormData();
        Test.stopTest();

        System.assertEquals( expectedformDataReturned, formDataReturned, 'The form data should be initialized but not populated');
    }

    static testMethod void testGetFormData_OneInstanceExists() {
        setup();

        Map<String, Object> formDataReturned;

        Map<String, Object> expectedformDataReturned = new Map<String, Object>{
            ComponentDocController.SUPPORTED_METADATA_TYPES_KEY => new List<String>(),
            ComponentDocController.AVAILABLE_USERS_KEY => new List<String>(),
            ComponentDocController.INSTANCES_RUN_TIMES_KEY => new Map<String, String>(),
            ComponentDocController.INSTANCES_KEY => new List<String>{INSTANCE_NAME}
        };
        Test.startTest();
            formDataReturned = ComponentDocController.getFormData();
        Test.stopTest();

        System.assertEquals( expectedformDataReturned, formDataReturned, 'The form data should be initialized and only one instance should be detected');
    }


    static testMethod void queryExistingMembers() {
        setup();

        Component__c someProfileComponent = TestingUtils.createComponent('someProfileComponent', 'Profile', instance.Id);

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(story.Id, instance);
        Backlog_Component__c backlogProfileComponent = TestingUtils.createDocumentedProfile(story.Id, someProfileComponent, instance.Id);

        Test.startTest();
            List<ComponentSearchWrapper> results = ComponentDocController.queryExistingMembers(story.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'We expect one documented component');
        System.assertEquals(backlogComponent.Component__c, results[0].component.Id, 'We expect the correct component to be returned.');
    }

    static testMethod void queryExistingMembers_observeSavedIsDeletedValue() {
        setup();

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(story.Id, instance);

        Component__c componentToDelete = new Component__c(Id = backlogComponent.Component__c);
        FieldModifiedData deletedData = new FieldModifiedData(instance.Name, true);
        componentToDelete.Field_Modified_Data__c = JSON.serialize( new List<FieldModifiedData>{ deletedData } );
        update componentToDelete;

        Test.startTest();
            List<ComponentSearchWrapper> results = ComponentDocController.queryExistingMembers(story.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'The documented component should be returned');
        System.assertEquals(backlogComponent.Component__c, results[0].component.Id, 'The documented component should be returned');
        System.assertEquals(false, results[0].isDeleted, 'The deleted value of the component should be unchanged');
    }

    static testMethod void getBacklogComponentsDiffs_noPriorComponents() {
        setup();

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(story.Id, instance);

        Test.startTest();
            ComponentDocController.DocumentedComponentDiff results 
                = ComponentDocController.getBacklogComponentsDiffs(story.Id, null);
        Test.stopTest();

        System.assertEquals(1, results.addedComponents.size(), 'The newly added component should be returned');
        System.assertEquals(backlogComponent.Id, results.addedComponents[0].backlogComponent.Id,
             'The newly added component should be returned');
        System.assertEquals(0, results.deletedComponents.size(), 'The deleted components list should remain empty');
    }

    static testMethod void getBacklogComponentsDiffs_noNewComponents() {
        setup();

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(story.Id, instance);

        Test.startTest();
            ComponentDocController.DocumentedComponentDiff results 
                    = ComponentDocController.getBacklogComponentsDiffs(
                        story.Id, new List<String> { backlogComponent.Id });
        Test.stopTest();

        System.assertEquals(0, results.addedComponents.size(), 'No added components should be returned');
        System.assertEquals(0, results.deletedComponents.size(), 'The deleted components list should remain empty');
    }

    static testMethod void getBacklogComponentsDiffs_deletedComponents() {
        setup();

        Backlog_Component__c deletedBacklogComponent = TestingUtils.createDocumentedBacklogComponent(story.Id, instance);
        delete deletedBacklogComponent;

        Test.startTest();
            ComponentDocController.DocumentedComponentDiff results 
                    = ComponentDocController.getBacklogComponentsDiffs(
                        story.Id, new List<String> { deletedBacklogComponent.Id });
        Test.stopTest();

        System.assertEquals(0, results.addedComponents.size(), 'No added components should be returned');
        System.assertEquals(1, results.deletedComponents.size(), 'The deleted component should be returned');
        System.assertEquals(deletedBacklogComponent.Id, results.deletedComponents[0], 'The deleted component should be returned');
    }

    static testMethod void getBacklogComponentsDiffs() {
        setup();

        Component__c existingComp1 = TestingUtils.buildComponent('exists', ComponentServices.APEX_ALM_NAME, instance.Id);
        Component__c deletedComp = TestingUtils.buildComponent('deleted', ComponentServices.APEX_ALM_NAME, instance.Id);
        Component__c newComp1 = TestingUtils.buildComponent('new1', ComponentServices.APEX_ALM_NAME, instance.Id);
        Component__c newComp2 = TestingUtils.buildComponent('new2', ComponentServices.APEX_ALM_NAME, instance.Id);
        insert new List<Component__c> { existingComp1, deletedComp, newComp1, newComp2 };

        Backlog_Component__c existingBacklogComponent 
            = TestingUtils.buildDocumentedComponent(story.Id, existingComp1, instance.Id);
        Backlog_Component__c deletedBacklogComponent 
            = TestingUtils.buildDocumentedComponent(story.Id, deletedComp, instance.Id);
        Backlog_Component__c newBacklogComponent1 
            = TestingUtils.buildDocumentedComponent(story.Id, newComp1, instance.Id);
        Backlog_Component__c newBacklogComponent2 
            = TestingUtils.buildDocumentedComponent(story.Id, newComp2, instance.Id);
        insert new List<Backlog_Component__c> {
             existingBacklogComponent, deletedBacklogComponent, newBacklogComponent1, newBacklogComponent2};

        delete deletedBacklogComponent;

        Test.startTest();
            ComponentDocController.DocumentedComponentDiff results 
                    = ComponentDocController.getBacklogComponentsDiffs(
                        story.Id, new List<String> { existingBacklogComponent.Id, deletedBacklogComponent.Id });
        Test.stopTest();

        System.assertEquals(2, results.addedComponents.size(), 'The newly added components should be returned');
        Set<Id> addedComponents = new Set<Id>{ newBacklogComponent1.Id, newBacklogComponent2.Id };

        System.assertEquals(true, addedComponents.contains(results.addedComponents[0].backlogComponent.Id),
             'The newly added component should be returned');
        System.assertEquals(true, addedComponents.contains(results.addedComponents[1].backlogComponent.Id),
             'The newly added component should be returned');

        System.assertEquals(1, results.deletedComponents.size(), 'The deleted component should be returned');
        System.assertEquals(deletedBacklogComponent.Id, results.deletedComponents[0], 'The deleted component should be returned');
    }

    static testMethod void deleteSelectedComponents() {
        setup();

        Backlog__c backlogItem = TestingUtils.createBacklogItems(1, true)[0];

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(backlogItem.Id, instance);

        Test.startTest();
            ComponentDocController.deleteSelectedComponents(new List<Id>{backlogComponent.Id});
        Test.stopTest();

        List<Backlog_Component__c> currentComponents = [select id from Backlog_Component__c where Backlog__c = :backlogItem.Id];

        System.assertEquals(0, currentComponents.size(), 'We expect the selected component to be deleted.');

    }

    static testMethod void deleteSelectedComponents_errorHandling() {
        setup();
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.LOG_ACTION));

        Backlog__c backlogItem = TestingUtils.createBacklogItems(1, true)[0];
        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(backlogItem.Id, instance);
        String backlogComponentId = backlogComponent.Id;
        delete backlogComponent;

        Test.startTest();
            try{
                ComponentDocController.deleteSelectedComponents(new List<Id>{backlogComponentId});
                System.assert(false, 'We expect an exception to be thrown.');
            } catch (Exception e){
                System.assert(e instanceOf AuraHandledException, 'We expect to have the correct exception thrown.');
            }
        Test.stopTest();

    }

    static testMethod void updateComponentNotes() {
        setup();

        Backlog__c backlogItem = TestingUtils.createBacklogItems(1, true)[0];

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(backlogItem.Id, instance);

        List<Backlog_Component__c> currentComponents = [select id, Notes__c from Backlog_Component__c where Backlog__c = :backlogItem.Id];

        System.assertEquals(1, currentComponents.size(), 'We expect to get back a documented component');
        System.assert(String.isBlank(currentComponents[0].Notes__c), 'We expect the  documented component to have no notes');

        String NEW_NOTES = 'new notes';

        Test.startTest();
            ComponentDocController.updateComponentNotes(backlogComponent.Id, NEW_NOTES);
        Test.stopTest();

        currentComponents = [select id, Notes__c from Backlog_Component__c where Backlog__c = :backlogItem.Id];

        System.assertEquals(1, currentComponents.size(), 'We expect to get back a documented component');
        System.assertEquals(NEW_NOTES, currentComponents[0].Notes__c, 'We expect the  documented component to have notes populated');
    }

    static testMethod void updateComponentNotes_errorHandling() {
        setup();
        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.LOG_ACTION));

        Backlog__c backlogItem = TestingUtils.createBacklogItems(1, true)[0];

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(backlogItem.Id, instance);

        List<Backlog_Component__c> currentComponents = [select id, Notes__c from Backlog_Component__c where Backlog__c = :backlogItem.Id];

        System.assertEquals(1, currentComponents.size(), 'We expect to get back a documented component');
        System.assert(String.isBlank(currentComponents[0].Notes__c), 'We expect the  documented component to have no notes');

        String NEW_NOTES = 'new notes';

        Test.startTest();
            try{
                ComponentDocController.updateComponentNotes(null, NEW_NOTES);
                System.assert(false, 'We expect an exception to be thrown.');
            } catch (Exception e){
                System.assert(e instanceOf AuraHandledException, 'We expect to have the correct exception thrown.');
            }
        Test.stopTest();

        currentComponents = [select id, Notes__c from Backlog_Component__c where Backlog__c = :backlogItem.Id];

        System.assertEquals(1, currentComponents.size(), 'We expect to get back a documented component');
        System.assert(String.isBlank(currentComponents[0].Notes__c), 'We expect the  documented component to have no notes');
    }

    static testMethod void updateComponentDeployManually() {
        setup();

        Backlog__c backlogItem = TestingUtils.createBacklogItems(1, true)[0];

        Backlog_Component__c backlogComponent = TestingUtils.createDocumentedBacklogComponent(backlogItem.Id, instance);

        List<Backlog_Component__c> currentComponents = [
            SELECT Id, Deploy_Manually__c FROM Backlog_Component__c WHERE Backlog__c = :backlogItem.Id
        ];

        System.assertEquals(1, currentComponents.size(), 'There should be 1 backlog component');
        System.assertEquals(false, currentComponents[0].Deploy_Manually__c, 'Deploy manually should be initialized to false');

        Test.startTest();
            ComponentDocController.updateComponentDeployManually(backlogComponent.Id, true);
        Test.stopTest();

        currentComponents = [
            SELECT Id, Deploy_Manually__c FROM Backlog_Component__c WHERE Backlog__c = :backlogItem.Id
        ];

        System.assertEquals(true, currentComponents[0].Deploy_Manually__c, 'Deploy manually should have its value updated');
    }

    static testMethod void queryDocumentedComponents() {
        Integer COMP_LIMIT_PAGE_1 = 1;
        Integer COMP_LIMIT_PAGE_2 = 10000; // large limit to simulate what the frontend will be supplying

        Instances__c instance = TestingUtils.createInstance('testInstance');
        Backlog__c story = TestingUtils.createBacklogItems(1, true)[0];

        Backlog_Component__c backlogProfileComponent = TestingUtils.createDocumentedProfile(story.Id, 'ProfileName',
                                                                                            instance.Id);

        List<Backlog_Component__c> documentedComps = TestingUtils.documentComponentsToBacklogItem(
            instance.Id,
            story.Id,
            TestingUtils.createComponents(3, 'test', 'testType', instance.Id)
        );
        Set<Id> documentedCompIds = Pluck.Ids('Id', documentedComps);

        Test.startTest();
            ComponentDocController.DocumentedComponentsQueryResult query1 =
                ComponentDocController.queryDocumentedComponents(story.Id, 0, COMP_LIMIT_PAGE_1, true);

            // start the second query where the first left off (ie offset = COMP_LIMIT_PAGE_1)
            ComponentDocController.DocumentedComponentsQueryResult query2 =
                ComponentDocController.queryDocumentedComponents(story.Id, COMP_LIMIT_PAGE_1, COMP_LIMIT_PAGE_2, false);
        Test.stopTest();

        // test that all backlog comps were retrieved
        System.assertEquals(COMP_LIMIT_PAGE_1, query1.results.size(),
            'The first query should return the correct number of backlog components');

        Integer remainingResultsPageSize = documentedComps.size() - COMP_LIMIT_PAGE_1;
        System.assertEquals(remainingResultsPageSize, query2.results.size(),
            'The second query should return the correct number of backlog components');

        List<ComponentSearchWrapper> allResults = new List<ComponentSearchWrapper>();
        allResults.addAll(query1.results);
        allResults.addAll(query2.results);
        Set<Id> queriedIds = new Set<Id>();
        for (ComponentSearchWrapper result : allResults) {
            queriedIds.add(result.backlogComponent.Id);
        }
        System.assert(documentedCompIds.equals(queriedIds), 'All backlog components should have been queried');

        // test whether documented components count was retrieved
        System.assertEquals(documentedComps.size(), query1.totalDocumentedComponents,
            'the total number of documented components should exclude profiles');
        System.assertEquals(null, query2.totalDocumentedComponents,
            'the total number of documented components should not have been retrieved');

        // test hasMore
        System.assert(query1.hasMore, 'The first query should indicate that there are more results');
        System.assert(!query2.hasMore, 'The second query should NOT indicate that there are more results');
    }
}
