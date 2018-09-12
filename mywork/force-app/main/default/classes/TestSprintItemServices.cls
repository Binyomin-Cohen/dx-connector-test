@isTest
private class TestSprintItemServices {

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

    static testMethod void testGetBacklogItemIdsWithLatestSprintIds() {

        setupTestSprintItemData(true);

        Test.startTest();
            Map<Id, Id> backlogToSprintMap = SprintItemServices.getBacklogItemIdsWithLatestSprintIds((List<Sprint_Item__c>)UnitTest.get('Sprint Items').getList());
        Test.stopTest();

        System.assertEquals(UnitTest.getIds('Backlogs'), backlogToSprintMap.keySet(), 'We expect to get back all Backlog Item attached to the Sprint Items');
        for (Sprint_Item__c sprintItem : (List<Sprint_Item__c>)UnitTest.get('Sprint Items').getList()){
            System.assertEquals(sprintItem.Sprint__c, backlogToSprintMap.get(sprintItem.Backlog__c), 'We expect to get back a map of Backlog Id to latest Sprint Id');
        }
    }

    static testMethod void testUpdateCurrentSprintOnBacklogs() {

        SprintItemServices.RUN_TRIGGER = false;
        BacklogItemServices.RUN_TRIGGER = false;
        setupTestSprintItemData(true);

        List<Sprint__c> sprints = [Select Id, (Select Id, Current_Sprint__c from Backlog_Items__r) From Sprint__c Where Id in :UnitTest.getIds('Sprints')];

        System.assertEquals(UnitTest.getIds('Sprints').size() ,sprints.size(), 'We expect to get back the correct number of Sprints.');
        for (Sprint__c sprint : sprints){
            for (Backlog__c bklg : sprint.Backlog_Items__r){
                System.assertEquals(null, 'We expect no Backlog Items to be updated from the trigger.');
            }
        }

        Test.startTest();
            SprintItemServices.updateCurrentSprintOnBacklogsToMostRecentSprint((List<Sprint_Item__c>)UnitTest.get('Sprint Items in Sprint 1').getList(), null);
        Test.stopTest();

        sprints = [Select Id, (Select Id, Current_Sprint__c from Backlog_Items__r) From Sprint__c Where Id in :UnitTest.getIds('Sprints')];

        Id sprint1Id = UnitTest.get('Sprint 1').getList()[0].Id;
        Id sprint2Id = UnitTest.get('Sprint 2').getList()[0].Id;

        System.assertEquals(UnitTest.getIds('Sprints').size() ,sprints.size(), 'We expect to get back the correct number of Sprints.');
        for (Sprint__c sprint : sprints){
            if (sprint.Id == sprint1Id){
                System.assertEquals(new Set<Id>{sprint.Id}, Pluck.ids(SObjectServices.getFullyQualifiedName('Current_Sprint__c'), sprint.Backlog_Items__r),
                    'We expect the Current Sprint to be populated on the backlog items for Sprint 1.');
            } else {
                System.assertEquals(new Set<Id>(), Pluck.ids(SObjectServices.getFullyQualifiedName('Current_Sprint__c'), sprint.Backlog_Items__r),
                    'We expect the Current Sprint to NOT be populated on the other backlog items.');
            }
        }
    }

    static testMethod void testUpdateCurrentSprintOnBacklogs_previousSprintCompleted() {
        Backlog__c backlog = new Backlog__c(Status__c = 'Open');

        Sprint__c firstSprint = new Sprint__c(Name = 'firstSprint', Status__c = SprintModel.IN_PROGRESS_STATUS);
        Sprint__c secondSprint = new Sprint__c(Name = 'secondSprint', Status__c = SprintModel.IN_PROGRESS_STATUS);

        insert new List<Sprint__c>{ firstSprint, secondSprint };
        insert backlog;

        Sprint_Item__c firstSprintItem = new Sprint_Item__c(Backlog__c = backlog.Id, Sprint__c = firstSprint.Id);
        insert firstSprintItem;

        Test.startTest();

            firstSprint.Status__c = SprintModel.COMPLETED_STATUS;
            update firstSprint;

            Sprint_Item__c secondSprintItem = new Sprint_Item__c(Backlog__c = backlog.Id, Sprint__c = secondSprint.Id);
            insert secondSprintItem;

        Test.stopTest();

        backlog = [SELECT Id, Current_Sprint__c FROM Backlog__c];
        System.assertEquals(secondSprint.Id, backlog.Current_Sprint__c, 'The current sprint for the backlog item should have been updated to the second sprint');
    }

    static testMethod void testUpdateStatusOnBacklogs_sprintNotComplete() {
        String statusBefore = 'New';
        String statusAfter = 'Open';

        Sprint__c sprint = new Sprint__c(Status__c = SprintModel.IN_PROGRESS_STATUS);
        insert sprint;
        Backlog__c backlogItemBefore = new Backlog__c(Status__c = statusBefore);
        insert backlogItemBefore;
        Sprint_Item__c sprintItemBefore = new Sprint_Item__c(Status__c = statusBefore, Backlog__c = backlogItemBefore.Id, Sprint__c = sprint.Id);
        insert sprintItemBefore;
        Sprint_Item__c sprintItemAfter = new Sprint_Item__c(Id = sprintItemBefore.Id, Status__c = statusAfter, Backlog__c = backlogItemBefore.Id, Sprint__c = sprint.Id);

        Test.startTest();

            SprintItemServices.updateStatusOnBacklogs(
                new List<Sprint_Item__c>{ sprintItemAfter },
                new Map<Id, Sprint_Item__c>{ sprintItemBefore.Id => sprintItemBefore }
            );

        Test.stopTest();

        Backlog__c backlogItemResult = [SELECT Status__c FROM Backlog__c][0];
        System.assertEquals(statusAfter, backlogItemResult.Status__c, 'The backlog item status should have changed.');
    }

    static testMethod void testUpdateStatusOnBacklogs_sprintComplete() {
        String statusBefore = 'New';
        String statusAfter = 'Open';

        Sprint__c sprint = new Sprint__c(Status__c = SprintModel.COMPLETED_STATUS);
        insert sprint;
        Backlog__c backlogItemBefore = new Backlog__c(Status__c = statusBefore);
        insert backlogItemBefore;
        Sprint_Item__c sprintItemBefore = new Sprint_Item__c(Status__c = statusBefore, Backlog__c = backlogItemBefore.Id, Sprint__c = sprint.Id);
        insert sprintItemBefore;
        Sprint_Item__c sprintItemAfter = new Sprint_Item__c(Id = sprintItemBefore.Id, Status__c = statusAfter, Backlog__c = backlogItemBefore.Id, Sprint__c = sprint.Id);

        Test.startTest();

            SprintItemServices.updateStatusOnBacklogs(
                new List<Sprint_Item__c>{ sprintItemAfter },
                new Map<Id, Sprint_Item__c>{ sprintItemBefore.Id => sprintItemBefore }
            );

        Test.stopTest();

        Backlog__c backlogItemResult = [SELECT Status__c FROM Backlog__c][0];
        System.assertEquals(statusBefore, backlogItemResult.Status__c, 'The backlog item status should not have changed.');
    }

    static testMethod void testUpdateStatusOnBacklogs_sprintStatusNotAValidBacklogItemStatus() {
        String statusBefore = 'New';
        String statusAfter = SprintModel.NOT_STARTED_STATUS;

        Sprint__c sprint = new Sprint__c(Status__c = SprintModel.IN_PROGRESS_STATUS);
        insert sprint;
        Backlog__c backlogItemBefore = new Backlog__c(Status__c = statusBefore);
        insert backlogItemBefore;
        Sprint_Item__c sprintItemBefore = new Sprint_Item__c(Status__c = statusBefore, Backlog__c = backlogItemBefore.Id, Sprint__c = sprint.Id);
        insert sprintItemBefore;
        Sprint_Item__c sprintItemAfter = new Sprint_Item__c(Id = sprintItemBefore.Id, Status__c = statusAfter, Backlog__c = backlogItemBefore.Id, Sprint__c = sprint.Id);

        Test.startTest();

            SprintItemServices.updateStatusOnBacklogs(
                new List<Sprint_Item__c>{ sprintItemAfter },
                new Map<Id, Sprint_Item__c>{ sprintItemBefore.Id => sprintItemBefore }
            );

        Test.stopTest();

        Backlog__c backlogItemResult = [SELECT Status__c FROM Backlog__c][0];
        System.assertEquals(statusBefore, backlogItemResult.Status__c, 'The backlog item status should not have changed.');
    }

    static testMethod void testCreateSprintItem() {
        Sprint__c sprint = new Sprint__c(Name='Test Sprint', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        Id returnedSprintItemId = null;
        Test.startTest();

            try {
                returnedSprintItemId = SprintItemServices.createSprintItem(sprint.Id, backlogItem.Id);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Sprint__c, Status__c, Backlog__c, Backlog__r.Current_Sprint__c
            FROM Sprint_Item__c
            WHERE Id = :returnedSprintItemId
        ];

        System.assertEquals(1, afterSprintItems.size(), 'One sprint item should exist.');
        System.assertEquals(sprint.Id, afterSprintItems[0].Sprint__c, 'A sprint item should have been created looking up to the requested sprint.');
        System.assertEquals(SprintModel.NOT_STARTED_STATUS, afterSprintItems[0].Status__c, 'A sprint item should have been created with a not started status.');
        System.assertEquals(afterSprintItems[0].Id, returnedSprintItemId, 'The correct new sprint item ID should be returned.');
        System.assertEquals(backlogItem.Id, afterSprintItems[0].Backlog__c, 'A sprint item should have been created looking up to the requested backlog.');
        System.assertEquals(sprint.Id, afterSprintItems[0].Backlog__r.Current_Sprint__c, 'The new sprint item\'s backlog item should point to the correct sprint.');
    }

    static testMethod void testCreateSprintItem_duplicate() {
        Sprint__c sprint = new Sprint__c(Name='Test Sprint', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        Id returnedSprintItemId0 = null;
        Id returnedSprintItemId1 = null;
        Sprint_Item__c sprintItem0 = null;
        Test.startTest();

            try {
                returnedSprintItemId0 = SprintItemServices.createSprintItem(sprint.Id, backlogItem.Id);
                sprintItem0 = [SELECT Id FROM Sprint_Item__c LIMIT 1];
                returnedSprintItemId1 = SprintItemServices.createSprintItem(sprint.Id, backlogItem.Id);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> sprintItems = [SELECT Id FROM Sprint_Item__c LIMIT 2];
        System.assertEquals(1, sprintItems.size(), 'Only one sprint item should exist when neither are incomplete.');
        System.assertEquals(sprintItem0.Id, returnedSprintItemId0, 'The correct new sprint item ID should be returned.');
        System.assertEquals(null, returnedSprintItemId1, 'A null sprint item ID should be returned when the sprint item is deleted.');
    }

    static testMethod void testCreateSprintItem_sameBacklogDifferentSprint_notIncomplete() {
        Sprint__c sprint0 = new Sprint__c(Name='Test Sprint 0', Status__c = SprintModel.NOT_STARTED_STATUS);
        Sprint__c sprint1 = new Sprint__c(Name='Test Sprint 1', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert new List<Sprint__c>{ sprint0, sprint1 };

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        Id returnedSprintItemId0 = null;
        Id returnedSprintItemId1 = null;
        Sprint_Item__c sprintItem0 = null;
        Sprint_Item__c sprintItem1 = null;
        Test.startTest();

            try {
                returnedSprintItemId0 = SprintItemServices.createSprintItem(sprint0.Id, backlogItem.Id);
                sprintItem0 = [SELECT Id FROM Sprint_Item__c LIMIT 1];
                returnedSprintItemId1 = SprintItemServices.createSprintItem(sprint1.Id, backlogItem.Id);
                sprintItem1 = [SELECT Id FROM Sprint_Item__c WHERE Id != :returnedSprintItemId0 LIMIT 1];
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> sprintItems = [SELECT Status__c FROM Sprint_Item__c];
        System.assertEquals(1, sprintItems.size(), 'Only one sprint item should exist when neither are incomplete.');
        System.assertEquals(SprintModel.NOT_STARTED_STATUS, sprintItems[0].Status__c, 'The status should match.');
        System.assertEquals(sprintItem0.Id, returnedSprintItemId0, 'The correct new sprint item ID should be returned.');
        System.assertEquals(sprintItem1.Id, returnedSprintItemId1, 'The correct new sprint item ID should be returned.');
    }

    static testMethod void testCreateSprintItem_sameBacklogDifferentSprint_incomplete() {
        Sprint__c sprint0 = new Sprint__c(Name='Test Sprint 0', Status__c = SprintModel.IN_PROGRESS_STATUS);
        Sprint__c sprint1 = new Sprint__c(Name='Test Sprint 1', Status__c = SprintModel.NOT_STARTED_STATUS);
        insert new List<Sprint__c>{ sprint0, sprint1 };

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        Id returnedSprintItemId0 = null;
        Id returnedSprintItemId1 = null;
        Sprint_Item__c sprintItem0 = null;
        Sprint_Item__c sprintItem1 = null;
        Test.startTest();

            returnedSprintItemId0 = SprintItemServices.createSprintItem(sprint0.Id, backlogItem.Id);

            sprint0.Status__c = SprintModel.COMPLETED_STATUS;
            update sprint0;
            sprintItem0 = [SELECT Status__c FROM Sprint_Item__c LIMIT 1][0];
            sprintItem0.Status__c = SprintModel.INCOMPLETE_STATUS;
            update sprintItem0;

            returnedSprintItemId1 = SprintItemServices.createSprintItem(sprint1.Id, backlogItem.Id);

            sprintItem1 = [SELECT Status__c FROM Sprint_Item__c WHERE Id != :sprintItem0.Id LIMIT 1][0];

        Test.stopTest();

        List<Sprint_Item__c> sprintItems = [SELECT Status__c FROM Sprint_Item__c];
        System.assertEquals(2, sprintItems.size(), 'Two sprint items should exist when one is incomplete.');
        System.assertEquals(SprintModel.INCOMPLETE_STATUS, sprintItems[0].Status__c, 'The status should match.');
        System.assertEquals(sprintItem0.Id, returnedSprintItemId0, 'The correct new sprint item ID should be returned.');
        System.assertEquals(sprintItem1.Id, returnedSprintItemId1, 'The correct new sprint item ID should be returned.');
    }

    static testMethod void testCreateSprintItem_blankSprintDelete_singleItemExists_notIncomplete() {
        Sprint__c sprint = new Sprint__c(Name='Test Sprint 0', Status__c = SprintModel.IN_PROGRESS_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        Id beforeSprintItemId = SprintItemServices.createSprintItem(sprint.Id, backlogItem.Id);

        List<Sprint_Item__c> beforeSprintItems = [
            SELECT Status__c
            FROM Sprint_Item__c
            WHERE Backlog__c = :backlogItem.Id
        ];
        System.assertEquals(1, beforeSprintItems.size(), 'The planned sprint item should exist before deletion.');
        System.assertEquals(SprintModel.NOT_STARTED_STATUS, beforeSprintItems[0].Status__c, 'The planned sprint item should have the correct status.');

        Id returnedSprintItemId = null;
        Test.startTest();

            try {
                returnedSprintItemId = SprintItemServices.createSprintItem(null, backlogItem.Id);
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Id
            FROM Sprint_Item__c
            WHERE Backlog__c = :backlogItem.Id
        ];
        System.assertEquals(0, afterSprintItems.size(), 'The planned sprint item should not exist after deletion.');
        System.assertEquals(null, returnedSprintItemId, 'A null sprint item ID should be returned when the sprint item is deleted.');

        List<Backlog__c> afterBacklogItems = [SELECT Current_Sprint__c FROM Backlog__c];
        System.assertEquals(1, afterBacklogItems.size(), 'The backlog item should still exist.');
        System.assertEquals(null, afterBacklogItems[0].Current_Sprint__c, 'The sprint field on the backlog item should be cleared out.');
    }

    static testMethod void testCreateSprintItem_blankSprintDelete_singleItemExists_incomplete() {
        Sprint__c sprint = new Sprint__c(Name='Test Sprint 0', Status__c = SprintModel.IN_PROGRESS_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        Id beforeSprintItemId = SprintItemServices.createSprintItem(sprint.Id, backlogItem.Id);

        sprint.Status__c = SprintModel.COMPLETED_STATUS;
        update sprint;
        Sprint_Item__c beforeSprintItem = new Sprint_Item__c(Id = beforeSprintItemId);
        beforeSprintItem.Status__c = SprintModel.INCOMPLETE_STATUS;
        update beforeSprintItem;

        List<Sprint_Item__c> beforeSprintItems = [
            SELECT Status__c
            FROM Sprint_Item__c
            WHERE Backlog__c = :backlogItem.Id
        ];
        System.assertEquals(1, beforeSprintItems.size(), 'The incomplete sprint item should exist before deletion.');
        System.assertEquals(SprintModel.INCOMPLETE_STATUS, beforeSprintItems[0].Status__c, 'The planned sprint item should have the correct status.');

        Id returnedSprintItemId = null;
        Test.startTest();

            returnedSprintItemId = SprintItemServices.createSprintItem(null, backlogItem.Id);

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Sprint__c, Status__c, Backlog__c, Backlog__r.Current_Sprint__c
            FROM Sprint_Item__c
            WHERE Backlog__c = :backlogItem.Id
        ];
        System.assertEquals(1, afterSprintItems.size(), 'The incomplete sprint item should still exist.');
        System.assertEquals(sprint.Id, afterSprintItems[0].Sprint__c, 'The planned sprint item should still look up to the correct sprint.');
        System.assertEquals(SprintModel.INCOMPLETE_STATUS, afterSprintItems[0].Status__c, 'The planned sprint item should still have the correct status.');
        System.assertEquals(null, returnedSprintItemId, 'A null sprint item ID should be returned when no new sprint item is created.');
        System.assertEquals(sprint.Id, afterSprintItems[0].Backlog__r.Current_Sprint__c, 'The sprint field on the backlog item should still point to the correct sprint.');
    }

    static testMethod void testCreateSprintItem_blankSprintDelete_multipleItemsExist() {
        Sprint__c sprint0 = new Sprint__c(Name='Test Sprint 0', Status__c = SprintModel.IN_PROGRESS_STATUS);
        Sprint__c sprint1 = new Sprint__c(Name='Test Sprint 1', Status__c = SprintModel.IN_PROGRESS_STATUS);
        insert new List<Sprint__c>{ sprint0, sprint1 };

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        Id beforeSprintItemId0 = SprintItemServices.createSprintItem(sprint0.Id, backlogItem.Id);
        System.assertNotEquals(null, beforeSprintItemId0, 'The new sprint item should be created successfully.');

        sprint0.Status__c = SprintModel.COMPLETED_STATUS;
        update sprint0;
        Sprint_Item__c beforeSprintItem = new Sprint_Item__c(Id = beforeSprintItemId0);
        beforeSprintItem.Status__c = SprintModel.INCOMPLETE_STATUS;
        update beforeSprintItem;

        Id beforeSprintItemId1 = SprintItemServices.createSprintItem(sprint1.Id, backlogItem.Id);
        System.assertNotEquals(null, beforeSprintItemId1, 'The new sprint item should be created successfully.');

        List<Sprint_Item__c> beforeSprintItems = [
            SELECT Id
            FROM Sprint_Item__c
            WHERE Backlog__c = :backlogItem.Id
        ];
        System.assertEquals(2, beforeSprintItems.size(), 'Two sprint items should exist before deletion.');

        Id returnedSprintItemId = null;
        Test.startTest();

            returnedSprintItemId = SprintItemServices.createSprintItem(null, backlogItem.Id);

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Status__c
            FROM Sprint_Item__c
            WHERE Backlog__c = :backlogItem.Id
        ];
        System.assertEquals(1, afterSprintItems.size(), 'Only one sprint item should exist after deletion.');
        System.assertEquals(beforeSprintItemId0, afterSprintItems[0].Id, 'The correct sprint item should remain.');
        System.assertEquals(SprintModel.INCOMPLETE_STATUS, afterSprintItems[0].Status__c, 'The correct sprint item should remain.');
        System.assertEquals(null, returnedSprintItemId, 'A null sprint item ID should be returned when the sprint item is deleted.');
    }

    static testMethod void testCreateSprintItem_hasNotIncompleteItemsInCompletedSprints_addSprintItem() {
        Sprint__c sprint0 = new Sprint__c(Name='Test Sprint 0', Status__c = SprintModel.IN_PROGRESS_STATUS);
        Sprint__c sprint1 = new Sprint__c(Name='Test Sprint 1', Status__c = SprintModel.IN_PROGRESS_STATUS);
        insert new List<Sprint__c>{ sprint0, sprint1 };

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        Id beforeSprintItemId0 = SprintItemServices.createSprintItem(sprint0.Id, backlogItem.Id);
        System.assertNotEquals(null, beforeSprintItemId0, 'The new sprint item should be created successfully.');

        sprint0.Status__c = SprintModel.COMPLETED_STATUS;
        update sprint0;

        Id returnedSprintItemId = null;
        Test.startTest();

            returnedSprintItemId = SprintItemServices.createSprintItem(sprint1.Id, backlogItem.Id);

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Status__c
            FROM Sprint_Item__c
            WHERE Backlog__c = :backlogItem.Id
        ];
        System.assertEquals(1, afterSprintItems.size(), 'Only one sprint item should exist.');
        System.assertEquals(beforeSprintItemId0, afterSprintItems[0].Id, 'The correct sprint item should remain.');
        System.assertEquals(SprintModel.NOT_STARTED_STATUS, afterSprintItems[0].Status__c, 'The correct sprint item should remain.');
        System.assertEquals(null, returnedSprintItemId, 'A null sprint item ID should be returned.');
    }

    static testMethod void testCreateSprintItem_hasNotIncompleteItemsInCompletedSprints_deleteSprintItem() {
        Sprint__c sprint = new Sprint__c(Name='Test Sprint 0', Status__c = SprintModel.IN_PROGRESS_STATUS);
        insert sprint;

        Backlog__c backlogItem = new Backlog__c();
        insert backlogItem;

        Id beforeSprintItemId0 = SprintItemServices.createSprintItem(sprint.Id, backlogItem.Id);
        System.assertNotEquals(null, beforeSprintItemId0, 'The new sprint item should be created successfully.');

        sprint.Status__c = SprintModel.COMPLETED_STATUS;
        update sprint;

        Id returnedSprintItemId = null;
        Test.startTest();

            returnedSprintItemId = SprintItemServices.createSprintItem(null, backlogItem.Id);

        Test.stopTest();

        List<Sprint_Item__c> afterSprintItems = [
            SELECT Status__c
            FROM Sprint_Item__c
            WHERE Backlog__c = :backlogItem.Id
        ];
        System.assertEquals(1, afterSprintItems.size(), 'The sprint item should still exist.');
        System.assertEquals(null, returnedSprintItemId, 'A null sprint item ID should be returned.');
    }
}
