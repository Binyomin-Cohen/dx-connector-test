@isTest
private class TestUpdateExistingBkgComponentRecords {

    static testMethod void testBatch() {
        Backlog__c bklg = new Backlog__c();
        insert bklg;

        Component__c comp = new Component__c(Name='Foo', Type__c='Apex Class');
        insert comp;

        List<Backlog_Component__c> backlogComps = new List<Backlog_Component__c>();

        // Insert 200 backlog component records to simulate one batch execution
        for (Integer i=0; i<199; i++) {
            Backlog_Component__c bc = new Backlog_Component__c();
            bc.Backlog__c = bklg.Id;
            bc.Component__c = comp.Id;

            if (Math.mod(i, 2) == 0) {
                bc.Source_Sandbox__c = 'sandbox';
            } else {
                bc.Source_Sandbox__c = 'prod';
            }

            backlogComps.add(bc);
        }

        // Create record with source sandbox value empty
        Backlog_Component__c bc2 = new Backlog_Component__c();
        bc2.Backlog__c = bklg.Id;
        bc2.Component__c = comp.Id;
        bc2.Source_Sandbox__c = '';
        backlogComps.add(bc2);

        insert backlogComps;

        Integer errors = [Select count() from Backlog_Component__c Where Source_Instance__c = ''];
        System.assertEquals(200, errors, 'No backlog component record should have its source instance set');

        // execute the batch
        Test.startTest();
            UpdateExistingBacklogComponentRecords batch = new UpdateExistingBacklogComponentRecords();
            ID batchProcessid = Database.executeBatch(batch);
        Test.stopTest();

        Integer emptyCount = [Select count() from Backlog_Component__c Where Source_Instance__c = ''];
        System.assertEquals(1, emptyCount, 'There should be 1 backlog component record with no source instance value');

        List<Instances__c> instanceList = [Select Name from Instances__c Order By Name Asc];
        System.assertEquals(2, instanceList.size(), 'There should be 2 Instance records.');
        System.assertEquals('prod', instanceList.get(0).Name.toLowerCase(), 'There should be 1 Instance record called Prod.');
        System.assertEquals('sandbox', instanceList.get(1).Name.toLowerCase(), 'There should be 1 Instance record called Sandbox.');
    }
}
