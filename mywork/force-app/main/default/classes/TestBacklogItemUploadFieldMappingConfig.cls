@isTest
private class TestBacklogItemUploadFieldMappingConfig {

    static testMethod void populateRelatedRecords_recordTypes() {
        // Real Lookup Error Fields
        Map<String, Schema.RecordTypeInfo> rtMap = new Map<String, Schema.RecordTypeInfo>();
        for (Schema.RecordTypeInfo rt : Backlog__c.SObjectType.getDescribe().getRecordTypeInfos()){
            if (!rt.isMaster()){
                rtMap.put(rt.getName(), rt);
            }
        }
        System.assert(rtMap.size() > 0, 'We expect at least one record type on Backlog__c.');

        String recordTypeIdField = 'RecordTypeId';

        BacklogItemUploadFieldMappingConfig recordTypeIdFieldMappingConfig = new BacklogItemUploadFieldMappingConfig(recordTypeIdField);
        recordTypeIdFieldMappingConfig.salesforceFieldName = recordTypeIdField;

        Test.startTest();
            recordTypeIdFieldMappingConfig.populateRelatedRecords(new List<String>(rtMap.keySet()));
        Test.stopTest();

        System.assertEquals(rtMap.keySet(), recordTypeIdFieldMappingConfig.lookupDetail.existingRelatedRecordMap.keySet(),
            'We expect the correct set of existing record types.');
        for (String recordTypeName : rtMap.keySet()){
            String actualId = recordTypeIdFieldMappingConfig.lookupDetail.existingRelatedRecordMap.get(recordTypeName);
            System.assertEquals(rtMap.get(recordTypeName).getRecordTypeId(), actualId,
                'We expect the correct set of existing record type id.');
        }
    }

    static testMethod void populateRelatedRecords_matchExisting15DigitIds() {
        Backlog__c parentStory = TestingUtils.createBacklogItem();
        parentStory = [SELECT Id, Name FROM Backlog__c WHERE Id = :parentStory.Id];

        String parentField = SObjectServices.getFullyQualifiedName('Parent_User_Story__c');

        BacklogItemUploadFieldMappingConfig fieldMappingConfig = new BacklogItemUploadFieldMappingConfig(parentField);
        fieldMappingConfig.salesforceFieldName = parentField;

        Test.startTest();
            fieldMappingConfig.populateRelatedRecords(new List<String>{ String.valueOf(parentStory.Id).left(15) });
        Test.stopTest();

        System.assertEquals(1, fieldMappingConfig.lookupDetail.existingRelatedRecordMap.size(),
            'The existing record should be found.');
        String actualId = fieldMappingConfig.lookupDetail.existingRelatedRecordMap.values()[0];
        System.assertEquals(parentStory.Id, actualId,
            'The Id of the existing record should be returned.');
        System.assertEquals(0, fieldMappingConfig.lookupDetail.newRelatedRecords.size(),
            'No new values should be returned for record creation');
    }
}