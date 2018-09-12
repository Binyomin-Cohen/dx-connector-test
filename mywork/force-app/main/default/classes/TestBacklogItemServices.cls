@isTest
private class TestBacklogItemServices {
    static final String INACTIVE_STATUS = 'Released';
    static final String ACTIVE_STATUS = 'Dev ready';

    static void setupTestSprintItemData(Boolean doInsert){
        UnitTest.addData(TestingUtils.buildSprints('test_sprint', 2)).tag('Sprints');
        if (doInsert){
            UnitTest.get('Sprints').insertAll();
        }
        else {
            UnitTest.get('Sprints').dummyInsert();
        }
        UnitTest.get('Sprints')
            .divide(2)
            .part('Sprint 1')
            .part('Sprint 2');
        UnitTest.addData(TestingUtils.buildBacklogItems(2)).tag('Backlogs');
        if (doInsert){
            UnitTest.get('Backlogs').insertAll();
        }
        else {
            UnitTest.get('Backlogs').dummyInsert();
        }

        UnitTest.addData(TestingUtils.buildSprintItems(null, (List<Backlog__c>) UnitTest.get('Backlogs').getList() )).tag('Sprint Items');
        UnitTest.get('Sprint Items')
            .divide(2)
            .part('Sprint Items in Sprint 1')
            .part('Sprint Items in Sprint 2');
        UnitTest.get('Sprint Items in Sprint 1').property(SObjectServices.getFullyQualifiedName('Sprint__c')).assign(UnitTest.get('Sprint 1').getList()[0].Id);
        UnitTest.get('Sprint Items in Sprint 2').property(SObjectServices.getFullyQualifiedName('Sprint__c')).assign(UnitTest.get('Sprint 2').getList()[0].Id);
        if (doInsert){
            UnitTest.get('Sprint Items').insertAll();
        }
        else {
            UnitTest.get('Sprint Items').dummyInsert();
        }
    }
    static void setupAlmSettings() {
        ALMSettings__c settings = new ALMSettings__c();
        settings.Inactive_Backlog_Statuses_1__c = INACTIVE_STATUS;
        System.runAs( TestingUtils.ADMIN_USER ) {
            insert settings;
        }
    }

    static testMethod void getPrioritizedItemCount() {
        setupAlmSettings();

        List<Backlog__c> items = new List<Backlog__c> {
            TestingUtils.buildBacklogItem(INACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS)
        };

        for (Backlog__c item : items) {
            item.Priority__c = 1;
        }

        insert items;
        Set<Id> alreadyQueriedIds = new Set<Id>();

        Test.startTest();
            Integer itemCount = BacklogItemServices.getPrioritizedItemCount(alreadyQueriedIds);
        Test.stopTest();

        System.assertEquals(2, itemCount, 'The prioritized item count should include all prioritized items that have active statuses');
    }


    static testMethod void getPrioritizedItemCount_avoidQueriedRecord() {
        setupAlmSettings();

        List<Backlog__c> items = new List<Backlog__c> {
            TestingUtils.buildBacklogItem(INACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS)
        };

        for (Backlog__c item : items) {
            item.Priority__c = 1;
        }

        insert items;
        Set<Id> alreadyQueriedIds = new Set<Id>{items[1].id};

        Test.startTest();
            Integer itemCount = BacklogItemServices.getPrioritizedItemCount(alreadyQueriedIds);
        Test.stopTest();

        System.assertEquals(2, itemCount, 'The prioritized item count should include all prioritized items that have active statuses');
    }

    static testMethod void getCustomPrioritizedItemCount() {
        setupAlmSettings();

        Custom_Backlog__c cBacklog = TestingUtils.createCustomBacklog('test');

        List<Backlog__c> items = new List<Backlog__c> {
            TestingUtils.buildBacklogItem(INACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS)
        };
        for (Backlog__c item : items) {
            item.Priority__c = 1;
        }
        items[1].Custom_Backlog__c = cBacklog.Id;
        items[1].Custom_Priority__c = 1;
        Set<Id>alreadyQueriedIds = new Set<Id>();

        insert items;

        Test.startTest();
            Integer itemCount = BacklogItemServices.getCustomPrioritizedItemCount(cBacklog.Id, alreadyQueriedIds);
        Test.stopTest();

        System.assertEquals(1, itemCount,
            'The prioritized item count should include all prioritized items AND are associated with the custom backlog');
    }

    static testMethod void getAllowableQueryRows() {
        List<Backlog__c> items = new List<Backlog__c> {
            TestingUtils.buildBacklogItem(INACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS)
        };

        Test.startTest();
	        insert items;
	        Integer queriesMadeOnInsert = Limits.getQueryRows();
            items = [SELECT Id FROM Backlog__c];
	        Integer expectedQueryRowsRemaining = Limits.getLimitQueryRows() - (queriesMadeOnInsert + items.size());
	        Integer actualQueryRowsRemaining = BacklogItemServices.getAllowableQueryRows();
        Test.stopTest();


        System.assertEquals(expectedQueryRowsRemaining, actualQueryRowsRemaining,
            'The query rows remaining should be correct');
    }

    static testMethod void getAllowableQueryRows_noQuery() {
        List<Backlog__c> items = new List<Backlog__c> {
            TestingUtils.buildBacklogItem(INACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS)
        };

        Test.startTest();
	        insert items;
	        Integer queriesMadeOnInsert = Limits.getQueryRows();
	        Integer expectedQueryRowsRemaining = Limits.getLimitQueryRows() - queriesMadeOnInsert;
            Integer actualQueryRowsRemaining = BacklogItemServices.getAllowableQueryRows();
        Test.stopTest();

        System.assertEquals(expectedQueryRowsRemaining, actualQueryRowsRemaining,
            'The query rows remaining should be correct');
    }

    static testMethod void getCustomPrioritizedItemCount_avoidQueriedRecord() {
        ALMSettings__c settings = new ALMSettings__c();
        settings.Inactive_Backlog_Statuses_1__c = INACTIVE_STATUS;
        System.runAs( TestingUtils.ADMIN_USER ) {
            insert settings;
        }

        Custom_Backlog__c cBacklog = TestingUtils.createCustomBacklog('test');

        List<Backlog__c> items = new List<Backlog__c> {
            TestingUtils.buildBacklogItem(INACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS),
            TestingUtils.buildBacklogItem(ACTIVE_STATUS)
        };
        for (Backlog__c item : items) {
            item.Priority__c = 1;
        }
        items[1].Custom_Backlog__c = cBacklog.Id;
        items[1].Custom_Priority__c = 1;
        items[2].Custom_Backlog__c = cBacklog.Id;
        items[2].Custom_Priority__c = 2;

        insert items;
        Set<Id>alreadyQueriedIds = new Set<Id>{items[2].id};

        Test.startTest();
            Integer itemCount = BacklogItemServices.getCustomPrioritizedItemCount(cBacklog.Id, alreadyQueriedIds);
        Test.stopTest();

        System.assertEquals(2, itemCount,
            'The prioritized item count should include all prioritized items AND are associated with the custom backlog');
    }

    static testMethod void getInactiveStatuses_noInactiveStatuses() {
        Set<String> inactiveStatuses;
        try {
            inactiveStatuses = BacklogItemServices.getInactiveStatuses();
        } catch(Exception e) {
            System.assert(false, 'Inactive status retrieval should succeed when there are no statuses');
        }

        System.assertEquals(0, inactiveStatuses.size(), 'No statuses should be returned when there are no inactive statuses.');
    }
    static testMethod void getInactiveStatuses() {
        String status1 = 'status1';
        String status2 = 'status number two';
        String status3 = '~status !@#$%^&*()_+ three;';
        String status4 = 'fourth  status';

        ALMSettings__c settings = new ALMSettings__c();
        settings.Inactive_Backlog_Statuses_1__c = status1 + BacklogItemServices.INACTIVE_STATUS_SEPARATOR;
        settings.Inactive_Backlog_Statuses_1__c += status2 + BacklogItemServices.INACTIVE_STATUS_SEPARATOR;
        settings.Inactive_Backlog_Statuses_1__c += status3;

        settings.Inactive_Backlog_Statuses_2__c = status4;

        System.runAs( TestingUtils.ADMIN_USER ) {
            insert settings;
        }

        Test.startTest();

            Set<String> inactiveStatuses = BacklogItemServices.getInactiveStatuses();

        Test.stopTest();

        System.assertEquals(4, inactiveStatuses.size(), 'ALL statuses should be returned.');
        System.assert( inactiveStatuses.contains( status1 ), 'All inactive statuses should be returned: format: ' + status1);
        System.assert( inactiveStatuses.contains( status2 ), 'All inactive statuses should be returned: format: ' + status2);
        System.assert( inactiveStatuses.contains( status3 ), 'All inactive statuses should be returned: format: ' + status3);
        System.assert( inactiveStatuses.contains( status4 ), 'All inactive statuses should be returned: format: ' + status4);
    }

    static testMethod void getPrioritizationFields() {

        ALM_Settings_List__c setting1 = ALMSettingsServices.buildPrioritizationColumnSetting('CreatedDate', 1);
        ALM_Settings_List__c setting2 = ALMSettingsServices.buildPrioritizationColumnSetting('LastModifiedById', 2);

        System.runAs( TestingUtils.ADMIN_USER) {
            insert new List<ALM_Settings_List__c>{ setting1, setting2 };
        }

        Test.startTest();

            List<Column> priorityFields = BacklogItemServices.getPrioritizationFields();

        Test.stopTest();

        System.assertEquals(2, priorityFields.size(), 'All fields should be returned.');
        System.assertEquals(setting1.Value__c, priorityFields[0].apiName, 'All fields should have their api name set.');
        System.assertEquals(setting2.Value__c, priorityFields[1].apiName, 'All fields should have their api name set.');
    }

    static testMethod void saveInactiveStatuses_singleField() {
        String status1 = 'status1';
        String status2 = 'status2';

        Test.startTest();
            BacklogItemServices.saveInactiveStatuses(new List<String>{status1, status2});
        Test.stopTest();

        Set<String> inactiveStatuses = BacklogItemServices.getInactiveStatuses();
        System.assertEquals(2, inactiveStatuses.size(), 'Both items should have been saved');
        System.assert(inactiveStatuses.contains(status1), 'Both items should have been saved');
        System.assert(inactiveStatuses.contains(status2), 'Both items should have been saved');
    }

    static testMethod void saveInactiveStatuses_overflow() {
        String longStatus = '';

        for(Integer i = 0; i < 250; i++) {
            longStatus += 'z';
        }

        String newStatus = 'Long status that does not fit';

        Test.startTest();
            BacklogItemServices.saveInactiveStatuses(new List<String>{longStatus, newStatus});
        Test.stopTest();

        Set<String> inactiveStatuses = BacklogItemServices.getInactiveStatuses();
        System.assertEquals(2, inactiveStatuses.size(), 'Both items should have been saved');
        System.assert(inactiveStatuses.contains(longStatus), 'Both items should have been saved');
        System.assert(inactiveStatuses.contains(newStatus), 'Both items should have been saved');
    }

    static testMethod void savePrioritizationFields() {
        ALM_Settings_List__c setting1 = ALMSettingsServices.buildPrioritizationColumnSetting('CreatedDate', 1);

        System.runAs( TestingUtils.ADMIN_USER) {
            insert new List<ALM_Settings_List__c>{ setting1 };
        }

        Test.startTest();
            List<String> newColumns = new List<String>{'Description__c', 'Instance__c'};
            BacklogItemServices.savePrioritizationFields( newColumns );

        Test.stopTest();

        List<ALM_Settings_List__c> savedStatuses = ALMSettingsServices.getPrioritizationColumnSettings();

        System.assertEquals(newColumns.size(), savedStatuses.size(), 'Only columns specified should now exist');
        System.assertEquals(savedStatuses[0].Value__c, newColumns[0], 'Columns specified should be inserted in order');
        System.assertEquals(savedStatuses[1].Value__c, newColumns[1], 'Columns specified should be inserted in order');
    }

    static testMethod void getUserAssignments() {
        Backlog__c bklg = new Backlog__c();
        insert bklg;

        String userName = 'Bud Abbott';

        ALM_User__c user1 = new ALM_User__c(Name = userName);
        ALM_User__c user2 = new ALM_User__c(Name = 'Lou Costello');
        insert new ALM_User__c[]{user1, user2};

        Backlog_User__c bu = new Backlog_User__c(Backlog__c = bklg.Id, ALM_User__c = user1.Id);
        insert bu;

        Test.startTest();

            List<UserAssignment> users = BacklogItemServices.getUserAssignments(''+bklg.Id);

        Test.stopTest();

        System.assertEquals(1, users.size(), 'It should return users assigned to the given backlog.');
        System.assertEquals(userName, users[0].name, 'It should return users assigned to the given backlog.');
    }

    static testMethod void testGetBacklogItemIdsWithLatestSprintIds_OneSprint(){

        setupTestSprintItemData(true);

        Test.startTest();
            Map<Id, Id> backlogToSprintId = BacklogItemServices.getBacklogItemIdsWithLatestSprintIds(UnitTest.getIds('Backlogs'));
        Test.stopTest();

        System.assertEquals(UnitTest.getIds('Backlogs'), backlogToSprintId.keySet(), 'We expect to get back all Backlog Item attached to the Sprint Items');
        for (Sprint_Item__c sprintItem : (List<Sprint_Item__c>)UnitTest.get('Sprint Items').getList()){
            System.assertEquals(sprintItem.Sprint__c, backlogToSprintId.get(sprintItem.Backlog__c), 'We expect to get back a map of Backlog Id to latest Sprint Id');
        }
    }

    static testMethod void testGetBacklogItemIdsWithLatestSprintIds(){

        Sprint__c sprint1 = new Sprint__c(Name = 'Test Sprint 1');
        Sprint__c sprint2 = new Sprint__c(Name = 'Test Sprint 1', Start_Date__c=Date.today());
        Sprint__c sprint3 = new Sprint__c(Name = 'Test Sprint 1', Start_Date__c=Date.today().addDays(14));
        insert new List<Sprint__c>{sprint1, sprint2, sprint3};

        Backlog__c backlogItem = TestingUtils.createBacklogItem(1);

        TestingUtils.createSprintItems(sprint1.Id, new List<Backlog__c>{backlogItem});
        TestingUtils.createSprintItems(sprint2.Id, new List<Backlog__c>{backlogItem});
        TestingUtils.createSprintItems(sprint3.Id, new List<Backlog__c>{backlogItem});

        Test.startTest();
            Map<Id, Id> backlogToSprintId = BacklogItemServices.getBacklogItemIdsWithLatestSprintIds(new Set<Id>{backlogItem.Id});
        Test.stopTest();

        System.assert(backlogToSprintId.containsKey(backlogItem.Id), 'We expect to get back the Backlog Item in the map.');
        System.assertEquals(sprint3.Id, backlogToSprintId.get(backlogItem.Id), 'We expect to get back the latest sprint for each Backlog Item in the map.');
    }

     static testMethod void testGetBacklogItemIdsWithLatestSprintIds_NoSprintItem(){

        Sprint__c sprint1 = new Sprint__c(Name = 'Test Sprint 1');
        insert new List<Sprint__c>{sprint1};

        Backlog__c backlogItem = TestingUtils.createBacklogItem(1);

        Test.startTest();
            Map<Id, Id> backlogToSprintId = BacklogItemServices.getBacklogItemIdsWithLatestSprintIds(new Set<Id>{backlogItem.Id});
        Test.stopTest();

        System.assert(backlogToSprintId.containsKey(backlogItem.Id), 'We expect to get back the Backlog Item in the map.');
        System.assertEquals(null, backlogToSprintId.get(backlogItem.Id), 'We expect to get back a null id for the latest sprint when no sprint items exist');
    }

    static testMethod void testPopulateCurrentSprintOnBacklogs(){
        setupTestSprintItemData(true);

        Map<Id, Id> backlogToSprintId = new Map<Id, Id>();
        for (Id bklgId : UnitTest.getIds('Backlogs')){
            backlogToSprintId.put(bklgId, UnitTest.get('Sprint 2').getList()[0].Id);
        }

        Test.startTest();
            List<Backlog__c> updatedBklgs = BacklogItemServices.populateCurrentSprintOnBacklogs(backlogToSprintId);
        Test.stopTest();

        Map<Id, Backlog__c> updatedBklgMap = new Map<Id, Backlog__c>(updatedBklgs);
        Set<Id> backlogsOnSprint1 = Pluck.ids(Sprint_Item__c.Backlog__c, (List<Sprint_Item__c>)UnitTest.get('Sprint Items in Sprint 1').getList());
        System.assertEquals(updatedBklgMap.keySet(), backlogsOnSprint1, 'We expect to get back all Backlog Item that have changed Sprints');
        System.assertEquals(new Set<Id>{UnitTest.get('Sprint 2').getList()[0].Id}, Pluck.ids(Backlog__c.Current_Sprint__c, updatedBklgs),
            'We expect each backlog item to be updated to sprint 2');
    }

    static testMethod void testUpdateBacklogs(){

        final String TEST_BKLG_STATUS = 'TEST_STATUS';

        setupTestSprintItemData(true);

        List<Backlog__c> bklgUpdates = new List<Backlog__c>();
        for (Id bklgId : UnitTest.getIds('Backlogs')){
            bklgUpdates.add(new Backlog__c(Id=bklgId, Status__c =TEST_BKLG_STATUS));
        }

        Test.startTest();
            BacklogItemServices.updateBacklogs(bklgUpdates);
        Test.stopTest();

        bklgUpdates = [Select Status__c from Backlog__c Where Id in :UnitTest.getIds('Backlogs')];

        System.assertEquals(UnitTest.getIds('Backlogs').size(), bklgUpdates.size(),
            'We expect to get back the correct number of backlog items.');
        for (Backlog__c bklg : bklgUpdates){
            System.assertEquals(TEST_BKLG_STATUS, bklg.Status__c, 'We expect the Backlog Status to be updated.');
        }
    }

    static testMethod void testUpdateBacklogs_errorHandling(){

        Test.setMock(HttpCalloutMock.class, new MockWebAssemblerAPI(MockWebAssemblerAPI.LOG_ACTION));

        final String TEST_BKLG_STATUS = 'TEST_STATUS';

        setupTestSprintItemData(true);

        List<Backlog__c> bklgUpdates = new List<Backlog__c>();
        for (Id bklgId : UnitTest.getIds('Backlogs')){
            bklgUpdates.add(new Backlog__c(Id=bklgId, Status__c =TEST_BKLG_STATUS));
        }
        bklgUpdates[0].Id = null;

        Test.startTest();
            BacklogItemServices.updateBacklogs(bklgUpdates);
        Test.stopTest();

        bklgUpdates = [Select Status__c from Backlog__c Where Id in :UnitTest.getIds('Backlogs')];

        System.assertEquals(UnitTest.getIds('Backlogs').size(), bklgUpdates.size(),
            'We expect to get back the correct number of backlog items.');
        for (Backlog__c bklg : bklgUpdates){
            System.assertNotEquals(TEST_BKLG_STATUS, bklg.Status__c, 'We expect the Backlog Status to NOT be updated.');
        }
    }

    static testMethod void filterBacklogItemsWithModifiedSprints_notEmpty() {
        Sprint__c sprint0 = new Sprint__c();
        Sprint__c sprint1 = new Sprint__c();
        insert new List<Sprint__c>{ sprint0, sprint1 };

        Backlog__c backlogItemBefore0 = new Backlog__c(Current_Sprint__c = sprint0.Id);
        Backlog__c backlogItemBefore1 = new Backlog__c(Current_Sprint__c = sprint0.Id);
        Backlog__c backlogItemBefore2 = new Backlog__c(Current_Sprint__c = sprint0.Id);
        Backlog__c backlogItemBefore3 = new Backlog__c();
        insert new List<Backlog__c>{ backlogItemBefore0, backlogItemBefore1, backlogItemBefore2, backlogItemBefore3 };

        Map<Id, Backlog__c> oldMap = new Map<Id, Backlog__c>{
            backlogItemBefore0.Id => backlogItemBefore0,
            backlogItemBefore1.Id => backlogItemBefore1,
            backlogItemBefore2.Id => backlogItemBefore2,
            backlogItemBefore3.Id => backlogItemBefore3
        };

        Backlog__c backlogItemAfter0 = new Backlog__c(Id = backlogItemBefore0.Id, Current_Sprint__c = sprint0.Id);
        Backlog__c backlogItemAfter1 = new Backlog__c(Id = backlogItemBefore1.Id, Current_Sprint__c = sprint1.Id);
        Backlog__c backlogItemAfter2 = new Backlog__c(Id = backlogItemBefore2.Id, Current_Sprint__c = null);
        Backlog__c backlogItemAfter3 = new Backlog__c(Id = backlogItemBefore3.Id, Current_Sprint__c = sprint1.Id);
        Backlog__c backlogItemAfter4 = new Backlog__c(Current_Sprint__c = sprint0.Id);

        List<Backlog__c> newList = new List<Backlog__c>{ backlogItemAfter0, backlogItemAfter1, backlogItemAfter2, backlogItemAfter3, backlogItemAfter4 };

        Test.startTest();

            List<Backlog__c> filteredList = BacklogItemServices.filterBacklogItemsWithModifiedSprints(oldMap, newList);

        Test.stopTest();

        System.assertEquals(4, filteredList.size(), 'There should be four items in the filtered list.');

        System.assertEquals(backlogItemAfter1.Id, filteredList[0].Id, 'The backlog item IDs should match.');
        System.assertEquals(sprint1.Id, filteredList[0].Current_Sprint__c, 'The sprint IDs should match.');

        System.assertEquals(backlogItemAfter2.Id, filteredList[1].Id, 'The backlog item IDs should match.');
        System.assertEquals(null, filteredList[1].Current_Sprint__c, 'The sprint IDs should match.');

        System.assertEquals(backlogItemAfter3.Id, filteredList[2].Id, 'The backlog item IDs should match.');
        System.assertEquals(sprint1.Id, filteredList[2].Current_Sprint__c, 'The sprint IDs should match.');

        System.assertEquals(backlogItemAfter4.Id, filteredList[3].Id, 'The backlog item IDs should match.');
        System.assertEquals(sprint0.Id, filteredList[3].Current_Sprint__c, 'The sprint IDs should match.');
    }

    static testMethod void filterBacklogItemsWithModifiedSprints_empty() {
        Sprint__c sprint0 = new Sprint__c();
        Sprint__c sprint1 = new Sprint__c();
        insert new List<Sprint__c>{ sprint0, sprint1 };

        Backlog__c backlogItem0 = new Backlog__c(Current_Sprint__c = sprint0.Id);
        Backlog__c backlogItem1 = new Backlog__c(Current_Sprint__c = sprint1.Id);
        Backlog__c backlogItem2 = new Backlog__c(Current_Sprint__c = null);
        Backlog__c backlogItem3 = new Backlog__c(Current_Sprint__c = sprint1.Id);
        Backlog__c backlogItem4 = new Backlog__c(Current_Sprint__c = sprint0.Id);

        List<Backlog__c> newList = new List<Backlog__c>{ backlogItem0, backlogItem1, backlogItem2, backlogItem3, backlogItem4 };

        Test.startTest();

            List<Backlog__c> filteredList = BacklogItemServices.filterBacklogItemsWithModifiedSprints(null, newList);

        Test.stopTest();

        System.assertEquals(5, filteredList.size(), 'There should be five items in the filtered list.');

        System.assertEquals(backlogItem0.Id, filteredList[0].Id, 'The backlog item IDs should match.');
        System.assertEquals(sprint0.Id, filteredList[0].Current_Sprint__c, 'The sprint IDs should match.');

        System.assertEquals(backlogItem1.Id, filteredList[1].Id, 'The backlog item IDs should match.');
        System.assertEquals(sprint1.Id, filteredList[1].Current_Sprint__c, 'The sprint IDs should match.');

        System.assertEquals(backlogItem2.Id, filteredList[2].Id, 'The backlog item IDs should match.');
        System.assertEquals(null, filteredList[2].Current_Sprint__c, 'The sprint IDs should match.');

        System.assertEquals(backlogItem3.Id, filteredList[3].Id, 'The backlog item IDs should match.');
        System.assertEquals(sprint1.Id, filteredList[3].Current_Sprint__c, 'The sprint IDs should match.');

        System.assertEquals(backlogItem4.Id, filteredList[4].Id, 'The backlog item IDs should match.');
        System.assertEquals(sprint0.Id, filteredList[4].Current_Sprint__c, 'The sprint IDs should match.');
    }

    static testMethod void testUpdateStatusOnSprintItems_noUpdate() {
        String status = 'New';

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('New', 0),
            ALMSettingsServices.buildSprintLaneSetting('Open', 1),
            ALMSettingsServices.buildSprintLaneSetting('In-Progress', 2),
            ALMSettingsServices.buildSprintLaneSetting('Dev Complete', 3),
            ALMSettingsServices.buildSprintLaneSetting('Released', 4)
        };
        insert settings;

        Sprint__c sprintNotCompleted = new Sprint__c(Status__c = SprintModel.IN_PROGRESS_STATUS);
        Sprint__c sprintCompleted = new Sprint__c(Status__c = SprintModel.COMPLETED_STATUS);
        insert new List<Sprint__c>{ sprintNotCompleted, sprintCompleted };
        Backlog__c backlogItem = new Backlog__c(Status__c = status);
        insert backlogItem;
        Sprint_Item__c sprintItemNotCompletedSprint = new Sprint_Item__c(Status__c = status, Backlog__c = backlogItem.Id, Sprint__c = sprintNotCompleted.Id);
        Sprint_Item__c sprintItemCompletedSprint = new Sprint_Item__c(Status__c = status, Backlog__c = backlogItem.Id, Sprint__c = sprintCompleted.Id);
        insert new List<Sprint_Item__c>{ sprintItemNotCompletedSprint, sprintItemCompletedSprint };

        Test.startTest();

            BacklogItemServices.updateStatusOnSprintItems(
                new List<Backlog__c>{ backlogItem },
                new Map<Id, Backlog__c>{ backlogItem.Id => backlogItem }
            );

        Test.stopTest();

        Map<Id, Sprint_Item__c> sprintItemsAfter = new Map<Id, Sprint_Item__c>([SELECT Status__c FROM Sprint_Item__c]);
        System.assertEquals(status, sprintItemsAfter.get(sprintItemNotCompletedSprint.Id).Status__c, 'The sprint item status for the completed sprint should not have changed.');
        System.assertEquals(status, sprintItemsAfter.get(sprintItemCompletedSprint.Id).Status__c, 'The sprint item status for the not-completed sprint should not have changed.');
    }

    static testMethod void testUpdateStatusOnSprintItems_update() {
        String statusBefore = 'New';
        String statusAfter = 'Open';

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('New', 0),
            ALMSettingsServices.buildSprintLaneSetting('Open', 1),
            ALMSettingsServices.buildSprintLaneSetting('In-Progress', 2),
            ALMSettingsServices.buildSprintLaneSetting('Dev Complete', 3),
            ALMSettingsServices.buildSprintLaneSetting('Released', 4)
        };
        insert settings;

        Sprint__c sprintNotCompleted = new Sprint__c(Status__c = SprintModel.IN_PROGRESS_STATUS);
        Sprint__c sprintCompleted = new Sprint__c(Status__c = SprintModel.COMPLETED_STATUS);
        insert new List<Sprint__c>{ sprintNotCompleted, sprintCompleted };
        Backlog__c backlogItemBefore = new Backlog__c(Status__c = statusBefore);
        insert backlogItemBefore;
        Backlog__c backlogItemAfter = new Backlog__c(Id = backlogItemBefore.Id, Status__c = statusAfter);
        Sprint_Item__c sprintItemNotCompletedSprint = new Sprint_Item__c(Status__c = statusBefore, Backlog__c = backlogItemBefore.Id, Sprint__c = sprintNotCompleted.Id);
        Sprint_Item__c sprintItemCompletedSprint = new Sprint_Item__c(Status__c = statusBefore, Backlog__c = backlogItemBefore.Id, Sprint__c = sprintCompleted.Id);
        insert new List<Sprint_Item__c>{ sprintItemNotCompletedSprint, sprintItemCompletedSprint };

        Test.startTest();

            BacklogItemServices.updateStatusOnSprintItems(
                new List<Backlog__c>{ backlogItemAfter },
                new Map<Id, Backlog__c>{ backlogItemBefore.Id => backlogItemBefore }
            );

        Test.stopTest();

        Map<Id, Sprint_Item__c> sprintItemsAfter = new Map<Id, Sprint_Item__c>([SELECT Status__c FROM Sprint_Item__c]);
        System.assertEquals(statusBefore, sprintItemsAfter.get(sprintItemCompletedSprint.Id).Status__c, 'The sprint item status for the completed sprint should not have changed.');
        System.assertEquals(statusAfter, sprintItemsAfter.get(sprintItemNotCompletedSprint.Id).Status__c, 'The sprint item status for the not-completed sprint should have changed.');
    }

    private static testMethod void getBacklogAutoPrioritizationBehavior_universal_nullBehavior() {
        Backlog_Auto_Prioritization__c backlogAutoPrioritizationConfiguration = new Backlog_Auto_Prioritization__c(
            Name = 'Universal',
            Backlog_ID__c = BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            Prioritization_Behavior__c = null
        );
        insert backlogAutoPrioritizationConfiguration;

        Test.startTest();

            BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = BacklogItemServices.getBacklogAutoPrioritizationBehavior(backlogAutoPrioritizationConfiguration.Backlog_ID__c);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, behavior, 'The prioritization behavior should default to the "off" behavior.');
    }

    private static testMethod void getBacklogAutoPrioritizationBehavior_universal_invalidBehavior() {
        Backlog_Auto_Prioritization__c backlogAutoPrioritizationConfiguration = new Backlog_Auto_Prioritization__c(
            Name = 'Universal',
            Backlog_ID__c = BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            Prioritization_Behavior__c = 'Invalid'
        );
        insert backlogAutoPrioritizationConfiguration;

        Test.startTest();

            BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = BacklogItemServices.getBacklogAutoPrioritizationBehavior(backlogAutoPrioritizationConfiguration.Backlog_ID__c);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, behavior, 'The prioritization behavior default to the "off" behavior.');
    }

    private static testMethod void getBacklogAutoPrioritizationBehavior_universal_validBehavior_doesNotExist() {
        Test.startTest();

            BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = BacklogItemServices.getBacklogAutoPrioritizationBehavior(BacklogItemServices.UNIVERSAL_BACKLOG_ID);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF, behavior, 'The prioritization behavior default to the "off" behavior.');
    }

    private static testMethod void getBacklogAutoPrioritizationBehavior_universal_validBehavior_exists() {
        Backlog_Auto_Prioritization__c backlogAutoPrioritizationConfiguration = new Backlog_Auto_Prioritization__c(
            Name = 'Universal',
            Backlog_ID__c = BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            Prioritization_Behavior__c = 'TOP'
        );
        insert backlogAutoPrioritizationConfiguration;

        Test.startTest();

            BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = BacklogItemServices.getBacklogAutoPrioritizationBehavior(backlogAutoPrioritizationConfiguration.Backlog_ID__c);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP, behavior, 'The prioritization behavior should be set properly.');
    }


    private static testMethod void getBacklogAutoPrioritizationBehavior_custom_validBehavior_exists() {
        Id backlogId = TestingUtils.createRandomFakeSObjectId(Custom_Backlog__c.SObjectType);

        Backlog_Auto_Prioritization__c backlogAutoPrioritizationConfiguration = new Backlog_Auto_Prioritization__c(
            Name = 'Custom_' + backlogId,
            Backlog_ID__c = backlogId,
            Prioritization_Behavior__c = 'TOP'
        );
        insert backlogAutoPrioritizationConfiguration;

        Test.startTest();

            BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = BacklogItemServices.getBacklogAutoPrioritizationBehavior(backlogAutoPrioritizationConfiguration.Backlog_ID__c);

        Test.stopTest();

        System.assertEquals(BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP, behavior, 'The prioritization behavior should be set properly.');
    }

    private static testMethod void setBacklogAutoPrioritizationBehavior_universal_nullBehavior() {
        Id backlogId = BacklogItemServices.UNIVERSAL_BACKLOG_ID;
        BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = null;
        String name = 'Universal';

        Test.startTest();

            BacklogItemServices.setBacklogAutoPrioritizationBehavior(backlogId, behavior);

        Test.stopTest();

        List<Backlog_Auto_Prioritization__c> backlogAutoPrioritizationConfigurations = [SELECT Backlog_ID__c, Prioritization_Behavior__c FROM Backlog_Auto_Prioritization__c WHERE Name = :name];

        System.assertEquals(1, backlogAutoPrioritizationConfigurations.size(), 'The backlog auto-prioritization should exist.');
        System.assertEquals(backlogId, backlogAutoPrioritizationConfigurations[0].Backlog_ID__c, 'The backlog auto-prioritization backlog ID should be set properly.');
        System.assert('Off'.equalsIgnoreCase(backlogAutoPrioritizationConfigurations[0].Prioritization_Behavior__c), 'The backlog auto-prioritization behavior should be set properly.');
    }

    private static testMethod void setBacklogAutoPrioritizationBehavior_universal_validBehavior() {
        Id backlogId = BacklogItemServices.UNIVERSAL_BACKLOG_ID;
        BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP;
        String name = 'Universal';

        Test.startTest();

            BacklogItemServices.setBacklogAutoPrioritizationBehavior(backlogId, behavior);

        Test.stopTest();

        List<Backlog_Auto_Prioritization__c> backlogAutoPrioritizationConfigurations = [SELECT Backlog_ID__c, Prioritization_Behavior__c FROM Backlog_Auto_Prioritization__c WHERE Name = :name];

        System.assertEquals(1, backlogAutoPrioritizationConfigurations.size(), 'The backlog auto-prioritization should exist.');
        System.assertEquals(backlogId, backlogAutoPrioritizationConfigurations[0].Backlog_ID__c, 'The backlog auto-prioritization backlog ID should be set properly.');
        System.assert('Top'.equalsIgnoreCase(backlogAutoPrioritizationConfigurations[0].Prioritization_Behavior__c), 'The backlog auto-prioritization behavior should be set properly.');
    }

    private static testMethod void setBacklogAutoPrioritizationBehavior_custom_validBehavior() {
        Id backlogId = TestingUtils.createRandomFakeSObjectId(Custom_Backlog__c.SObjectType);
        BacklogAutoPrioritizationModel.PrioritizationBehavior behavior = BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP;
        String name = 'Custom_' + backlogId;

        Test.startTest();

            BacklogItemServices.setBacklogAutoPrioritizationBehavior(backlogId, behavior);

        Test.stopTest();

        List<Backlog_Auto_Prioritization__c> backlogAutoPrioritizationConfigurations = [SELECT Backlog_ID__c, Prioritization_Behavior__c FROM Backlog_Auto_Prioritization__c WHERE Name = :name];

        System.assertEquals(1, backlogAutoPrioritizationConfigurations.size(), 'The backlog auto-prioritization should exist.');
        System.assertEquals(backlogId, backlogAutoPrioritizationConfigurations[0].Backlog_ID__c, 'The backlog auto-prioritization backlog ID should be set properly.');
        System.assert('Top'.equalsIgnoreCase(backlogAutoPrioritizationConfigurations[0].Prioritization_Behavior__c), 'The backlog auto-prioritization behavior should be set properly.');
    }

    private static testMethod void setBacklogAutoPrioritizationBehavior_custom_validBehavior_alreadyExists() {
        Id backlogId = TestingUtils.createRandomFakeSObjectId(Custom_Backlog__c.SObjectType);
        BacklogAutoPrioritizationModel.PrioritizationBehavior behaviorEnum = BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP;
        String behaviorString = 'Top';
        String name = 'Custom_' + backlogId;

        Backlog_Auto_Prioritization__c backlogAutoPrioritizationConfiguration = new Backlog_Auto_Prioritization__c(
            Name = name,
            Backlog_ID__c = backlogId,
            Prioritization_Behavior__c = behaviorString
        );
        insert backlogAutoPrioritizationConfiguration;

        Test.startTest();

            BacklogItemServices.setBacklogAutoPrioritizationBehavior(backlogId, behaviorEnum);

        Test.stopTest();

        List<Backlog_Auto_Prioritization__c> backlogAutoPrioritizationConfigurations = [SELECT Backlog_ID__c, Prioritization_Behavior__c FROM Backlog_Auto_Prioritization__c WHERE Name = :name];

        System.assertEquals(1, backlogAutoPrioritizationConfigurations.size(), 'The backlog auto-prioritization should exist.');
        System.assertEquals(backlogId, backlogAutoPrioritizationConfigurations[0].Backlog_ID__c, 'The backlog auto-prioritization backlog ID should be set properly.');
        System.assert(behaviorString.equalsIgnoreCase(backlogAutoPrioritizationConfigurations[0].Prioritization_Behavior__c), 'The backlog auto-prioritization behavior should be set properly.');
    }

    private static List<Backlog__c> autoPrioritizeBacklogItems_universal_assertAndRefresh(Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems) {
        return autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, null);
    }

    private static List<Backlog__c> autoPrioritizeBacklogItems_universal_assertAndRefresh(Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems, List<Backlog__c> existingBacklogItems) {
        Test.startTest();

            BacklogItemServices.autoPrioritizeBacklogItems(backlogAutoPrioritizationModelToBacklogItems);

        Test.stopTest();

        if (existingBacklogItems == null) {
            existingBacklogItems = new List<Backlog__c>();
        }
        return [SELECT Priority__c, Custom_Backlog__c, Custom_Priority__c FROM Backlog__c WHERE Id IN :Pluck.ids(existingBacklogItems) ORDER BY Priority__c ASC NULLS FIRST];
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_noAutoPrioritize_insertOne() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(1);

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(1);
        existingBacklogItems[0].Priority__c = 1;
        insert existingBacklogItems;

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                null => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog item should be prioritized to the top of the universal backlog.');
        System.assertEquals(null, newBacklogItems[0].Priority__c, 'The new backlog item should be unprioritized in the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_autoPrioritizeDefault_insertOne() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(1);

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(1);
        existingBacklogItems[0].Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            (BacklogAutoPrioritizationModel.PrioritizationBehavior)null
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog item should be prioritized to the top of the universal backlog.');
        System.assertEquals(null, newBacklogItems[0].Priority__c, 'The new backlog item should be unprioritized in the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_autoPrioritizeOff_insertOne() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(1);

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(1);
        existingBacklogItems[0].Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog item should be prioritized to the top of the universal backlog.');
        System.assertEquals(null, newBacklogItems[0].Priority__c, 'The new backlog item should be unprioritized in the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_autoPrioritizeOff_insertMultiple() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(2);

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(1);
        existingBacklogItems[0].Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog item should be prioritized to the top of the universal backlog.');
        System.assertEquals(null, newBacklogItems[0].Priority__c, 'The new backlog items should be unprioritized in the universal backlog.');
        System.assertEquals(null, newBacklogItems[1].Priority__c, 'The new backlog items should be unprioritized in the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_autoPrioritizeTop_insertOne_noneExisting() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(1);

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems);

        System.assertEquals(0, refreshedExistingBacklogItems.size(), 'There should be no existing backlog items.');
        System.assertNotEquals(null, newBacklogItems[0].Priority__c, 'The new backlog item should be prioritized to the top of the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_autoPrioritizeTop_insertOne() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(1);

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(1);
        existingBacklogItems[0].Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog item should be prioritized beneath the new backlog item in the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c - 1, newBacklogItems[0].Priority__c, 'The new backlog item should be prioritized to the top of the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_autoPrioritizeTop_insertOne_highestExistingPriorityLessThanOne() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(1);

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(1);
        existingBacklogItems[0].Priority__c = 0;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog item should be prioritized below the new backlog item in the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c - 1, newBacklogItems[0].Priority__c, 'The new backlog item should be prioritized to the top of the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_autoPrioritizeTop_insertMultiple() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(2);

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(1);
        existingBacklogItems[0].Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog item should be prioritized beneath the new backlog item in the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c - 2, newBacklogItems[0].Priority__c, 'The new backlog items should be prioritized to the top of the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c - 1, newBacklogItems[1].Priority__c, 'The new backlog items should be prioritized to the top of the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_autoPrioritizeBottom_insertOne() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(1);

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(1);
        existingBacklogItems[0].Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog item should be prioritized above the new backlog item in the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c + 1, newBacklogItems[0].Priority__c, 'The new backlog item should be prioritized to the bottom of the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_autoPrioritizeBottom_insertOne_noneExisting() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(1);

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems);

        System.assertEquals(0, refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertNotEquals(null, newBacklogItems[0].Priority__c, 'The new backlog item should be prioritized to the bottom of the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_universal_autoPrioritizeBottom_insertMultiple() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(2);

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(1);
        existingBacklogItems[0].Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => newBacklogItems
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog item should be prioritized above the new backlog item in the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c + 1, newBacklogItems[0].Priority__c, 'The new backlog items should be prioritized to the bottom of the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c + 2, newBacklogItems[1].Priority__c, 'The new backlog items should be prioritized to the bottom of the universal backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_custom_autoPrioritizeOff_insertMultiple() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        Custom_Backlog__c backlog = new Custom_Backlog__c();
        insert backlog;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(2);
        newBacklogItems[1].Custom_Backlog__c = backlog.Id;

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(2);
        existingBacklogItems[0].Priority__c = 1;
        existingBacklogItems[1].Priority__c = 2;
        existingBacklogItems[1].Custom_Backlog__c = backlog.Id;
        existingBacklogItems[1].Custom_Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF
        );
        BacklogAutoPrioritizationModel customConfiguration = new BacklogAutoPrioritizationModel(
            backlog.Id,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.OFF
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => new List<Backlog__c>{ newBacklogItems[0], newBacklogItems[1] },
                customConfiguration => new List<Backlog__c>{ newBacklogItems[1] }
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog item should be prioritized to the top of the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Custom_Backlog__c, refreshedExistingBacklogItems[0].Custom_Backlog__c, 'The existing backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[0].Custom_Priority__c, refreshedExistingBacklogItems[0].Custom_Priority__c, 'The existing backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[1].Priority__c, refreshedExistingBacklogItems[1].Priority__c, 'The existing backlog item should be prioritized to the top of the universal backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Backlog__c, refreshedExistingBacklogItems[1].Custom_Backlog__c, 'The existing backlog item should be associated with the proper custom backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Priority__c, refreshedExistingBacklogItems[1].Custom_Priority__c, 'The existing backlog item should be prioritized to the top of the proper custom backlog.');
        System.assertEquals(null, newBacklogItems[0].Priority__c, 'The new backlog item should be unprioritized in the universal backlog.');
        System.assertEquals(null, newBacklogItems[0].Custom_Backlog__c, 'The new backlog item should not be associated with any custom backlog.');
        System.assertEquals(null, newBacklogItems[0].Custom_Priority__c, 'The new backlog item should not be associated with any custom backlog.');
        System.assertEquals(null, newBacklogItems[1].Priority__c, 'The new backlog item should be unprioritized in the universal backlog.');
        System.assertEquals(backlog.Id, newBacklogItems[1].Custom_Backlog__c, 'The new backlog item should be associated with the proper custom backlog.');
        System.assertEquals(null, newBacklogItems[1].Custom_Priority__c, 'The new backlog item should be unprioritized in the custom backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_custom_autoPrioritizeTop_insertOne_noneExisting() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        Custom_Backlog__c backlog = new Custom_Backlog__c();
        insert backlog;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(1);
        newBacklogItems[0].Custom_Backlog__c = backlog.Id;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP
        );
        BacklogAutoPrioritizationModel customConfiguration = new BacklogAutoPrioritizationModel(
            backlog.Id,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => new List<Backlog__c>{ newBacklogItems[0] },
                customConfiguration => new List<Backlog__c>{ newBacklogItems[0] }
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems);

        System.assertEquals(0, refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertNotEquals(null, newBacklogItems[0].Priority__c, 'The new backlog item should be prioritized to the top of the universal backlog.');
        System.assertEquals(backlog.Id, newBacklogItems[0].Custom_Backlog__c, 'The new backlog item should be associated with the proper custom backlog.');
        System.assertNotEquals(null, newBacklogItems[0].Custom_Priority__c, 'The new backlog item should be prioritized to the top of the proper custom backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_custom_autoPrioritizeTop_insertMultiple() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        Custom_Backlog__c backlog = new Custom_Backlog__c();
        insert backlog;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(2);
        newBacklogItems[1].Custom_Backlog__c = backlog.Id;

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(2);
        existingBacklogItems[0].Priority__c = 1;
        existingBacklogItems[1].Priority__c = 2;
        existingBacklogItems[1].Custom_Backlog__c = backlog.Id;
        existingBacklogItems[1].Custom_Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP
        );
        BacklogAutoPrioritizationModel customConfiguration = new BacklogAutoPrioritizationModel(
            backlog.Id,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => new List<Backlog__c>{ newBacklogItems[0], newBacklogItems[1] },
                customConfiguration => new List<Backlog__c>{ newBacklogItems[1] }
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog items should be prioritized below the new backlog items in the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Custom_Backlog__c, refreshedExistingBacklogItems[0].Custom_Backlog__c, 'The existing backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[0].Custom_Priority__c, refreshedExistingBacklogItems[0].Custom_Priority__c, 'The existing backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[1].Priority__c, refreshedExistingBacklogItems[1].Priority__c, 'The existing backlog items should be prioritized below the new backlog items in the universal backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Backlog__c, refreshedExistingBacklogItems[1].Custom_Backlog__c, 'The existing backlog item should be associated with the proper custom backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Priority__c, refreshedExistingBacklogItems[1].Custom_Priority__c, 'The existing backlog item should be prioritized below the new backlog item in proper custom backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c - 2, newBacklogItems[0].Priority__c, 'The new backlog items should be prioritized to the top of the universal backlog.');
        System.assertEquals(null, newBacklogItems[0].Custom_Backlog__c, 'The new backlog item should not be associated with any custom backlog.');
        System.assertEquals(null, newBacklogItems[0].Custom_Priority__c, 'The new backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c - 1, newBacklogItems[1].Priority__c, 'The new backlog items should be prioritized to the top of the universal backlog.');
        System.assertEquals(backlog.Id, newBacklogItems[1].Custom_Backlog__c, 'The new backlog item should be associated with the proper custom backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Priority__c - 1, newBacklogItems[1].Custom_Priority__c, 'The new backlog item should be prioritized to the top of the proper custom backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_custom_autoPrioritizeBottom_insertOne_noneExisting() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        Custom_Backlog__c backlog = new Custom_Backlog__c();
        insert backlog;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(1);
        newBacklogItems[0].Custom_Backlog__c = backlog.Id;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM
        );
        BacklogAutoPrioritizationModel customConfiguration = new BacklogAutoPrioritizationModel(
            backlog.Id,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => new List<Backlog__c>{ newBacklogItems[0] },
                customConfiguration => new List<Backlog__c>{ newBacklogItems[0] }
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems);

        System.assertEquals(0, refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertNotEquals(null, newBacklogItems[0].Priority__c, 'The new backlog items should be prioritized to the top of the universal backlog.');
        System.assertEquals(backlog.Id, newBacklogItems[0].Custom_Backlog__c, 'The new backlog item should not be associated with any custom backlog.');
        System.assertNotEquals(null, newBacklogItems[0].Custom_Priority__c, 'The new backlog item should not be associated with any custom backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_custom_autoPrioritizeBottom_insertMultiple() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        Custom_Backlog__c backlog = new Custom_Backlog__c();
        insert backlog;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(2);
        newBacklogItems[1].Custom_Backlog__c = backlog.Id;

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(2);
        existingBacklogItems[0].Priority__c = 1;
        existingBacklogItems[1].Priority__c = 2;
        existingBacklogItems[1].Custom_Backlog__c = backlog.Id;
        existingBacklogItems[1].Custom_Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM
        );
        BacklogAutoPrioritizationModel customConfiguration = new BacklogAutoPrioritizationModel(
            backlog.Id,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => new List<Backlog__c>{ newBacklogItems[0], newBacklogItems[1] },
                customConfiguration => new List<Backlog__c>{ newBacklogItems[1] }
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog items should be prioritized below the new backlog items in the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Custom_Backlog__c, refreshedExistingBacklogItems[0].Custom_Backlog__c, 'The existing backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[0].Custom_Priority__c, refreshedExistingBacklogItems[0].Custom_Priority__c, 'The existing backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[1].Priority__c, refreshedExistingBacklogItems[1].Priority__c, 'The existing backlog items should be prioritized below the new backlog items in the universal backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Backlog__c, refreshedExistingBacklogItems[1].Custom_Backlog__c, 'The existing backlog item should be associated with the proper custom backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Priority__c, refreshedExistingBacklogItems[1].Custom_Priority__c, 'The existing backlog item should be prioritized below the new backlog item in proper custom backlog.');
        System.assertEquals(existingBacklogItems[1].Priority__c + 1, newBacklogItems[0].Priority__c, 'The new backlog items should be prioritized to the top of the universal backlog.');
        System.assertEquals(null, newBacklogItems[0].Custom_Backlog__c, 'The new backlog item should not be associated with any custom backlog.');
        System.assertEquals(null, newBacklogItems[0].Custom_Priority__c, 'The new backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[1].Priority__c + 2, newBacklogItems[1].Priority__c, 'The new backlog items should be prioritized to the top of the universal backlog.');
        System.assertEquals(backlog.Id, newBacklogItems[1].Custom_Backlog__c, 'The new backlog item should be associated with the proper custom backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Priority__c + 1, newBacklogItems[1].Custom_Priority__c, 'The new backlog item should be prioritized to the bottom of the proper custom backlog.');
    }

    private static testMethod void autoPrioritizeBacklogItems_custom_autoPrioritizeMixed_insertMultiple() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        Custom_Backlog__c backlog = new Custom_Backlog__c();
        insert backlog;

        List<Backlog__c> newBacklogItems = TestingUtils.buildBacklogItems(2);
        newBacklogItems[1].Custom_Backlog__c = backlog.Id;

        List<Backlog__c> existingBacklogItems = TestingUtils.buildBacklogItems(2);
        existingBacklogItems[0].Priority__c = 1;
        existingBacklogItems[1].Priority__c = 2;
        existingBacklogItems[1].Custom_Backlog__c = backlog.Id;
        existingBacklogItems[1].Custom_Priority__c = 1;
        insert existingBacklogItems;

        BacklogAutoPrioritizationModel universalConfiguration = new BacklogAutoPrioritizationModel(
            BacklogItemServices.UNIVERSAL_BACKLOG_ID,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.TOP
        );
        BacklogAutoPrioritizationModel customConfiguration = new BacklogAutoPrioritizationModel(
            backlog.Id,
            BacklogAutoPrioritizationModel.PrioritizationBehavior.BOTTOM
        );

        Map<BacklogAutoPrioritizationModel, List<Backlog__c>> backlogAutoPrioritizationModelToBacklogItems =
            new Map<BacklogAutoPrioritizationModel, List<Backlog__c>>{
                universalConfiguration => new List<Backlog__c>{ newBacklogItems[0], newBacklogItems[1] },
                customConfiguration => new List<Backlog__c>{ newBacklogItems[1] }
            };

        List<Backlog__c> refreshedExistingBacklogItems = autoPrioritizeBacklogItems_universal_assertAndRefresh(backlogAutoPrioritizationModelToBacklogItems, existingBacklogItems);

        System.assertEquals(existingBacklogItems.size(), refreshedExistingBacklogItems.size(), 'The proper number of existing backlog items should be retrieved.');
        System.assertEquals(existingBacklogItems[0].Priority__c, refreshedExistingBacklogItems[0].Priority__c, 'The existing backlog items should be prioritized below the new backlog items in the universal backlog.');
        System.assertEquals(existingBacklogItems[0].Custom_Backlog__c, refreshedExistingBacklogItems[0].Custom_Backlog__c, 'The existing backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[0].Custom_Priority__c, refreshedExistingBacklogItems[0].Custom_Priority__c, 'The existing backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[1].Priority__c, refreshedExistingBacklogItems[1].Priority__c, 'The existing backlog items should be prioritized below the new backlog items in the universal backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Backlog__c, refreshedExistingBacklogItems[1].Custom_Backlog__c, 'The existing backlog item should be associated with the proper custom backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Priority__c, refreshedExistingBacklogItems[1].Custom_Priority__c, 'The existing backlog item should be prioritized below the new backlog item in proper custom backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c - 2, newBacklogItems[0].Priority__c, 'The new backlog items should be prioritized to the top of the universal backlog.');
        System.assertEquals(null, newBacklogItems[0].Custom_Backlog__c, 'The new backlog item should not be associated with any custom backlog.');
        System.assertEquals(null, newBacklogItems[0].Custom_Priority__c, 'The new backlog item should not be associated with any custom backlog.');
        System.assertEquals(existingBacklogItems[0].Priority__c - 1, newBacklogItems[1].Priority__c, 'The new backlog items should be prioritized to the top of the universal backlog.');
        System.assertEquals(backlog.Id, newBacklogItems[1].Custom_Backlog__c, 'The new backlog item should be associated with the proper custom backlog.');
        System.assertEquals(existingBacklogItems[1].Custom_Priority__c + 1, newBacklogItems[1].Custom_Priority__c, 'The new backlog item should be prioritized to the bottom of the proper custom backlog.');
    }

}