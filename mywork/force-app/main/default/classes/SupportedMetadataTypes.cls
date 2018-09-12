public with sharing class SupportedMetadataTypes {
    
    public static List<String> getAll() {
        List<String> types = new List<String>();
        try {
            for (Supported_Metadata_Types__c record : Supported_Metadata_Types__c.getAll().values()) {
                types.add(record.Name);
            }
            types.sort();
            return types;
        } catch(System.ListException e) {
            List<Supported_Metadata_Types__c> mdTypesWithDuplicates = [SELECT Name from Supported_Metadata_Types__c];
            return deleteDuplicates(mdTypesWithDuplicates);
        }

    }
    
    @TestVisible
    private static List<String> deleteDuplicates(List<Supported_Metadata_Types__c> mdTypesWithDuplicates) {
            Set<String> mdNamesSet = new Set<String>();
            List<Supported_Metadata_Types__c> mdTypesToDelete = new List<Supported_Metadata_Types__c>();

            for (Supported_Metadata_Types__c mdType: mdTypesWithDuplicates) {
                if (!mdNamesSet.add(mdType.Name)) {
                    mdTypesToDelete.add(mdType);
                }
            }
            try {
                delete mdTypesToDelete;
            } catch(Exception e) {
                ALMLogServices.error(e, ALMLogServices.Application.COMPONENT_DOCUMENTATION);
            }
            List<String> mdNamesList = new List<String>();
            mdNamesList.addAll(mdNamesSet);
            mdNamesList.sort();
            return mdNamesList;
            
    }

}