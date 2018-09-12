@isTest
private class TestUpdateExistingComponentKeys {

    static testMethod void testBatch() {
        ComponentServices.RUN_TRIGGER = false;
        
        List<Component__c> componentList = new List<Component__c>();
      
        // Insert 200 component records to simulate one batch execution
        for (Integer i=0; i<200; i++) {
            Component__c c = new Component__c(Name='Foo'+i);
            c.Type__c = 'Application';
            componentList.add(c);
        }
        
        insert componentList;
        
        ComponentServices.RUN_TRIGGER = true;
        
        Integer startCount = [Select count() from Component__c Where Key__c = ''];
        System.assertEquals(200, startCount, 'Expected 200 records with an empty Key__c value');
        
        // execute the batch
        Test.startTest();
            UpdateExistingComponentKeys batch = new UpdateExistingComponentKeys();
            ID batchProcessid = Database.executeBatch(batch);
        Test.stopTest();
        
        Integer endCount = [Select count() from Component__c Where Key__c = ''];
        System.assertEquals(0, endCount, 'There should be 0 records with an empty Key__c value');
    }
}