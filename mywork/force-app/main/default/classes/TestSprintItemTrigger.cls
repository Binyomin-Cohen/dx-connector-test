@isTest
private class TestSprintItemTrigger {
    
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
        
    }

    static testMethod void testSprintItemInsert_UpdateCurrentSprintOnBacklog() {
        
        setupTestSprintItemData(true);
        
        Test.startTest();
            UnitTest.get('Sprint Items').insertAll();
        Test.stopTest();
        
        Map<Id, Backlog__c> bklgMap = new Map<Id, Backlog__c>([Select Current_Sprint__c, Status__c from Backlog__c Where Id in :UnitTest.getIds('Backlogs')]);
        
        System.assertEquals(UnitTest.getIds('Backlogs'), bklgMap.keySet(), 'We expect to get back the correct backlogs.');
        for (Sprint_Item__c sItem : (List<Sprint_Item__c>)UnitTest.get('Sprint Items').getList()){
            System.assertEquals(sItem.Sprint__c, bklgMap.get(sItem.Backlog__c).Current_Sprint__c, 'We expect the Backlog to be updated with the current sprint.');
        }
        
    }
    
    static testMethod void testSprintItemNonSprintUpdate_MaintainCurrentSprintOnBacklog() {
        
        setupTestSprintItemData(true);

        UnitTest.get('Sprint Items').insertAll();
        
        UnitTest.get('Sprint Items').property(SObjectServices.getFullyQualifiedName('Status__c')).assign(SprintModel.COMPLETED_STATUS);
        
        Test.startTest();
            UnitTest.get('Sprint Items').updateAll();
        Test.stopTest();
        
        Map<Id, Backlog__c> bklgMap = new Map<Id, Backlog__c>([Select Current_Sprint__c, Status__c from Backlog__c Where Id in :UnitTest.getIds('Backlogs')]);
        
        System.assertEquals(UnitTest.getIds('Backlogs'), bklgMap.keySet(), 'We expect to get back the correct backlogs.');
        for (Sprint_Item__c sItem : (List<Sprint_Item__c>)UnitTest.get('Sprint Items').getList()){
            System.assertEquals(sItem.Sprint__c, bklgMap.get(sItem.Backlog__c).Current_Sprint__c, 'We expect the Backlog to be the same current sprint.');
        }
        
    }
    
    static testMethod void testSprintItemDelete_ClearCurrentSprintOnBacklog() {
        
        setupTestSprintItemData(true);
        UnitTest.get('Sprint Items').insertAll();
        
        Test.startTest();
            UnitTest.get('Sprint Items').deleteAll();
        Test.stopTest();
        
        Map<Id, Backlog__c> bklgMap = new Map<Id, Backlog__c>([Select Current_Sprint__c, Status__c from Backlog__c Where Id in :UnitTest.getIds('Backlogs')]);
        
        System.assertEquals(UnitTest.getIds('Backlogs'), bklgMap.keySet(), 'We expect to get back the correct backlogs.');
        for (Id bklgId : bklgMap.keySet()){
            System.assertEquals(null, bklgMap.get(bklgId).Current_Sprint__c, 'We expect the Backlog to be updated with NO current sprint.');
        }
        
    }
    static testMethod void testSprintItemUndelete_UpdateCurrentSprintOnBacklog() {
        
        setupTestSprintItemData(true);
        UnitTest.get('Sprint Items').insertAll();
        UnitTest.get('Sprint Items').deleteAll();
        
        Test.startTest();
            undelete UnitTest.get('Sprint Items').getList();
        Test.stopTest();
        
        Map<Id, Backlog__c> bklgMap = new Map<Id, Backlog__c>([Select Current_Sprint__c, Status__c from Backlog__c Where Id in :UnitTest.getIds('Backlogs')]);
        
        System.assertEquals(UnitTest.getIds('Backlogs'), bklgMap.keySet(), 'We expect to get back the correct backlogs.');
        for (Sprint_Item__c sItem : (List<Sprint_Item__c>)UnitTest.get('Sprint Items').getList()){
            System.assertEquals(sItem.Sprint__c, bklgMap.get(sItem.Backlog__c).Current_Sprint__c, 'We expect the Backlog to be updated with the current sprint.');
        }
        
    }
}