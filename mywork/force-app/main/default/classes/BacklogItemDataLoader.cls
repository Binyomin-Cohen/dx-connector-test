public with sharing class BacklogItemDataLoader {

    private static String DML_RECORD_LIMIT_REACHED_MSG = 'Too many records to insert in one transacton.';
    @TestVisible
    private static String AUTO_NUMBER_ERROR_STATUS_CODE = 'Attempted to Set Auto Number';
    @TestVisible
    private static String AUTO_NUMBER_ERROR_MESSAGE = 'Auto number is restricted and cannot be set';
    private BacklogItemUploadMappingConfig mcd;
    private Map<String, Integer> columnHeaderIndexRecords;
    private List<List<String>> backlogItemRecords;

    private Map<String, String> columnHeaderToSalesforceField;

    private Map<String, BacklogItemUploadFieldMappingConfig.LookupDetail> backlogItemFieldToLookupDetail;
    @TestVisible
    private Map<String, List<SObject>> relatedObjectToRecords;
    @TestVisible
    private Map<String, Set<String>> nonCreatableRelatedObjectToRecordNames;

    public BacklogItemDataLoader(BacklogItemUploadMappingConfig mcd,
        Map<String, Integer> columnHeaderIndexRecords, List<List<String>> backlogItemRecords) {
        this.mcd = mcd;
        this.columnHeaderIndexRecords = columnHeaderIndexRecords;
        this.backlogItemRecords = backlogItemRecords;

        initMappingData();
    }

    private void initMappingData() {
        columnHeaderToSalesforceField = new Map<String, String>();
        backlogItemFieldToLookupDetail = new Map<String, BacklogItemUploadFieldMappingConfig.LookupDetail>();
        relatedObjectToRecords = new Map<String, List<SObject>>();
        nonCreatableRelatedObjectToRecordNames = new Map<String, Set<String>>();

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

        List<BacklogItemUploadFieldMappingConfig> allFieldMappingConfigs = new List<BacklogItemUploadFieldMappingConfig>();
        allFieldMappingConfigs.addAll(mcd.mappingConfigurations);
        allFieldMappingConfigs.addAll(mcd.requiredMappingConfigurations);
        for (BacklogItemUploadFieldMappingConfig fmc : allFieldMappingConfigs){
            if (fmc.isMapped){
                // TODO: This approach does NOT handle the same column being mapped to multiple salesforce fields
                //      This is disjointed from the UI, currently, the UI seems like we do support this.
                columnHeaderToSalesforceField.put(fmc.columnName, fmc.salesforceFieldName);
                backlogItemFieldToLookupDetail.put(fmc.salesforceFieldName, fmc.lookupDetail);
                if (fmc.isLookup && fmc.lookupDetail.createNewRelatedRecords && !fmc.lookupDetail.hasLookupError && gd.containsKey(fmc.lookupDetail.lookupTargetObjectName)){
                    Schema.SObjectType sObjType = gd.get(fmc.lookupDetail.lookupTargetObjectName);
                    String nameField = SObjectServices.getNameField(sObjType);
                    Schema.DescribeSObjectResult sobjectTypeDescribeResult = sObjType.getDescribe();
                    String sobjectName = sobjectTypeDescribeResult.getName();
                    Set<String> uniqueObjectRecords = new Set<String>(fmc.lookupDetail.newRelatedRecords);
                    if( !sobjectTypeDescribeResult.fields.getMap().get(nameField).getDescribe().isCreateable() ){
                        if(!nonCreatableRelatedObjectToRecordNames.containsKey(sobjectName)){
                            nonCreatableRelatedObjectToRecordNames.put(sobjectName, new Set<String>());
                        }
                        nonCreatableRelatedObjectToRecordNames.get(sobjectName).addAll(uniqueObjectRecords);
                        continue;
                    }
                    relatedObjectToRecords.put(fmc.salesforceFieldName, new List<SObject>());
                    for (String relatedObjectName : uniqueObjectRecords){
                        SObject lookupObject = sObjType.newSObject();
                        lookupObject.put(nameField, relatedObjectName);
                        relatedObjectToRecords.get(fmc.salesforceFieldName).add(lookupObject);
                    }
                }
            }
        }
    }

    public BacklogItemUploadResult createRecords() {

        Map<String, Map<String, String>> newLookupObjectRecordNameToId = new Map<String, Map<String, String>>();
        Upload_Result__c ur = new Upload_Result__c(Num_of_Errors__c = 0, Num_of_Records_Created__c = 0);
        List<String> orderedColumnNames = new List<String>(columnHeaderToSalesforceField.keySet());

        List<List<String>> successData = new List<List<String>>();
        successData.add(new List<String>{'Id'});
        successData[0].addAll(orderedColumnNames);
        List<List<String>> errorData = new List<List<String>>();
        errorData.add(new List<String>{'Status Code', 'Message', 'Fields', 'Id'});
        errorData[0].addAll(orderedColumnNames);

        List<SObject> relatedObjectRecords = new List<SObject>();
        for (List<SObject> relatedRecords : relatedObjectToRecords.values()){
            relatedObjectRecords.addAll(relatedRecords);
        }

        if ((relatedObjectRecords.size() + backlogItemRecords.size()) > LimitServices.getRemainingDMLRecordsAvailable()){
            throw new AuraHandledException(DML_RECORD_LIMIT_REACHED_MSG);
        }
        try {
            List<Database.SaveResult> srList = Database.insert(relatedObjectRecords, false);

            for ( Integer i = 0; i < srList.size(); i++){
                Database.SaveResult sr = srList[i];
                SObject sobjRecord = relatedObjectRecords[i];

                String sobjectName = sobjRecord.getSObjectType().getDescribe().getName();
                String sobjectNameField = SObjectServices.getNameField(sobjRecord.getSObjectType());

                if (!newLookupObjectRecordNameToId.containsKey(sobjectName)){
                    newLookupObjectRecordNameToId.put(sobjectName, new Map<String, String>());
                }

                if (sr.isSuccess()){
                    newLookupObjectRecordNameToId.get(sobjectName).put( (String) sobjRecord.get(sobjectNameField) , sr.getId() );
                    ur.Num_of_Records_Created__c += 1;
                    successData.add(new List<String>{sr.getId()});
                } else {
                    newLookupObjectRecordNameToId.get(sobjectName).put( (String) sobjRecord.get(sobjectNameField) , null );
                    ur.Num_of_Errors__c += 1;
                    for(Database.Error error : sr.getErrors()) {
                        errorData.add(new List<String>{
                            String.valueOf(error.getStatusCode()), error.getMessage(), String.join(error.getFields(), ',')
                        });
                    }
                }
            }
            //Check the non creatable strings here
            for(String nonCreatableSObjectName : nonCreatableRelatedObjectToRecordNames.keySet() ){
                for(String recordName : nonCreatableRelatedObjectToRecordNames.get(nonCreatableSObjectName)){
                    errorData.add(new List<String>{
                        AUTO_NUMBER_ERROR_STATUS_CODE, AUTO_NUMBER_ERROR_MESSAGE
                    });
                    ur.Num_of_Errors__c += 1;
                }
            }
        } catch (Exception ex){
            ur.Num_of_Errors__c = relatedObjectRecords.size();
            throw new AuraHandledException(ex.getMessage()); // TODO: should this be thrown OR let continue?
        }

        List<Backlog__c> backlogItems = new List<Backlog__c>();
        Map<String, Schema.SObjectField> backlogItemFieldMap = Backlog__c.getSobjectType().getDescribe().fields.getMap();
        for (List<String> backlogItemRecordValues : backlogItemRecords){
            try {
                Backlog__c record = buildBacklogItem(backlogItemRecordValues, backlogItemFieldMap, newLookupObjectRecordNameToId);
                backlogItems.add(record);
            } catch (Exception ex) {
                errorData.add(new List<String>{'', ex.getMessage(), '' });
                ur.Num_of_Errors__c += 1;
            }
        }

        try {
            List<Database.SaveResult> backlogItemSrList = Database.insert(backlogItems, false);
            for ( Integer i = 0; i < backlogItemSrList.size(); i++){
                Database.SaveResult sr = backlogItemSrList[i];
                SObject sobjRecord = backlogItems[i];
                if (sr.isSuccess()){
                    ur.Num_of_Records_Created__c += 1;
                    successData.add(getCsvRow(sobjRecord, orderedColumnNames));
                } else {
                    ur.Num_of_Errors__c += 1;
                    for(Database.Error error : sr.getErrors()) {
                        List<String> errorRow = new List<String>{
                            String.valueOf(error.getStatusCode()), error.getMessage(), String.join(error.getFields(), ',')
                        };
                        errorRow.addAll(getCsvRow(sobjRecord, orderedColumnNames));
                        errorData.add(errorRow);
                    }
                }
            }
        } catch (Exception ex){
            ur.Num_of_Errors__c += backlogItems.size();
            throw new AuraHandledException(ex.getMessage()); // TODO: should this be thrown OR let continue?
        }

        try {
            insert ur;
        } catch (Exception ex){
            throw new AuraHandledException(ex.getMessage());
        }

        Attachment successCsv = new Attachment();
        successCsv.Name = 'success_' + Datetime.now().format('MM_dd_yyyy_HH_mm_ss') + '.csv';
        successCsv.ParentId = ur.Id;
        successCsv.Body = Blob.valueof(generateCSVString(successData));

        Attachment failureCsv = new Attachment();
        failureCsv.Name = 'failure_' + Datetime.now().format('MM_dd_yyyy_HH_mm_ss') + '.csv';
        failureCsv.ParentId = ur.Id;
        failureCsv.Body = Blob.valueof(generateCSVString(errorData));

        try {
            insert new List<Attachment>{successCsv, failureCsv};
        } catch (Exception ex){
            throw new AuraHandledException(ex.getMessage());
        }

        return new BacklogItemUploadResult(ur, successCsv.Id, failureCsv.Id);
    }

    private Backlog__c buildBacklogItem(List<String> backlogItemRecordValues, Map<String, Schema.SObjectField> backlogItemFieldMap,
        Map<String, Map<String, String>> newLookupObjectRecordNameToId) {

        Backlog__c record = new Backlog__c();

        for (String columnName : columnHeaderIndexRecords.keySet()) {
            Integer columnDataIndex = columnHeaderIndexRecords.get(columnName);
            String columnDataValue = backlogItemRecordValues.get(columnDataIndex).trim();
            if (String.isNotBlank(columnDataValue) && columnHeaderToSalesforceField.containsKey(columnName)) {
                String columnSalesforceApiName = columnHeaderToSalesforceField.get(columnName);
                Schema.DescribeFieldResult sobjFieldDescribe = backlogItemFieldMap.get(columnSalesforceApiName).getDescribe();
                Schema.DisplayType fieldType = sobjFieldDescribe.getType();
                if (fieldType == Schema.DisplayType.Reference) {
                    Boolean populateLookupFieldWithRawValue = true;
                    if (backlogItemFieldToLookupDetail.containsKey(columnSalesforceApiName)) {
                        // some new records were created
                        BacklogItemUploadFieldMappingConfig.LookupDetail lookupDetail =
                             backlogItemFieldToLookupDetail.get(columnSalesforceApiName);
                        String sObjectName = lookupDetail.lookupTargetObjectName;
                        Set<String> newRelatedRecords = new Set<String>(lookupDetail.newRelatedRecords);
                        if (nonCreatableRelatedObjectToRecordNames.containsKey(sObjectName)
                            && nonCreatableRelatedObjectToRecordNames.get(sObjectName).contains(columnDataValue)){
                            populateLookupFieldWithRawValue = false;
                        }
                        else if (newLookupObjectRecordNameToId.containsKey(sObjectName)){
                            // new record created, get the id by name value
                            Map<String, String> newRecordNameToIds = newLookupObjectRecordNameToId.get(sObjectName);
                            if ( newRecordNameToIds.containsKey( columnDataValue ) ) {
                                record.put(columnSalesforceApiName, newRecordNameToIds.get( columnDataValue ) );
                                populateLookupFieldWithRawValue = false;
                            }
                        } else if (lookupDetail.existingRelatedRecordMap.containsKey(columnDataValue)) {
                            String existingLookupId = lookupDetail.existingRelatedRecordMap.get(columnDataValue);
                            record.put(columnSalesforceApiName, existingLookupId );
                            populateLookupFieldWithRawValue = false;
                        } else if (!lookupDetail.createNewRelatedRecords && newRelatedRecords.contains(columnDataValue)) {
                            populateLookupFieldWithRawValue = false;
                        }
                    }
                    if (populateLookupFieldWithRawValue && SObjectServices.isValidId(columnDataValue)) {
                        record.put(columnSalesforceApiName, columnDataValue );
                    }
                } else {
                    if (backlogItemFieldMap.containsKey(columnSalesforceApiName)) {
                        populateSObjectValue(record, fieldType, columnSalesforceApiName, columnDataValue);
                    }
                }
            }
        }

        return record;
    }

    /**
    * @throws System.TypeException
    */
    private void populateSObjectValue(SObject record, Schema.DisplayType fieldType, String apiName, String dataValue) {
        if (fieldType == Schema.DisplayType.Boolean ){
            record.put(apiName, Boolean.valueOf(dataValue) );
        } else if ( fieldType == Schema.DisplayType.Datetime){
            record.put(apiName, Datetime.valueOf(dataValue) );
        } else if ( fieldType == Schema.DisplayType.Date){
            record.put(apiName, Date.valueOf(dataValue) );
        } else if ( fieldType == Schema.DisplayType.Integer ||
                      fieldType == Schema.DisplayType.Double ||
                      fieldType == Schema.DisplayType.Currency ||
                      fieldType == Schema.DisplayType.Percent ) {
            record.put(apiName, Decimal.valueOf(dataValue) );
        } else {
            record.put(apiName, dataValue );
        }
    }

    private static String generateCSVString(List<List<String>> csvData) {
        String csvString = '';
        for (List<String> rowData : csvData) {
            csvString += String.join(rowData, ',') + '\n';
        }

        return csvString;
    }

    private List<String> getCsvRow(SObject record, List<String> columnNames) {
        List<String> columns = new List<String>();

        columns.add(String.valueOf(record.get('Id')));

        for (String columnName : columnNames) {
            String apiName = columnHeaderToSalesforceField.get(columnName);
            if (record.get(apiName) == null) {
                columns.add('');
            } else {
                String recordValue = String.valueOf(record.get(apiName));
                columns.add(recordValue.escapeCsv());
            }
        }
        return columns;
    }

}
