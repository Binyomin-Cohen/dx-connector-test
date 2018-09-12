public class BacklogItemUploadMappingConfig {

    @AuraEnabled
    public List<BacklogItemUploadFieldMappingConfig> mappingConfigurations;
    @AuraEnabled
    public List<BacklogItemUploadFieldMappingConfig> requiredMappingConfigurations;
    @AuraEnabled
    public List<String> requiredFieldApiNames;
    @AuraEnabled
    public List<String> lookupFieldApiNames;
    @AuraEnabled
    public List<String> unmappedFields;
    @AuraEnabled
    public List<String> allBacklogItemFields;
    @AuraEnabled
    public List<String> uploadedColumnNames;
    @AuraEnabled
    public String backlogItemObjectLabelPlural;
    @AuraEnabled
    public String backlogItemObjectApiName;

    public BacklogItemUploadMappingConfig(){
        mappingConfigurations = new List<BacklogItemUploadFieldMappingConfig>();
        requiredMappingConfigurations = new List<BacklogItemUploadFieldMappingConfig>();
        requiredFieldApiNames = new List<String>();
        lookupFieldApiNames = new List<String>();
        unmappedFields = new List<String>();
        uploadedColumnNames = new List<String>();
        allBacklogItemFields = new List<String>();
        backlogItemObjectApiName = SObjectServices.getFullyQualifiedName('Backlog__c');
        backlogItemObjectLabelPlural = Schema.describeSObjects( new List<String>{backlogItemObjectApiName})[0].getLabelPlural();
    }

    /**
    * @param labelToApiNames a map of lowercase field labels to the field API Name
    * @precondition unmappedFields, requiredFieldApiNames, and lookupFieldApiNames need to be populated
    */
    public void autoMapFields(Map<String, String> labelToApiNames){
        Set<String> unmappedFieldSet = new Set<String>();
        Set<String> unmappedFieldApiNames = new Set<String>(unmappedFields);
        Set<String> requiredFieldApiNameSet = new Set<String>(requiredFieldApiNames);
        Set<String> lookupFieldApiNamesSet = new Set<String>(lookupFieldApiNames);

        for (String unmappedField : unmappedFields ){
            unmappedFieldSet.add(unmappedField.toLowerCase());
        }
        for (BacklogItemUploadFieldMappingConfig fieldMapConfig : mappingConfigurations){
            String apiName;
            if (unmappedFieldSet.contains(fieldMapConfig.columnName.toLowerCase()) ){ // API Name
                apiName = fieldMapConfig.columnName;
                unmappedFieldSet.remove(apiName.toLowerCase());
            }
            else if (labelToApiNames.containsKey(fieldMapConfig.columnName.toLowerCase())){ // Label match
                apiName = labelToApiNames.get(fieldMapConfig.columnName.toLowerCase());
                labelToApiNames.remove(fieldMapConfig.columnName.toLowerCase());
            }
            if (!String.isEmpty(apiName)){
                fieldMapConfig.isMapped = true;
                fieldMapConfig.salesforceFieldName = apiName;
                unmappedFieldApiNames.remove(fieldMapConfig.salesforceFieldName);

                fieldMapConfig.isRequired = requiredFieldApiNameSet.contains(apiName);
                fieldMapConfig.isLookup = lookupFieldApiNamesSet.contains(apiName);
            }
        }
        unmappedFields = new List<String>(unmappedFieldApiNames);
    }

    public void populateRequiredMappingConfigurations(){

        Set<String> unmappedRequiredFields = new Set<String>(requiredFieldApiNames);

        // Remove auto-mapped required fields
        for (Integer i = mappingConfigurations.size() - 1; i >= 0; i--) {
            BacklogItemUploadFieldMappingConfig fieldMapConfig = mappingConfigurations[i];
            if (fieldMapConfig.isRequired && fieldMapConfig.isMapped) {
                requiredMappingConfigurations.add(fieldMapConfig);
                mappingConfigurations.remove(i);
                unmappedRequiredFields.remove(fieldMapConfig.salesforceFieldName);
            }
        }

        Set<String> unmappedFieldSet = new Set<String>(unmappedFields);
        // Add unmapped required fields
        for (String requiredField : unmappedRequiredFields) {
            BacklogItemUploadFieldMappingConfig mapConfig = new BacklogItemUploadFieldMappingConfig();
            mapConfig.isRequired = true;
            mapConfig.salesforceFieldName = requiredField;
            unmappedFieldSet.remove(requiredField);
            requiredMappingConfigurations.add(mapConfig);
        }
        unmappedFields = new List<String>(unmappedFieldSet);
    }
}