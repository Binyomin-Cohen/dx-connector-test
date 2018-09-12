@isTest
private class TestBacklogItemTrigger {
    static testMethod void backlogItem_insert_single_notCompleted() {
        Sprint__c sprint = new Sprint__c(Name = 'Test Sprint 0', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c(Current_Sprint__c = sprint.Id);

        Test.startTest();

            try {
                insert backlogItem;
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> sprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];

        System.assertEquals(1, sprintItems.size(), 'There should be one new sprint item.');
        System.assertEquals(backlogItem.Id, sprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint.Id, sprintItems[0].Sprint__c, 'The sprint ID should match.');
    }

    static testMethod void backlogItem_insert_single_completed() {
        Sprint__c sprint = new Sprint__c(Name = 'Test Sprint 0', Status__c = SprintModel.COMPLETED_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c(Current_Sprint__c = sprint.Id);

        Test.startTest();

            try {
                insert backlogItem;
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assert(true, 'An exception should be thrown.');
                System.assert(e.getMessage().contains(Label.Sprint_Item_Cannot_Add_To_Completed_Sprint), 'The exception message should match.');
            }

        Test.stopTest();

        List<Sprint_Item__c> sprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];

        System.assertEquals(0, sprintItems.size(), 'There should be no new sprint items.');
    }

    static testMethod void backlogItem_insert_multiple_mixture() {
        Sprint__c sprint0 = new Sprint__c(Name = 'Test Sprint 0', Status__c = SprintModel.COMPLETED_STATUS);
        Sprint__c sprint1 = new Sprint__c(Name = 'Test Sprint 1', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert new List<Sprint__c>{ sprint0, sprint1 };

        Backlog__c backlogItem0 = new Backlog__c(Current_Sprint__c = sprint0.Id);
        Backlog__c backlogItem1 = new Backlog__c(Current_Sprint__c = sprint1.Id);

        Test.startTest();

            try {
                Database.insert(new List<Backlog__c>{ backlogItem0, backlogItem1 }, false);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> sprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];

        System.assertEquals(1, sprintItems.size(), 'There should be one new sprint item.');
        System.assertEquals(backlogItem1.Id, sprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint1.Id, sprintItems[0].Sprint__c, 'The sprint ID should match.');
    }

    static testMethod void backlogItem_update_single_addSprintItem_notCompleted() {
        Sprint__c sprint = new Sprint__c(Name = 'Test Sprint 0', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        List<Sprint_Item__c> beforeSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(0, beforeSprintItems.size(), 'There should be no sprint items before the update.');

        Test.startTest();

            backlogItem.Current_Sprint__c = sprint.Id;

            try {
                update backlogItem;
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(1, afterSprintItems.size(), 'There should be one new sprint item.');
        System.assertEquals(backlogItem.Id, afterSprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint.Id, afterSprintItems[0].Sprint__c, 'The sprint ID should match.');
    }

    static testMethod void backlogItem_update_single_addSprintItem_completed() {
        Sprint__c sprint = new Sprint__c(Name = 'Test Sprint 0', Status__c = SprintModel.COMPLETED_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        List<Sprint_Item__c> beforeSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(0, beforeSprintItems.size(), 'There should be no sprint items before the update.');

        Test.startTest();

            backlogItem.Current_Sprint__c = sprint.Id;

            try {
                update backlogItem;
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assert(true, 'An exception should be thrown.');
                System.assert(e.getMessage().contains(Label.Sprint_Item_Cannot_Add_To_Completed_Sprint), 'The exception message should match.');
            }

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(0, afterSprintItems.size(), 'There should be no new sprint items.');
    }

    static testMethod void backlogItem_update_single_addSprintItem_duplicate() {
        Sprint__c sprint = new Sprint__c(Name = 'Test Sprint 0', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c(Current_Sprint__c = sprint.Id);
        insert backlogItem;

        List<Sprint_Item__c> beforeSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(1, beforeSprintItems.size(), 'There should be one sprint item before the update.');
        System.assertEquals(backlogItem.Id, beforeSprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint.Id, beforeSprintItems[0].Sprint__c, 'The sprint ID should match.');

        Test.startTest();

            backlogItem.Current_Sprint__c = sprint.Id;

            try {
                update backlogItem;
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(1, afterSprintItems.size(), 'There should be one sprint item.');
        System.assertEquals(backlogItem.Id, afterSprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint.Id, afterSprintItems[0].Sprint__c, 'The sprint ID should match.');
        System.assertEquals(beforeSprintItems[0].Id, afterSprintItems[0].Id, 'The sprint item ID should match.');
    }

    static testMethod void backlogItem_update_single_moveSprintItem_notCompleted() {
        Sprint__c sprint0 = new Sprint__c(Name = 'Test Sprint 0', Status__c = SprintModel.NOT_STARTED_STATUS);
        Sprint__c sprint1 = new Sprint__c(Name = 'Test Sprint 1', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert new List<Sprint__c>{ sprint0, sprint1 };

        Backlog__c backlogItem = new Backlog__c(Current_Sprint__c = sprint0.Id);
        insert backlogItem;

        List<Sprint_Item__c> beforeSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(1, beforeSprintItems.size(), 'There should be one sprint item before the update.');
        System.assertEquals(backlogItem.Id, beforeSprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint0.Id, beforeSprintItems[0].Sprint__c, 'The sprint ID should match.');

        Test.startTest();

            backlogItem.Current_Sprint__c = sprint1.Id;

            try {
                update backlogItem;
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(1, afterSprintItems.size(), 'There should be one sprint item.');
        System.assertEquals(backlogItem.Id, afterSprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint1.Id, afterSprintItems[0].Sprint__c, 'The sprint ID should match.');
    }

    static testMethod void backlogItem_update_single_moveSprintItem_completed() {
        Sprint__c sprint0 = new Sprint__c(Name = 'Test Sprint 0', Status__c = SprintModel.NOT_STARTED_STATUS);
        Sprint__c sprint1 = new Sprint__c(Name = 'Test Sprint 1', Status__c = SprintModel.COMPLETED_STATUS);
        insert new List<Sprint__c>{ sprint0, sprint1 };

        Backlog__c backlogItem = new Backlog__c(Current_Sprint__c = sprint0.Id);
        insert backlogItem;

        List<Sprint_Item__c> beforeSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(1, beforeSprintItems.size(), 'There should be one sprint item before the update.');
        System.assertEquals(backlogItem.Id, beforeSprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint0.Id, beforeSprintItems[0].Sprint__c, 'The sprint ID should match.');

        Test.startTest();

            backlogItem.Current_Sprint__c = sprint1.Id;

            try {
                update backlogItem;
                System.assert(false, 'An exception should be thrown.');
            } catch (Exception e) {
                System.assert(true, 'An exception should be thrown.');
                System.assert(e.getMessage().contains(Label.Sprint_Item_Cannot_Add_To_Completed_Sprint), 'The exception message should match.');
            }

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(1, afterSprintItems.size(), 'There should be one sprint item.');
        System.assertEquals(backlogItem.Id, afterSprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint0.Id, afterSprintItems[0].Sprint__c, 'The sprint ID should match.');
    }

    static testMethod void backlogItem_update_single_deleteSprintItem_notCompleted() {
        Sprint__c sprint = new Sprint__c(Name = 'Test Sprint 0', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c(Current_Sprint__c = sprint.Id);
        insert backlogItem;

        List<Sprint_Item__c> beforeSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(1, beforeSprintItems.size(), 'There should be one sprint item before the update.');
        System.assertEquals(backlogItem.Id, beforeSprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint.Id, beforeSprintItems[0].Sprint__c, 'The sprint ID should match.');

        Test.startTest();

            backlogItem.Current_Sprint__c = null;

            try {
                update backlogItem;
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(0, afterSprintItems.size(), 'There should be no sprint items.');
    }

    static testMethod void backlogItem_update_single_deleteSprintItem_completed() {
        Sprint__c sprint = new Sprint__c(Name = 'Test Sprint 0', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c(Current_Sprint__c = sprint.Id);
        insert backlogItem;

        List<Sprint_Item__c> beforeSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(1, beforeSprintItems.size(), 'There should be one sprint item before the update.');
        System.assertEquals(backlogItem.Id, beforeSprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint.Id, beforeSprintItems[0].Sprint__c, 'The sprint ID should match.');

        sprint.Status__c = SprintModel.COMPLETED_STATUS;
        update sprint;

        Test.startTest();

            backlogItem.Current_Sprint__c = null;

            try {
                update backlogItem;
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Backlog__c, Sprint__c 
            FROM Sprint_Item__c
        ];
        System.assertEquals(1, afterSprintItems.size(), 'There should be one sprint item.');
        System.assertEquals(backlogItem.Id, afterSprintItems[0].Backlog__c, 'The backlog item ID should match.');
        System.assertEquals(sprint.Id, afterSprintItems[0].Sprint__c, 'The sprint ID should match.');
    }
}