public with sharing class BacklogItemUploadController {
    public String namespace {get; set;}

    public BacklogItemUploadController() {
        namespace = SObjectServices.CURRENT_NAMESPACE;        
    }

    public static Set<String> ignoreRequiredFields = new Set<String>{
        'OwnerId'
    };

    public static SObjectServices.SObjectFieldInfo backlogItemFieldInfo {
        get {
            if (backlogItemFieldInfo == null){
                backlogItemFieldInfo = new SObjectServices.SObjectFieldInfo(Schema.SObjectType.Backlog__c, ignoreRequiredFields);
                backlogItemFieldInfo.populateFieldInfo();
            }
            return backlogItemFieldInfo;
        }
        set;
    }


    @AuraEnabled
    public static BacklogItemUploadResult createRecords(String mappingConfigDataJSON, String columnHeaderIndexRecordsJSON, String backlogItemRecordsJSON) {
        // BacklogItemUploadMappingConfig.class
        // Map of Field API Name to CSV Column Index records
        // list of list of strings

        BacklogItemUploadMappingConfig mcd;
        List<List<String>> backlogItemRecords;
        Map<String, Integer> columnHeaderIndexRecords;
        try {
            mcd = (BacklogItemUploadMappingConfig) JSON.deserialize(mappingConfigDataJSON, BacklogItemUploadMappingConfig.class);
        } catch(Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        try {
            backlogItemRecords = (List<List<String>>) JSON.deserialize(backlogItemRecordsJSON, List<List<String>>.class);
        } catch(Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }

        try {
             columnHeaderIndexRecords = (Map<String, Integer>) JSON.deserialize(columnHeaderIndexRecordsJSON, Map<String, Integer>.class);
        } catch(Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }

        BacklogItemDataLoader dataLoader = new BacklogItemDataLoader(mcd, columnHeaderIndexRecords, backlogItemRecords);

        return dataLoader.createRecords();
    }

    @AuraEnabled
    public static BacklogItemUploadMappingConfig buildMappingConfigurations(List<String> columnNames) {
        // required fields
        BacklogItemUploadMappingConfig mappingData = new BacklogItemUploadMappingConfig();
        mappingData.uploadedColumnNames = columnNames;
        mappingData.unmappedFields = backlogItemFieldInfo.fieldsAvailable;
        mappingData.requiredFieldApiNames = backlogItemFieldInfo.required;
        mappingData.lookupFieldApiNames = backlogItemFieldInfo.lookups;

        // prep auto mapping
        for (String columnName : columnNames) {
            mappingData.mappingConfigurations.add(new BacklogItemUploadFieldMappingConfig(columnName));
        }
        mappingData.allBacklogItemFields = backlogItemFieldInfo.labelToApiNames.values();
        mappingData.autoMapFields(backlogItemFieldInfo.labelToApiNames);
        mappingData.populateRequiredMappingConfigurations();
        return mappingData;
    }

    @AuraEnabled
    public static BacklogItemUploadFieldMappingConfig.LookupDetail getRelatedRecords(String fieldMappingConfigJSON, List<String> lookupValues) {
        BacklogItemUploadFieldMappingConfig fieldMappingConfig;
        try {
            fieldMappingConfig = (BacklogItemUploadFieldMappingConfig) JSON.deserialize(
                fieldMappingConfigJSON, BacklogItemUploadFieldMappingConfig.class);
        } catch(Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }

        fieldMappingConfig.populateRelatedRecords(lookupValues);
        return fieldMappingConfig.lookupDetail;
    }

}