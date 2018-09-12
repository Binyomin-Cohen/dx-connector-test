@isTest
private class TestSupportedMetadataTypes {

    static testMethod void getAll() {
        String objectType = 'Object';
        String workflowType = 'Workflow';
        
        List<Supported_Metadata_Types__c> mdTypes = new List<Supported_Metadata_Types__c>();
        mdTypes.add(new Supported_Metadata_Types__c(Name=objectType));
        mdTypes.add(new Supported_Metadata_Types__c(Name=workflowType));
        
        insert mdTypes;
        
        Test.startTest();
            List<String> actuals = SupportedMetadataTypes.getAll();
        Test.stopTest();
        
        actuals.sort();
        System.assertEquals(2, actuals.size(), 'All entries in the custom setting should be returned');
        System.assertEquals(objectType, actuals.get(0), 'Expected ' + objectType + ' to be in the custom setting');
        System.assertEquals(workflowType, actuals.get(1), 'Expected ' + workflowType + ' to be in the custom setting');
    }
    
    static testMethod void getAll_EmptyCustomSetting() {
        Test.startTest();
            List<String> actuals = SupportedMetadataTypes.getAll();
        Test.stopTest();
        
        System.assertEquals(0, actuals.size(), 'An empty list should be returned when no values are in the custom setting');
    }

    static testMethod void deleteDuplicates() {

        final String NAME_WITH_DUPLICATE = 'dupe';  
        List<Supported_Metadata_Types__c> mdTypes = new List<Supported_Metadata_Types__c>();

        List<String> namesForMDTypes = new List<String>{NAME_WITH_DUPLICATE, 'UniqueName', 'UniqueName2', NAME_WITH_DUPLICATE};
        for (String name: namesForMDTypes) {
            mdTypes.add(new Supported_Metadata_Types__c(Name=name ));
        }

        Test.startTest();
            List<String> dedupedNames = SupportedMetadataTypes.deleteDuplicates(mdTypes);
        Test.stopTest();

        System.assertEquals(namesForMDTypes.size() - 1 , dedupedNames.size(), 'The deduped list should have one element removed');
        Set<String> originalNamesSet = new Set<String>();
        Set<String> dedupedNamesSet = new Set<String>();
        originalNamesSet.addAll(namesForMDTypes);
        dedupedNamesSet.addAll(dedupedNames);
        System.assertEquals(originalNamesSet, dedupedNamesSet, 'The deduped list should have the same elements as the original list made into a set');
    }
}