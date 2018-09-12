@isTest
private class TestSprintServices {

    static testMethod void getFilteredBacklogItems() {
        Integer DEV_EFFORT = 2;

        Sprint__c sprint = new Sprint__c(Name='Sprint 2', Status__c= 'In Progress');
        insert sprint;

        Backlog__c backlogItem = buildBacklogItem( DEV_EFFORT );
        backlogItem.Priority__c = 1;
        Backlog__c backlogItemInSprint1 = buildBacklogItem( DEV_EFFORT );
        Backlog__c backlogItemInSprint2 = buildBacklogItem( DEV_EFFORT );
        Backlog__c backlogItemInSprintIncomplete = buildBacklogItem( DEV_EFFORT );
        backlogItemInSprintIncomplete.Priority__c = 2;

        insert new List<Backlog__c> { backlogItem, backlogItemInSprint1, backlogItemInSprint2, backlogItemInSprintIncomplete };

        List<Sprint_Item__c> sprintItems = new List<Sprint_Item__c>();

        sprintItems.addAll(
            TestingUtils.buildSprintItems( sprint.Id, new List<Backlog__c>{backlogItemInSprint1})
        );

        sprintItems.addAll(
            TestingUtils.buildSprintItems( sprint.Id, new List<Backlog__c>{backlogItemInSprint2})
        );

        sprintItems.addAll(
            TestingUtils.buildSprintItems( sprint.Id,
                new List<Backlog__c>{backlogItemInSprint2, backlogItemInSprintIncomplete}, SprintModel.INCOMPLETE_STATUS)
        );

        insert sprintItems;

        Test.startTest();

            List<Backlog__c> backlog = SprintServices.getFilteredBacklogItems(100, new List<String>());

        Test.stopTest();

        System.assertEquals(2, backlog.size(), 'Only items that do not have any active or completed sprint items should be returned');
        System.assertEquals(backlogItem.Id, backlog[0].Id, 'Items that do not have any sprint items should be returned, ordered by priority');
        System.assertEquals(backlogItemInSprintIncomplete.Id, backlog[1].Id, 'Items that only have incomplete sprint items should be returned, ordered by priority');
    }

    static testMethod void getFilteredBacklogItems_excludeInactiveStatuses() {
        String INACTIVE_STATUS = 'Rejected';

        System.runAs(TestingUtils.ADMIN_USER){
            insert new ALMSettings__c (
                  Inactive_Backlog_Statuses_1__c = INACTIVE_STATUS,
                  SetupOwnerId = UserInfo.getOrganizationId()
          );
        }

        Sprint__c sprint = new Sprint__c(Name='Test Sprint', Status__c= 'In Progress');
        insert sprint;

        Backlog__c bklg1 = TestingUtils.buildBacklogItem();
        Backlog__c bklg2 = TestingUtils.buildBacklogItem();
        bklg1.Status__c = 'In Progress';
        bklg2.Status__c = INACTIVE_STATUS;
        insert new Backlog__c[]{ bklg1, bklg2 };

        Test.startTest();

            List<Backlog__c> backlog = SprintServices.getFilteredBacklogItems(100, new List<String>());

        Test.stopTest();

        System.assertEquals(1, backlog.size(), 'Only items with active statuses should be returned.');
        System.assertEquals(bklg1.Id, backlog[0].Id, 'Only items with active statuses should be returned.');
    }

    static testMethod void getFilteredBacklogItems_limitRows() {
        Integer limitBy = 3;
        List<Backlog__c> backlogItems = TestingUtils.buildBacklogItems(5);
        insert backlogItems;

        Test.startTest();
            List<Backlog__c> returnedBacklogItems = SprintServices.getFilteredBacklogItems(limitBy, new List<String>());
        Test.stopTest();

        System.assertEquals(limitBy, returnedBacklogItems.size(),
            'There should be ' + limitBy + ' backlog items returned from the database.');

        Set<Id> defaultBacklogItemIds = Pluck.ids(backlogItems);
        for (Backlog__c backlog : returnedBacklogItems) {
            System.assert(defaultBacklogItemIds.contains(backlog.Id),
                'The Id of the returned backlog should match one of the inserted backlog items.');
        }
    }

    static testMethod void getFilteredBacklogItems_excludeIds() {
        Integer limitBy = 5;
        List<Backlog__c> backlogItems = TestingUtils.buildBacklogItems(limitBy);
        insert backlogItems;
        List<String> excludedIds = new List<String> { backlogItems[0].Id };

        Test.startTest();
            List<Backlog__c> returnedBacklogItems = SprintServices.getFilteredBacklogItems(limitBy, excludedIds);
        Test.stopTest();

        System.assertEquals(limitBy - excludedIds.size(), returnedBacklogItems.size(),
            'There should be ' + limitBy + ' backlog items returned from the database.');

        for (Backlog__c backlog : returnedBacklogItems) {
            System.assertNotEquals(excludedIds[0], backlog.Id,
                'The Id of the returned backlog should not match the excluded Id.');
        }
    }

    static testMethod void testGetSprintData() {

        insert ALMSettingsServices.buildSprintLaneSetting('Finished', 0);

        Sprint__c sprint1 = new Sprint__c(Name='Sprint 1',
            Status__c = SprintModel.NOT_STARTED_STATUS, Start_Date__c = Date.today().addDays(-1));
        Sprint__c sprint2 = new Sprint__c(Name='Sprint 2', Status__c= 'In Progress',
            Start_Date__c = Date.today());

        List<Sprint__c> sprints = new List<Sprint__c>{ sprint1, sprint2};
        insert sprints;

        Integer DEV_EFFORT = 2;

        Backlog__c sprint1Item = buildBacklogItem( DEV_EFFORT );

        Backlog__c sprint2Item1 = buildBacklogItem( DEV_EFFORT );
        Backlog__c sprint2Item2 = buildBacklogItem( DEV_EFFORT );
        Backlog__c sprint2Item3 =  TestingUtils.buildBacklogItem();

        insert new List<Backlog__c> {sprint1Item, sprint2Item1, sprint2Item2, sprint2Item3};

        List<Sprint_Item__c> sprintItems = new List<Sprint_Item__c>();

        sprintItems.addAll(
            TestingUtils.buildSprintItems( sprint1.Id, new List<Backlog__c>{sprint1Item})
        );

        List<Sprint_Item__c> sprint2IncompleteItems =  TestingUtils.buildSprintItems( sprint2.Id,
            new List<Backlog__c>{sprint2Item1, sprint2Item2}, 'In Progress');
        sprintItems.addAll( sprint2IncompleteItems );

        sprintItems.addAll(
            TestingUtils.buildSprintItems( sprint2.Id, new List<Backlog__c>{sprint2Item3},
                SprintModel.ITEM_COMPLETED_STATUS)
        );

        insert sprintItems;

        Test.startTest();

            List<SprintModel> sprintData = SprintServices.getSprintData( sprints );

        Test.stopTest();

        System.assertEquals(sprints.size(), sprintData.size(), 'All passed in sprints should be returned');

        System.assertEquals(sprint1.Id, sprintData[0].sprintId, 'Sprints should retain the order they were passed in.');
        System.assertEquals(sprint2.Id, sprintData[1].sprintId, 'Sprints should retain the order they were passed in.');

        System.assertEquals(1, sprintData[0].incompleteItems, 'All sprint items not marked as completed should be counted as incomplete.');
        System.assertEquals(1, sprintData[0].totalItems, 'All sprint items should be counted.');
        System.assertEquals(DEV_EFFORT, sprintData[0].totalEffort, 'All sprint items should effort should be summed.');
        System.assertEquals(0, sprintData[0].unestimatedItems, 'Sprint items without effort should be summed.');

        System.assertEquals(sprint2IncompleteItems.size(), sprintData[1].incompleteItems,
         'All sprint items not marked as completed should be counted as incomplete.');
        System.assertEquals(3, sprintData[1].totalItems, 'All sprint items should be counted.');
        System.assertEquals(DEV_EFFORT * 2, sprintData[1].totalEffort, 'All sprint items effort should be summed.');
        System.assertEquals(1, sprintData[1].unestimatedItems, 'Sprint items without effort should be summed.');
    }

    static testMethod void getSprintItemsForReassignment() {
        Sprint__c completedSprint = new Sprint__c(Name='Completed Sprint', Status__c= SprintModel.COMPLETED_STATUS,
            Start_Date__c = Date.today());
        insert completedSprint;

        Backlog__c backlogItem = buildBacklogItem( 0 );
        Backlog__c backlogItem2 = buildBacklogItem( 0 );
        Backlog__c backlogItem3 = buildBacklogItem( 0 );
        Backlog__c backlogItem4 = buildBacklogItem( 0 );
        List<Backlog__c>  backlogItems = new List<Backlog__c>{backlogItem, backlogItem2, backlogItem3, backlogItem4};
        insert backlogItems;

        List<Sprint_Item__c> items = TestingUtils.buildSprintItems( completedSprint.Id, backlogItems);
        items[0].Status__c = SprintModel.ITEM_COMPLETED_STATUS;
        items[1].Status__c = SprintModel.INCOMPLETE_STATUS;
        items[2].Status__c = SprintModel.IN_PROGRESS_STATUS;
        items[3].Status__c = SprintModel.NOT_STARTED_STATUS;

        insert items;

        Test.startTest();

            List<Sprint_Item__c> itemsForReassignment = SprintServices.getSprintItemsForReassignment( completedSprint.Id );

        Test.stopTest();

        System.assertEquals(2, itemsForReassignment.size(), 'Items with a status of Incomplete and completed should be excluded');

        Set<String> reassignmentStatuses = new Set<String>();
        for(Sprint_Item__c item : itemsForReassignment) {
            reassignmentStatuses.add( item.Status__c );
        }

        System.assert(reassignmentStatuses.contains( SprintModel.IN_PROGRESS_STATUS ), 'In progress items should be available for reassignment');
        System.assert(reassignmentStatuses.contains( SprintModel.NOT_STARTED_STATUS ), 'Not started items should be available for reassignment');
    }

    static testMethod void getSprintDateFormat_String() {
      String validDate = '2014-01-25';
      String validDateExpected = 'Jan 25, 2014';
      String validDateActual = SprintServices.getSprintDateFormat(validDate);
      System.assertEquals(validDateExpected, validDateActual, 'Dates should be returned in the format of MMM dd, yyyy');

      String invalidDate = null;
      String invalidDateExpected = '';
      String invalidDateActual = SprintServices.getSprintDateFormat(invalidDate);
      System.assertEquals(invalidDateExpected, invalidDateActual, 'A null date should return an empty string');

    }

    static testMethod void getSprintDateFormat_Date() {
      String validDate = '2014-01-25';
      Date d = Date.valueOf(validDate);
      String validDateExpected = 'Jan 25, 2014';
      String validDateActual = SprintServices.getSprintDateFormat(d);
      System.assertEquals(validDateExpected, validDateActual, 'Dates should be returned in the format of MMM dd, yyyy');

      Date invalidDate = null;
      String invalidDateExpected = '';
      String invalidDateActual = SprintServices.getSprintDateFormat(invalidDate);
      System.assertEquals(invalidDateExpected, invalidDateActual, 'A null date should return an empty string');
    }

    static testMethod void getLanes() {
        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('A', 0),
            ALMSettingsServices.buildSprintLaneSetting('B', 1),
            ALMSettingsServices.buildSprintLaneSetting('C', 2),
            ALMSettingsServices.buildSprintLaneSetting('New', 3)
        };

        insert settings;

        Test.startTest();

            List<Column> columns = SprintServices.getLanes();

        Test.stopTest();

        System.assertEquals(settings[0].Value__c, columns[0].apiName, 'The lanes should be retrieved in order.');
        System.assertEquals(settings[0].Value__c, columns[0].label,
            'The label should be defaulted when not found in the picklist.');
        System.assertEquals(settings[1].Value__c, columns[1].apiName, 'The lanes should be retrieved in order.');
        System.assertEquals(settings[1].Value__c, columns[1].label,
            'The label should be defaulted when not found in the picklist.');
        System.assertEquals(settings[2].Value__c, columns[2].apiName, 'The lanes should be retrieved in order.');
        System.assertEquals(settings[2].Value__c, columns[2].label,
            'The label should be defaulted when not found in the picklist.');
        System.assertEquals(settings[3].Value__c, columns[3].apiName, 'The lanes should be retrieved in order.');
        System.assertEquals(settings[3].Value__c, columns[3].label,
            'The label should be set correctly when found in the picklist values.');
    }

    static testMethod void getFurthestCompletedSprintColumn_single_noLanes() {
        List<String> picklistValues = SObjectServices.getPicklistValues(Schema.SObjectType.Backlog__c.fields.Status__c);
        String backlogItemStatus = picklistValues[picklistValues.size() - 1];

        Backlog__c backlogItem = new Backlog__c(Status__c = backlogItemStatus);
        insert backlogItem;

        Test.startTest();

            Column sprintColumn = SprintServices.getFurthestCompletedSprintColumn(backlogItem);

        Test.stopTest();

        System.assertEquals(null, sprintColumn, 'A backlog column with no match should default to null.');
    }

    static testMethod void getFurthestCompletedSprintColumn_single_noMatch() {
        List<String> picklistValues = SObjectServices.getPicklistValues(Schema.SObjectType.Backlog__c.fields.Status__c);
        String backlogItemStatus = picklistValues[picklistValues.size() - 1];

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('Test Status 0', 0),
            ALMSettingsServices.buildSprintLaneSetting('Test Status 1', 1),
            ALMSettingsServices.buildSprintLaneSetting('Test Status 2', 2)
        };
        insert settings;

        Backlog__c backlogItem = new Backlog__c(Status__c = backlogItemStatus);
        insert backlogItem;

        Test.startTest();

            Column sprintColumn = SprintServices.getFurthestCompletedSprintColumn(backlogItem);

        Test.stopTest();

        System.assertEquals(null, sprintColumn, 'A backlog column with no match should default to null.');
    }

    static testMethod void getFurthestCompletedSprintColumn_single_unknownBacklogItemStatus() {
        List<String> picklistValues = SObjectServices.getPicklistValues(Schema.SObjectType.Backlog__c.fields.Status__c);
        String backlogItemStatus = picklistValues[0];

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('Test Status 0', 0),
            ALMSettingsServices.buildSprintLaneSetting(backlogItemStatus, 1),
            ALMSettingsServices.buildSprintLaneSetting('Test Status 2', 2)
        };
        insert settings;

        Backlog__c backlogItem = new Backlog__c(Status__c = 'Not A Backlog Item Status');
        insert backlogItem;

        Test.startTest();

            Column sprintColumn = SprintServices.getFurthestCompletedSprintColumn(backlogItem);

        Test.stopTest();

        System.assertEquals(null, sprintColumn, 'A backlog column with an unknown status should default to null.');
    }

    static testMethod void getFurthestCompletedSprintColumn_single_noProximityMatch() {
        List<String> picklistValues = SObjectServices.getPicklistValues(Schema.SObjectType.Backlog__c.fields.Status__c);
        String earlierStatus = picklistValues[0];
        String laterStatus = picklistValues[picklistValues.size() - 1];

        System.assertNotEquals(earlierStatus, laterStatus, 'The two test statuses should not be equal.');

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('Test Status 0', 0),
            ALMSettingsServices.buildSprintLaneSetting(laterStatus, 1),
            ALMSettingsServices.buildSprintLaneSetting('Test Status 2', 2)
        };
        insert settings;

        Backlog__c backlogItem = new Backlog__c(Status__c = earlierStatus);
        insert backlogItem;

        Test.startTest();

            Column sprintColumn = SprintServices.getFurthestCompletedSprintColumn(backlogItem);

        Test.stopTest();

        System.assertEquals(null, sprintColumn, 'A backlog column with no match to a previous stage should default to null.');
    }

    static testMethod void getFurthestCompletedSprintColumn_single_exactMatch() {
        List<String> picklistValues = SObjectServices.getPicklistValues(Schema.SObjectType.Backlog__c.fields.Status__c);
        String backlogItemStatus = picklistValues[picklistValues.size() - 1];

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('Test Status 0', 0),
            ALMSettingsServices.buildSprintLaneSetting(backlogItemStatus, 1),
            ALMSettingsServices.buildSprintLaneSetting('Test Status 2', 2)
        };
        insert settings;

        Backlog__c backlogItem = new Backlog__c(Status__c = backlogItemStatus);
        insert backlogItem;

        Test.startTest();

            Column sprintColumn = SprintServices.getFurthestCompletedSprintColumn(backlogItem);

        Test.stopTest();

        System.assertEquals(backlogItemStatus, sprintColumn.label, 'A backlog column with an exact match should return the exact status.');
    }

    static testMethod void getFurthestCompletedSprintColumn_single_proximityMatch() {
        List<String> picklistValues = SObjectServices.getPicklistValues(Schema.SObjectType.Backlog__c.fields.Status__c);
        String status0 = picklistValues[0];
        String status1 = picklistValues[1];
        String notASprintLane = picklistValues[2];

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting(status0, 0),
            ALMSettingsServices.buildSprintLaneSetting(status1, 1),
            ALMSettingsServices.buildSprintLaneSetting('Test Status 2', 2)
        };
        insert settings;

        Backlog__c backlogItem = new Backlog__c(Status__c = notASprintLane);
        insert backlogItem;

        Test.startTest();

            Column sprintColumn = SprintServices.getFurthestCompletedSprintColumn(backlogItem);

        Test.stopTest();

        System.assertEquals(status1, sprintColumn.label, 'A backlog column with a proximity match should return the latest eligible status.');
    }

    static testMethod void getFurthestCompletedSprintColumn_multiple() {
        List<String> picklistValues = SObjectServices.getPicklistValues(Schema.SObjectType.Backlog__c.fields.Status__c);
        String status0 = picklistValues[0];
        String status1 = picklistValues[1];
        String status2 = picklistValues[2];

        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('Test Status 0', 0),
            ALMSettingsServices.buildSprintLaneSetting(status0, 1),
            ALMSettingsServices.buildSprintLaneSetting('Test Status 2', 2),
            ALMSettingsServices.buildSprintLaneSetting(status1, 3),
            ALMSettingsServices.buildSprintLaneSetting('Test Status 4', 4)
        };
        insert settings;

        Backlog__c backlogItem0 = new Backlog__c(Status__c = status0);
        Backlog__c backlogItem1 = new Backlog__c(Status__c = status2);
        List<Backlog__c> backlogItems = new List<Backlog__c>{ backlogItem0, backlogItem1 };
        insert backlogItems;

        Test.startTest();

            Map<Id, Column> backlogIdToSprintColumn = SprintServices.getFurthestCompletedSprintColumn(backlogItems);

        Test.stopTest();

        System.assertEquals(2, backlogIdToSprintColumn.size(), 'There should be two columns returned.');
        System.assertEquals(status0, backlogIdToSprintColumn.get(backlogItem0.Id).label, 'The status should match.');
        System.assertEquals(status1, backlogIdToSprintColumn.get(backlogItem1.Id).label, 'The status should match.');
    }

    static testMethod void getStatusPicklistLabel_NotFound() {
        String requestedValue = 'abcXYZ';
        String actual = SprintServices.getStatusPicklistLabel(requestedValue);
        System.assertEquals(requestedValue, actual, 'When the requested status value is not found, it should just be returned');
    }

    private static Backlog__c buildBacklogItem(Integer devEffort) {
        Backlog__c backlogItem = TestingUtils.buildBacklogItem();
        backlogItem.Dev_Effort__c = (Decimal) devEffort;
        return backlogItem;
    }
}