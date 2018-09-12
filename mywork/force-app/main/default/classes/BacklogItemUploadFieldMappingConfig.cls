public with sharing class BacklogItemUploadFieldMappingConfig {

    public static Set<String> UNSUPPORTED_OBJECT_TYPES = new Set<String>{'User', 'RecordType'};

    @AuraEnabled
    public String columnName {get; set;}

    @AuraEnabled
    public String salesforceFieldName {get; set;}

    @AuraEnabled
    public String sampleUploadedData {get; set;}

    @AuraEnabled
    public Boolean isRequired {get; set;}

    @AuraEnabled
    public Boolean isMapped {get; set;}

    @AuraEnabled
    public Boolean isLookup {get; set; }

    @AuraEnabled
    public LookupDetail lookupDetail {get; set;}

    public BacklogItemUploadFieldMappingConfig() {
        isLookup = false;
        isMapped = false;
        isRequired = false;
        sampleUploadedData = '';
        columnName = '';
        lookupDetail = new LookupDetail();
    }
    public BacklogItemUploadFieldMappingConfig(String column) {
        this();
        columnName = column;
    }

    public void populateRelatedRecords(List<String> lookupValues) {
        lookupDetail = new LookupDetail();

        final Integer FIFTEEN_CHAR_ID_LENGTH = 15;

        trimAndRemoveBlankValues(lookupValues);
        Set<String> sanitizedLookupValues = new Set<String>();
        for (String lookupValue : lookupValues) {
            sanitizedLookupValues.add( String.escapeSingleQuotes(lookupValue) );
        }

        Set<String> lookupResultValues = new Set<String>();

        for (DescribeSObjectResult describeResult : getLookupDescribeInfo()) {

            String sObjectName = describeResult.getName();
            String sObjectLabel = describeResult.getLabel();
            lookupDetail.lookupTargetObjectName = sObjectName;
            lookupDetail.lookupTargetObjectLabel = sObjectLabel;

            if (!describeResult.isCreateable() || UNSUPPORTED_OBJECT_TYPES.contains(sObjectName)) {
                lookupDetail.hasLookupError = true;
            }
            String backlogSobjectName = Schema.Backlog__c.getSObjectType().getDescribe().getName();
            String nameField = SObjectServices.getNameField(describeResult.getSobjectType());
            Boolean hasNameField = nameField != 'Id';

            String query = 'SELECT Id';
            if (hasNameField) {
                query += ', ' + nameField;
                if (sObjectName.equalsIgnoreCase(Schema.RecordType.getSObjectType().getDescribe().getName())){
                    query += ', sObjectType';
                }
            }
            query += ' FROM ' + sObjectName + ' WHERE (Id IN :sanitizedLookupValues';
            if (hasNameField) {
                query += ' OR ' + nameField + ' IN :sanitizedLookupValues)';
                if (sObjectName.equalsIgnoreCase(Schema.RecordType.getSObjectType().getDescribe().getName())){
                    query += ' AND sObjectType = :backlogSobjectName';
                }
            } else {
                query += ')';
            }

            for (SObject lookupResult : Database.query(query)) {
                lookupResultValues.add(lookupResult.Id);
                lookupResultValues.add(
                    String.valueOf(lookupResult.Id).left(FIFTEEN_CHAR_ID_LENGTH)
                );
                if (hasNameField) {
                    lookupResultValues.add((String)lookupResult.get(nameField));
                    lookupDetail.existingRelatedRecordMap.put((String)lookupResult.get(nameField), lookupResult.Id);
                }
            }
        }

        Set<String> lookupValuesSet = new Set<String>(lookupValues);
        lookupValuesSet.removeAll(lookupResultValues);
        lookupDetail.newRelatedRecords = new List<String>(lookupValuesSet);
    }

    private List<DescribeSObjectResult> getLookupDescribeInfo() {
        List<DescribeSObjectResult> describeResults = new List<DescribeSObjectResult>();

        Schema.DescribeFieldResult sobjFieldDescribe =
            Schema.SObjectType.Backlog__c.fields.getMap().get(salesforceFieldName).getDescribe();

        List<Schema.sObjectType> relatedTypes = sobjFieldDescribe.getReferenceTo();

        for (Schema.sObjectType type : relatedTypes) {
            describeResults.add(type.getDescribe());
        }

        return describeResults;
    }

    /**
    * Removes all blank values from a List of strings. Modifies the original collection.
    */
    private static void trimAndRemoveBlankValues(List<String> values) {
        for (Integer i = values.size() - 1; i >= 0; i--) {
            if (String.isBlank(values[i])) {
                values.remove(i);
            } else {
                values[i] = values[i].trim();
            }
        }
    }

    public class LookupDetail {
        @AuraEnabled
        public Boolean createNewRelatedRecords {get; set; }

        @AuraEnabled
        public Boolean hasLookupError {get; set; }

        @AuraEnabled
        public String lookupTargetObjectName {get; set; }

        @AuraEnabled
        public String lookupTargetObjectLabel {get; set; }

        @AuraEnabled
        public List<String> newRelatedRecords {get; set; }

        @AuraEnabled
        public Map<String, String> existingRelatedRecordMap {get; set; }

        public LookupDetail() {
            hasLookupError = false;
            lookupTargetObjectName = '';
            lookupTargetObjectLabel = '';
            createNewRelatedRecords = true;
            newRelatedRecords = new List<String>();
            existingRelatedRecordMap = new Map<String, String>();
        }

    }

}