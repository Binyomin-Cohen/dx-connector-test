@isTest
private class TestSprintHomeController {
    @isTest
    private static void constructor_backlog_noCustomSetting_defaultToUniversal() {
        String backlogName = 'Test Backlog';

        Custom_Backlog__c backlog = new Custom_Backlog__c(Name = backlogName, Universal__c = true);
        insert backlog;

        Test.startTest();

            SprintHomeController controller = new SprintHomeController();

        Test.stopTest();

        System.assertEquals(BacklogManagementHomeController.MASTER_BACKLOG_RECORD_ID, controller.backlogId, 'The proper backlog ID should be set.');
        System.assertEquals(backlogName, controller.backlogName, 'The proper backlog name should be set.');
        System.assertEquals(1, controller.backlogs.size(), 'The proper number of backlogs should be loaded.');
        System.assertEquals(controller.backlogs[0].getValue(), backlog.Id, 'The proper backlogs should be loaded.');
        System.assertEquals(controller.backlogs[0].getLabel(), backlog.Name, 'The proper backlogs should be loaded.');
    }

    @isTest
    private static void constructor_backlog_withCustomSetting_defaultToUniversal() {
        String backlogName = 'Test Backlog';

        Custom_Backlog__c backlog = new Custom_Backlog__c(Name = backlogName, Universal__c = true);
        insert backlog;

        insert new User_Preferences__c(SetupOwnerId = UserInfo.getUserId());

        Test.startTest();

            SprintHomeController controller = new SprintHomeController();

        Test.stopTest();

        System.assertEquals(BacklogManagementHomeController.MASTER_BACKLOG_RECORD_ID, controller.backlogId, 'The proper backlog ID should be set.');
        System.assertEquals(backlogName, controller.backlogName, 'The proper backlog name should be set.');
        System.assertEquals(1, controller.backlogs.size(), 'The proper number of backlogs should be loaded.');
        System.assertEquals(controller.backlogs[0].getValue(), backlog.Id, 'The proper backlogs should be loaded.');
        System.assertEquals(controller.backlogs[0].getLabel(), backlog.Name, 'The proper backlogs should be loaded.');
    }

    @isTest
    private static void constructor_backlog_withCustomSetting_defaultToDefaultCustom() {
        String universalBacklogName = 'Test Universal Backlog';
        String customBacklogName = 'Test Custom Backlog';

        Custom_Backlog__c universalBacklog = new Custom_Backlog__c(Name = universalBacklogName, Universal__c = true);
        insert universalBacklog;
        Custom_Backlog__c customBacklog = new Custom_Backlog__c(Name = customBacklogName, Universal__c = false);
        insert customBacklog;

        insert new User_Preferences__c(SetupOwnerId = UserInfo.getUserId(), Default_Custom_Backlog_Id__c = customBacklog.Id);

        Test.startTest();

            SprintHomeController controller = new SprintHomeController();

        Test.stopTest();

        System.assertEquals(customBacklog.Id, controller.backlogId, 'The proper backlog ID should be set.');
        System.assertEquals(customBacklogName, controller.backlogName, 'The proper backlog name should be set.');
        System.assertEquals(2, controller.backlogs.size(), 'The proper number of backlogs should be loaded.');
        System.assertEquals(controller.backlogs[0].getValue(), customBacklog.Id, 'The proper backlogs should be loaded.');
        System.assertEquals(controller.backlogs[0].getLabel(), customBacklog.Name, 'The proper backlogs should be loaded.');
        System.assertEquals(controller.backlogs[1].getValue(), universalBacklog.Id, 'The proper backlogs should be loaded.');
        System.assertEquals(controller.backlogs[1].getLabel(), universalBacklog.Name, 'The proper backlogs should be loaded.');
    }

    @isTest
    private static void constructor_backlog_withCustomSetting_sprintHomeCustom() {
        String universalBacklogName = 'Test Universal Backlog';
        String defaultCustomBacklogName = 'Test Default Custom Backlog';
        String sprintHomeCustomBacklogName = 'Test Sprint Home Custom Backlog';

        Custom_Backlog__c universalBacklog = new Custom_Backlog__c(Name = universalBacklogName, Universal__c = true);
        insert universalBacklog;
        Custom_Backlog__c defaultCustomBacklog = new Custom_Backlog__c(Name = defaultCustomBacklogName, Universal__c = false);
        insert defaultCustomBacklog;
        Custom_Backlog__c sprintHomeCustomBacklog = new Custom_Backlog__c(Name = sprintHomeCustomBacklogName, Universal__c = false);
        insert sprintHomeCustomBacklog;

        insert new User_Preferences__c(SetupOwnerId = UserInfo.getUserId(), Sprint_Home_Default_Backlog_ID__c = sprintHomeCustomBacklog.Id);

        Test.startTest();

            SprintHomeController controller = new SprintHomeController();

        Test.stopTest();

        System.assertEquals(sprintHomeCustomBacklog.Id, controller.backlogId, 'The proper backlog ID should be set.');
        System.assertEquals(sprintHomeCustomBacklogName, controller.backlogName, 'The proper backlog name should be set.');
        System.assertEquals(3, controller.backlogs.size(), 'The proper number of backlogs should be loaded.');
        System.assertEquals(controller.backlogs[0].getValue(), defaultCustomBacklog.Id, 'The proper backlogs should be loaded.');
        System.assertEquals(controller.backlogs[0].getLabel(), defaultCustomBacklog.Name, 'The proper backlogs should be loaded.');
        System.assertEquals(controller.backlogs[1].getValue(), sprintHomeCustomBacklog.Id, 'The proper backlogs should be loaded.');
        System.assertEquals(controller.backlogs[1].getLabel(), sprintHomeCustomBacklog.Name, 'The proper backlogs should be loaded.');
        System.assertEquals(controller.backlogs[2].getValue(), universalBacklog.Id, 'The proper backlogs should be loaded.');
        System.assertEquals(controller.backlogs[2].getLabel(), universalBacklog.Name, 'The proper backlogs should be loaded.');
    }

    static testMethod void testCreateSprint() {
        String sprintName = 'August sprint 1';

        Test.startTest();

            String sprintId = SprintHomeController.createSprint( sprintName );

        Test.stopTest();

        Sprint__c createdSprint = [SELECT Name, Status__c FROM Sprint__c WHERE Id = :sprintId];

        System.assertEquals(sprintName, createdSprint.Name, 'A sprint should have been created with the requested name.');
        System.assertEquals(SprintModel.NOT_STARTED_STATUS, createdSprint.Status__c, 'A sprint should have been created with a not started status.');
    }

    static testMethod void testDeleteSprint() {
        Sprint__c sprint1 = new Sprint__c(Name='Sprint 1',
            Status__c = SprintModel.NOT_STARTED_STATUS, Start_Date__c = Date.today().addDays(-1));
        insert sprint1;

        Test.startTest();

            SprintHomeController.deleteSprint( sprint1.Id );

        Test.stopTest();

        List<Sprint__c> sprints = [SELECT Id FROM Sprint__c];

        System.assertEquals(0, sprints.size(), 'The sprint should have been deleted');
    }

    static testMethod void getAssignableBacklogItems_excludeIds() {
        Integer totalCount = 5;
        List<Backlog__c> allBacklogItems = TestingUtils.buildBacklogItems(totalCount);
        insert allBacklogItems;

        List<String> excludeIds = new List<String> { allBacklogItems[0].Id };

        Test.startTest();
            List<BacklogItemModel> backlogItems = SprintHomeController.getAssignableBacklogItems(excludeIds);
        Test.stopTest();

        System.assertEquals(totalCount - excludeIds.size(), backlogItems.size(),
            'The backlog items count should be the total minus the count of excluded ids.');

        for (BacklogItemModel backlogItem : backlogItems) {
            System.assert(backlogItem.id != allBacklogItems[0].Id,
                'The excluded backlog item should not be in the list of backlog items returned.');
        }
    }

    static testMethod void getAssignableBacklogItems_limitQuery() {
        List<Backlog__c> allBacklogItems = TestingUtils.buildBacklogItems(SprintHomeController.BACKLOG_QUERY_LIMIT + 1);
        insert allBacklogItems;

        Test.startTest();
            List<BacklogItemModel> backlogItems = SprintHomeController.getAssignableBacklogItems(new List<String>());
        Test.stopTest();

        System.assertEquals(SprintHomeController.BACKLOG_QUERY_LIMIT, backlogItems.size(),
            'The backlog items count should be the total minus the count of excluded ids.');
    }

    static testMethod void getInitialBacklogItems_multipleLoops() {
        Sprint__c sprint = TestingUtils.createSprint('Test Sprint');
        List<Backlog__c> assignedBacklogItems = new List<Backlog__c>();
        List<Backlog__c> unassignedBacklogItems = new List<Backlog__c>();
        for (Integer k = 0; k < SprintHomeController.INITIAL_BACKLOG_ROW_LIMIT + 1; k++) {
            if (k < ( SprintHomeController.INITIAL_BACKLOG_ROW_LIMIT -
                SprintHomeController.BACKLOG_QUERY_LIMIT + 1) ) {
                assignedBacklogItems.add(TestingUtils.buildBacklogItem(k + 1));
            } else {
                unassignedBacklogItems.add(TestingUtils.buildBacklogItem(k + 1));
            }
        }

        insert assignedBacklogItems;
        insert unassignedBacklogItems;

        TestingUtils.createSprintItems(sprint.Id, assignedBacklogItems, SprintModel.IN_PROGRESS_STATUS);

        Test.startTest();
            List<BacklogItemModel> initialBacklogItems = SprintHomeController.getInitialBacklogItems();
        Test.stopTest();

        Set<Id> unassignedBacklogItemIds = Pluck.ids(unassignedBacklogItems);
        Set<String> backlogModelIds = new Set<String>();
        for (BacklogItemModel backlogItem : initialBacklogItems) {
            System.assert(unassignedBacklogItemIds.contains(backlogItem.id), 
                'The backlog item in the initial list should be an unassigned backlog item.');
            backlogModelIds.add(backlogItem.id);
        }

        System.assertEquals(SprintHomeController.BACKLOG_QUERY_LIMIT, backlogModelIds.size(),
            'The returned backlogs should all be unique and should match the default count.');
    }

    static testMethod void getInitialBacklogItems_returningLessThanLimit() {
        Integer lesserSize = 5;
        List<Backlog__c> backlogItems = new List<Backlog__c>();
        for (Integer k = 0; k < lesserSize; k++) {
            backlogItems.add(TestingUtils.buildBacklogItem(k + 1));
        }
        insert backlogItems;

        Test.startTest();
            List<BacklogItemModel> initialBacklogItems = SprintHomeController.getInitialBacklogItems();
        Test.stopTest();

        System.assertEquals(lesserSize, initialBacklogItems.size(), 
            'The returned backlog item list should contain the number of backlog items inserted.');

        Set<Id> assignableBacklogItemIds = Pluck.ids(backlogItems);
        for (BacklogItemModel backlogItem : initialBacklogItems) {
            System.assert(assignableBacklogItemIds.contains(backlogItem.id), 
                'The backlog item in the initial list should be an assignable backlog item.');
        }
    }

    static testMethod void getBacklogItemsCount_allUnassigned() {
        Integer totalCount = 5;
        List<Backlog__c> backlogItems = TestingUtils.buildBacklogItems(totalCount);
        insert backlogItems;

        Test.startTest();
            Integer returnedCount = SprintHomeController.getBacklogItemsCount(new List<String>());
        Test.stopTest();

        System.assertEquals(totalCount, returnedCount,
            'The returned count should match the inserted non assigned backlog items count.');
    }

    static testMethod void getBacklogItemsCount_inactiveStatuses() {
        ALMSettings__c almSettings = new ALMSettings__c();
        almSettings.Inactive_Backlog_Statuses_1__c = 'Deferred;~Defect Resolution';
        insert almSettings;

        Integer totalCount = 4;
        List<Backlog__c> backlogItems = TestingUtils.buildBacklogItems(totalCount);
        backlogItems[0].Status__c = 'Needs Requirements';
        backlogItems[1].Status__c = 'Deferred';
        backlogItems[2].Status__c = 'Defect Resolution';
        insert backlogItems;

        Test.startTest();
            Integer returnedCount = SprintHomeController.getBacklogItemsCount(new List<String>());
        Test.stopTest();

        System.assertEquals(2, returnedCount,
            'The returned count should match the total count minus all inactive statuses backlog items count.');
    }

    static testMethod void getBacklogItemsCount_sprintItems() {
        Integer totalCount = 5;
        List<Backlog__c> backlogItems = TestingUtils.buildBacklogItems(totalCount);
        insert backlogItems;

        List<Backlog__c> sprintBacklogItems = new List<Backlog__c> {
            backlogItems[0],
            backlogItems[1],
            backlogItems[2],
            backlogItems[3]
        };

        Sprint__c sprint = TestingUtils.createSprint('Test Sprint');
        List<Sprint_Item__c> sprintItems = TestingUtils.buildSprintItems(sprint.Id, sprintBacklogItems);
        sprintItems[0].Status__c = SprintModel.COMPLETED_STATUS;
        sprintItems[1].Status__c = SprintModel.IN_PROGRESS_STATUS;
        sprintItems[2].Status__c = SprintModel.INCOMPLETE_STATUS;
        insert sprintItems;

        Test.startTest();
            Integer returnedCount = SprintHomeController.getBacklogItemsCount(new List<String>());
        Test.stopTest();

        System.assertEquals(totalCount - 3, returnedCount,
            'The returned backlog count should be total minus all sprint items that are not incomplete.');
    }

    static testMethod void getBacklogItemsCount_duplicateSprintItemRecords() {
        Integer totalCount = 3;
        List<Backlog__c> backlogItems = TestingUtils.buildBacklogItems(totalCount);
        insert backlogItems;

        Backlog__c duplicateSprintBacklogItem = backlogItems[0];

        List<Backlog__c> sprintBacklogItems = new List<Backlog__c> {
            duplicateSprintBacklogItem,
            backlogItems[1]
        };

        Sprint__c closedSprint = TestingUtils.createSprint('Closed Sprint');
        List<Sprint_Item__c> closedSprintItems = TestingUtils.buildSprintItems(closedSprint.Id, sprintBacklogItems);
        closedSprintItems[0].Status__c = SprintModel.INCOMPLETE_STATUS;
        closedSprintItems[1].Status__c = SprintModel.INCOMPLETE_STATUS;
        insert closedSprintItems;

        Sprint__c newSprint = TestingUtils.createSprint('New Sprint');
        List<Sprint_Item__c> newSprintItems =
                    TestingUtils.buildSprintItems(newSprint.Id, new List<Backlog__c> { duplicateSprintBacklogItem });
        newSprintItems[0].Status__c = SprintModel.IN_PROGRESS_STATUS;
        insert newSprintItems;

        System.assertEquals(closedSprintItems[0].Backlog__c, newSprintItems[0].Backlog__c,
            'The closed sprint item and new sprint item should both be pointing at the same backlog item.');

        Test.startTest();
            Integer returnedCount = SprintHomeController.getBacklogItemsCount(new List<String>());
        Test.stopTest();

        List<Sprint_Item__c> queriedSprintItems = [ SELECT Id FROM Sprint_Item__c ];

        System.assertEquals(closedSprintItems.size() + newSprintItems.size(), queriedSprintItems.size(),
            'The number of sprint item records should be the total of sprint items in the closed and new sprint.');

        System.assertEquals(totalCount - newSprintItems.size(), returnedCount,
            'The returned backlog count should be total minus the non incomplete sprint item.');
    }

    static testMethod void getBacklogItemsCount_includingAlreadyAssigned() {
        Integer totalCount = 3;
        List<Backlog__c> backlogItems = TestingUtils.buildBacklogItems(totalCount);
        insert backlogItems;

        Test.startTest();
            Integer returnedCount = SprintHomeController.getBacklogItemsCount(new List<String>{ backlogItems[0].Id });
        Test.stopTest();

        System.assertEquals(totalCount, returnedCount,
            'The returned count should still match the total count when a queried backlog Id has been passed in.');
    }

    static testMethod void getBacklogItemsCount_nullParameter() {
        Integer totalCount = 3;
        List<Backlog__c> backlogItems = TestingUtils.buildBacklogItems(totalCount);
        insert backlogItems;

        Test.startTest();
            Integer returnedCount = SprintHomeController.getBacklogItemsCount(null);
        Test.stopTest();

        System.assertEquals(totalCount, returnedCount,
            'The returned count should still return correct value even though it is a null parameter.');
    }

    static testMethod void reassignIncompleteItems() {
        Integer DEV_EFFORT = 2;
        Sprint__c completedSprint = new Sprint__c(Name='Completed Sprint', Status__c= SprintModel.COMPLETED_STATUS,
            Start_Date__c = Date.today());

        Sprint__c notStartedSprint = new Sprint__c(Name='Not started Sprint',
            Status__c = SprintModel.NOT_STARTED_STATUS, Start_Date__c = Date.today().addDays(-1));

        insert new List<Sprint__c> { completedSprint, notStartedSprint };

        Backlog__c backlogItem = createBacklogItem( DEV_EFFORT );
        Backlog__c backlogItem2 = createBacklogItem( DEV_EFFORT );
        insert  new List<Backlog__c>{backlogItem, backlogItem2};

        insert TestingUtils.buildSprintItems( completedSprint.Id, new List<Backlog__c>{backlogItem, backlogItem2});

        Test.startTest();

            SprintModel result = SprintHomeController.reassignIncompleteItems( completedSprint.Id, notStartedSprint.Id );

        Test.stopTest();

        List<Sprint_Item__c> completeSprintSprintItems = [
            SELECT Id, Status__c FROM Sprint_Item__c WHERE Sprint__c = :completedSprint.Id
        ];

        List<Sprint_Item__c> notStartedSprintSprintItems = [
            SELECT Id, Status__c FROM Sprint_Item__c WHERE Sprint__c = :notStartedSprint.Id
        ];

        System.assertEquals(2, completeSprintSprintItems.size(), 'The reassigned items should not have been deleted');
        System.assertEquals(SprintModel.INCOMPLETE_STATUS, completeSprintSprintItems[0].Status__c, 'The reassigned items should have their status set to incomplete');
        System.assertEquals(SprintModel.INCOMPLETE_STATUS, completeSprintSprintItems[1].Status__c, 'The reassigned items should have their status set to incomplete');

        System.assertEquals(2, notStartedSprintSprintItems.size(), 'The reassigned items should have been added to the target sprint');
        System.assertEquals(SprintModel.NOT_STARTED_STATUS, notStartedSprintSprintItems[0].Status__c, 'The reassigned items should have their status set to not started');
        System.assertEquals(SprintModel.NOT_STARTED_STATUS, notStartedSprintSprintItems[1].Status__c, 'The reassigned items should have their status set to not started');

        System.assertEquals(2, result.totalItems, 'The updated result should have the total items count updated');
        System.assertEquals(DEV_EFFORT * 2, result.totalEffort, 'The updated result should have the total effort updated');
    }

    static testMethod void sendIncompleteItemsToBacklog() {
        insert ALMSettingsServices.buildSprintLaneSetting('Finished', 0);
        Sprint__c completedSprint = new Sprint__c(Name='Completed Sprint', Status__c= SprintModel.COMPLETED_STATUS,
            Start_Date__c = Date.today());

        insert completedSprint;

        Backlog__c backlogItem = createBacklogItem( 0 );
        Backlog__c backlogItem2 = createBacklogItem( 0 );
        List<Backlog__c>  backlogItems = new List<Backlog__c>{backlogItem, backlogItem2};
        insert backlogItems;

        List<Sprint_Item__c> items = TestingUtils.buildSprintItems( completedSprint.Id, backlogItems);

        items[0].Status__c = SprintModel.ITEM_COMPLETED_STATUS;
        items[1].Status__c = SprintModel.IN_PROGRESS_STATUS;
        insert items;

        Test.startTest();

            List<BacklogItemModel> result = SprintHomeController.sendIncompleteItemsToBacklog( completedSprint.Id );

        Test.stopTest();

        System.assertEquals(1, result.size(), 'The unfinished item should have been sent to the backlog');
        System.assertEquals(backlogItem2.Id, result[0].id, 'The unfinished item should have been sent to the backlog');

        List<Sprint_Item__c> incompleteSprintItems = [
            SELECT Id, Status__c FROM Sprint_Item__c
             WHERE Backlog__c = :backlogItem2.Id
        ];
        List<Sprint_Item__c> completeSprintItems = [
            SELECT Id, Status__c FROM Sprint_Item__c
             WHERE Backlog__c = :backlogItem.Id
        ];

        System.assertEquals(1, completeSprintItems.size(), 'The reassigned items should not have been deleted');
        System.assertEquals(SprintModel.ITEM_COMPLETED_STATUS, completeSprintItems[0].Status__c, 'The status of complete items should remain unchanged ');
        System.assertEquals(1, incompleteSprintItems.size(), 'The reassigned items should not have been deleted');
        System.assertEquals(SprintModel.INCOMPLETE_STATUS, incompleteSprintItems[0].Status__c, 'The unfinished items should have their status set to incomplete');
    }

    static testMethod void testGetAllSprints() {
        Sprint__c sprint1 = new Sprint__c(Name='Sprint 1',
            Status__c = SprintModel.NOT_STARTED_STATUS, Start_Date__c = Date.today().addDays(-1));
        Sprint__c sprint2 = new Sprint__c(Name='Sprint 2', Status__c= 'In Progress',
            Start_Date__c = Date.today());
        Sprint__c sprint3 = new Sprint__c(Name='Sprint 3', Status__c= SprintModel.COMPLETED_STATUS);
        insert new List<Sprint__c>{ sprint1, sprint2, sprint3};

        Integer DEV_EFFORT = 2;

        Backlog__c sprint1Item = createBacklogItem( DEV_EFFORT );

        Backlog__c sprint2Item1 = createBacklogItem( DEV_EFFORT );
        Backlog__c sprint2Item2 = createBacklogItem( DEV_EFFORT );

        Backlog__c sprint3Item1 = createBacklogItem( DEV_EFFORT );
        insert new List<Backlog__c> {sprint1Item, sprint2Item1, sprint2Item2, sprint3Item1};

        List<Sprint_Item__c> sprintItems = new List<Sprint_Item__c>();

        sprintItems.addAll(
            TestingUtils.buildSprintItems( sprint1.Id, new List<Backlog__c>{sprint1Item})
        );

        List<Sprint_Item__c> sprint2IncompleteItems =  TestingUtils.buildSprintItems( sprint2.Id,
            new List<Backlog__c>{sprint2Item1, sprint2Item2}, 'In Progress');
        sprintItems.addAll( sprint2IncompleteItems );

        sprintItems.addAll(
            TestingUtils.buildSprintItems( sprint3.Id, new List<Backlog__c>{sprint3Item1} )
        );

        insert sprintItems;

        Test.startTest();

            SprintHomeController.AllSprintsResponse sprintResponse = SprintHomeController.getAllSprints();

        Test.stopTest();

        List<SprintModel> activeSprints = sprintResponse.activeSprints;
        List<SprintModel> completedSprints = sprintResponse.CompletedSprints;

        System.assertEquals(2, activeSprints.size(), 'Active sprints should be populated');

        System.assertEquals(sprint1.Id, activeSprints[0].sprintId, 'Sprints should be ordered by created date.');
        System.assertEquals(sprint2.Id, activeSprints[1].sprintId, 'Sprints should be ordered by created date.');

        System.assertEquals(sprint1.Status__c, activeSprints[0].status, 'Sprints status should be set.');
        System.assertEquals(SprintServices.getSprintDateFormat( sprint1.Start_Date__c ), activeSprints[0].startDateDisplay, 'Sprints Start Date should be set.');
        System.assertEquals(sprint1.Start_Date__c, activeSprints[0].startDate, 'Sprints Start Date should be set.');
        System.assertEquals(1, activeSprints[0].incompleteItems, 'All sprint items not marked as completed should be counted as incomplete.');
        System.assertEquals(1, activeSprints[0].totalItems, 'All sprint items should be counted.');
        System.assertEquals(DEV_EFFORT, activeSprints[0].totalEffort, 'All sprint items effort should be summed.');
        System.assertEquals(0, activeSprints[0].unestimatedItems, 'Sprint items without effort should be summed.');

        System.assertEquals(sprint2.Status__c, activeSprints[1].status, 'Sprints status should be set.');
        System.assertEquals(SprintServices.getSprintDateFormat( sprint2.Start_Date__c ), activeSprints[1].startDateDisplay, 'Sprints Start Date should be set.');
        System.assertEquals(sprint2IncompleteItems.size(), activeSprints[1].incompleteItems,
         'All sprint items not marked as completed should be counted as incomplete.');
        System.assertEquals(2, activeSprints[1].totalItems, 'All sprint items should be counted.');
        System.assertEquals(DEV_EFFORT * 2, activeSprints[1].totalEffort, 'All sprint items effort should be summed.');
        System.assertEquals(0, activeSprints[1].unestimatedItems, 'Sprint items without effort should be summed.');

        System.assertEquals(1, completedSprints.size(), 'Completed sprints should be populated');

        System.assertEquals(sprint3.Id, completedSprints[0].sprintId, 'The list should only include completed sprints.');
        System.assertEquals(1, completedSprints[0].incompleteItems, 'All sprint items not marked as completed should be counted as incomplete.');
        System.assertEquals(1, completedSprints[0].totalItems, 'All sprint items should be counted.');
        System.assertEquals(DEV_EFFORT, completedSprints[0].totalEffort, 'All sprint items effort should be summed.');
        System.assertEquals(0, completedSprints[0].unestimatedItems, 'Sprint items without effort should be summed.');
    }


    private static Backlog__c createBacklogItem(Integer devEffort) {
        return new Backlog__c(Dev_Effort__c = (Decimal) devEffort);
    }

    @isTest
    private static void updateDefaultBacklog_noCustomSetting() {
        Id userId = UserInfo.getUserId();

        Test.startTest();

            Id newBacklogId = TestingUtils.createRandomFakeSObjectId(Backlog__c.SObjectType);
            SprintHomeController.updateDefaultBacklog(newBacklogId);

        Test.stopTest();

        System.assertEquals(newBacklogId, User_Preferences__c.getValues(userId).Sprint_Home_Default_Backlog_ID__c, 'The default backlog ID should be updated.');
    }

    @isTest
    private static void updateDefaultBacklog_withCustomSetting() {
        Id userId = UserInfo.getUserId();
        Id defaultCustomBacklogId = TestingUtils.createRandomFakeSObjectId(Custom_Backlog__c.SObjectType);
        Id sprintHomeDefaultBacklogId = TestingUtils.createRandomFakeSObjectId(Custom_Backlog__c.SObjectType);

        insert new User_Preferences__c(SetupOwnerId = userId, Default_Custom_Backlog_Id__c = defaultCustomBacklogId, Sprint_Home_Default_Backlog_ID__c = sprintHomeDefaultBacklogId);

        Test.startTest();

            Id newBacklogId = TestingUtils.createRandomFakeSObjectId(Backlog__c.SObjectType);
            SprintHomeController.updateDefaultBacklog(newBacklogId);

        Test.stopTest();

        System.assertEquals(defaultCustomBacklogId, User_Preferences__c.getValues(userId).Default_Custom_Backlog_Id__c, 'The default custom backlog ID should not be updated.');
        System.assertEquals(newBacklogId, User_Preferences__c.getValues(userId).Sprint_Home_Default_Backlog_ID__c, 'The sprint home default backlog ID should be updated.');
    }
}