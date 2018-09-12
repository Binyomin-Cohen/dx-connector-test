@isTest
private class TestUpdateExistingComponents {

    static testMethod void testBatch() {
        // Assert initial custom setting value
        List<PmPostInstallHelper__c> cs = [Select Enable_Rule__c from PmPostInstallHelper__c];
        System.assertEquals(0, cs.size(), 'There should be 1 custom setting record');
        
        List<Component__c> componentList = new List<Component__c>();

        // Insert 200 component records to simulate one batch execution
        for (Integer i=0; i<200; i++) {
            Component__c c = new Component__c(Name='Foo'+i);
            c.Type__c = 'Application';
            componentList.add(c);
        }
        
        insert componentList;
        
        // Update the newly created components
        for (Component__c c : componentList) {
        	c.Instance_Count__c = 1;
        }
        
        update componentList;
        
        Integer startCount = [Select count() from Component__c Where Instance_Count__c = 1];
        System.assertEquals(200, startCount, 'Expected 200 records with an instance count of 1');
        
        // execute the batch
        Test.startTest();
            UpdateExistingComponents batch = new UpdateExistingComponents();
            ID batchProcessid = Database.executeBatch(batch);
        Test.stopTest();
        
        Integer endCount = [Select count() from Component__c Where Instance_Count__c = 1];
        System.assertEquals(0, endCount, 'There should be 0 records with an instance count of 1');
        
        Integer finalCount = [Select count() from Component__c Where Instance_Count__c = 0];
        System.assertEquals(200, finalCount, 'There should be 200 records with an instance count of 1');
        
        // Assert custom setting value
        List<PmPostInstallHelper__c> setting = [Select Enable_Rule__c from PmPostInstallHelper__c];
        System.assertEquals(1, setting.size(), 'There should be 1 custom setting record');
        System.assert(setting[0].Enable_Rule__c, 'Enable Rule should be true');
    }
}