@isTest
private class TestBacklogItemDataLoader {
    static testMethod void createRecords_csvValueWithCommas() {
        String descriptionField = SObjectServices.getFullyQualifiedName('Description__c');
        String descriptionValue = 'commas should, not be abused';

        BacklogItemUploadFieldMappingConfig fieldMappingConfig = new BacklogItemUploadFieldMappingConfig(descriptionField);
        fieldMappingConfig.isMapped = true;
        fieldMappingConfig.salesforceFieldName = descriptionField;

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        mcd.mappingConfigurations.add(fieldMappingConfig);

        Map<String, Integer> columnHeaderIndexRecords = new Map<String, Integer>();
        columnHeaderIndexRecords.put(descriptionField, 0);

        List<List<String>> backlogItemRecords = new List<List<String>>();
        List<String> validRecord = new List<String>{descriptionValue};

        backlogItemRecords.add(validRecord);

        BacklogItemDataLoader dataLoader = new BacklogItemDataLoader(mcd, columnHeaderIndexRecords, backlogItemRecords);

        Test.startTest();
            BacklogItemUploadResult uploadResultObj = dataLoader.createRecords();
        Test.stopTest();

        System.assertEquals(1, uploadResultObj.record.Num_of_Records_Created__c,
            'The number of successful records created should be set on the Upload Result object.');
        System.assertEquals(0, uploadResultObj.record.Num_of_Errors__c,
            'No errors should occur when there are commas in a field value.');

        Attachment successAttachment = [SELECT Id, Body FROM Attachment WHERE Id = :uploadResultObj.successCsvId];
        Attachment failureAttachment = [SELECT Id, Body FROM Attachment WHERE Id = :uploadResultObj.failureCsvId];

        List<List<String>> successCsv = getCsvFromBlob(successAttachment.Body);
        System.assertEquals(2, successCsv.size(), 'a header row and a row for each successful record should be created');
        List<String> header = successCsv[0];
        System.assertEquals(2, header.size(), 'The header row should contain the Id and each selected column');
        System.assertEquals('Id', header[0], 'The header row should contain the Id');
        System.assertEquals(descriptionField, header[1], 'The header row should contain the selected column');
        List<String> row1 = successCsv[1];
        System.assertNotEquals(null, row1[0], 'The Id of the created record should be set');
        //Instead of worry about properly parsing commas in the csv attachment, just join the last two colummns based on the known value
        System.assertEquals('"' + descriptionValue +  '"', row1[1] +',' + row1[2], 'The data row should contain the value of the column with the commas');

        List<List<String>> failureCsv = getCsvFromBlob(failureAttachment.Body);
        System.assertEquals(1, failureCsv.size(), 'Only a header row should exist when there are no errors');
    }

    static testMethod void createRecords_csvValueWithNewLines() {
        String descriptionField = SObjectServices.getFullyQualifiedName('Description__c');
        String descriptionValue = 'new lines should\n not be abused';

        BacklogItemUploadFieldMappingConfig fieldMappingConfig = new BacklogItemUploadFieldMappingConfig(descriptionField);
        fieldMappingConfig.isMapped = true;
        fieldMappingConfig.salesforceFieldName = descriptionField;

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        mcd.mappingConfigurations.add(fieldMappingConfig);

        Map<String, Integer> columnHeaderIndexRecords = new Map<String, Integer>();
        columnHeaderIndexRecords.put(descriptionField, 0);

        List<List<String>> backlogItemRecords = new List<List<String>>();
        List<String> validRecord = new List<String>{descriptionValue};

        backlogItemRecords.add(validRecord);

        BacklogItemDataLoader dataLoader = new BacklogItemDataLoader(mcd, columnHeaderIndexRecords, backlogItemRecords);

        Test.startTest();
            BacklogItemUploadResult uploadResultObj = dataLoader.createRecords();
        Test.stopTest();

        System.assertEquals(1, uploadResultObj.record.Num_of_Records_Created__c,
            'The number of successful records created should be set on the Upload Result object.');
        System.assertEquals(0, uploadResultObj.record.Num_of_Errors__c,
            'No errors should occur when there are commas in a field value.');

        Attachment successAttachment = [SELECT Id, Body FROM Attachment WHERE Id = :uploadResultObj.successCsvId];

        List<List<String>> successCsv = getCsvFromBlob(successAttachment.Body);
        //For now we aren't parsing new lines when reading the attachment, so assume an extra line
        System.assertEquals(3, successCsv.size(), 'a header row and a row for each successful record should be created');
        List<String> header = successCsv[0];
        System.assertEquals(2, header.size(), 'The header row should contain the Id and each selected column');
        System.assertEquals('Id', header[0], 'The header row should contain the Id');
        System.assertEquals(descriptionField, header[1], 'The header row should contain the selected column');
        List<String> row1 = successCsv[1];
        row1.addAll(successCsv[2]);
        System.assertNotEquals(null, row1[0], 'The Id of the created record should be set');
        System.assertEquals('"' + descriptionValue +  '"', row1[1] +'\n' + row1[2], 'The data row should contain the value of the column with the new line');
    }

    static testMethod void createRecords_csvContent() {
        String devEffortField = SObjectServices.getFullyQualifiedName('Dev_Effort__c');
        String devEffortValue = '8';

        BacklogItemUploadFieldMappingConfig fieldMappingConfig = new BacklogItemUploadFieldMappingConfig(devEffortField);
        fieldMappingConfig.isMapped = true;
        fieldMappingConfig.salesforceFieldName = devEffortField;

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        mcd.mappingConfigurations.add(fieldMappingConfig);

        Map<String, Integer> columnHeaderIndexRecords = new Map<String, Integer>();
        columnHeaderIndexRecords.put(devEffortField, 0);

        List<List<String>> backlogItemRecords = new List<List<String>>();
        List<String> invalidRecord = new List<String>{'fake dev effort'};
        List<String> validRecord = new List<String>{devEffortValue};

        backlogItemRecords.add(invalidRecord);
        backlogItemRecords.add(validRecord);

        BacklogItemDataLoader dataLoader = new BacklogItemDataLoader(mcd, columnHeaderIndexRecords, backlogItemRecords);

        Test.startTest();
            BacklogItemUploadResult uploadResultObj = dataLoader.createRecords();
        Test.stopTest();

        System.assertEquals(1, uploadResultObj.record.Num_of_Records_Created__c,
            'The number of successful records created should be set on the Upload Result object.');
        System.assertEquals(1, uploadResultObj.record.Num_of_Errors__c,
            'The number of failed record inserts should be set on the Upload Result object.');

        Attachment successAttachment = [SELECT Id, Body FROM Attachment WHERE Id = :uploadResultObj.successCsvId];
        Attachment failureAttachment = [SELECT Id, Body FROM Attachment WHERE Id = :uploadResultObj.failureCsvId];

        List<List<String>> successCsv = getCsvFromBlob(successAttachment.Body);
        System.assertEquals(2, successCsv.size(), 'a header row and a row for each successful record should be created');
        List<String> header = successCsv[0];
        System.assertEquals(2, header.size(), 'The header row should contain the Id and each selected column');
        System.assertEquals('Id', header[0], 'The header row should contain the Id');
        System.assertEquals(devEffortField, header[1], 'The header row should contain the selected column');
        List<String> row1 = successCsv[1];
        System.assertNotEquals(null, row1[0], 'The Id of the created record should be set');
        System.assertEquals(devEffortValue, row1[1], 'The data row should contain the value of the inserted column');

        List<List<String>> failureCsv = getCsvFromBlob(failureAttachment.Body);
        System.assertEquals(2, failureCsv.size(), 'a header row and a row for each successful record should be created');
        header = failureCsv[0];
        System.assertEquals(5, header.size(), 'The header row should contain the failure headers and the mapped column');
        System.assertEquals(devEffortField, header[4], 'The header row should contain the mapped column');
        row1 = failureCsv[1];
        System.assertEquals('Invalid decimal: '+ invalidRecord[0], row1[1], 'The data row should contain the error message');
    }

    static testMethod void createRecords_ignoringNewValues_shouldIgnore(){

        String newPersonaFieldValue = UserInfo.getUserId(); // non-valid persona id
        String personaField = SObjectServices.getFullyQualifiedName('Persona__c');

        BacklogItemUploadFieldMappingConfig fieldMappingConfig = new BacklogItemUploadFieldMappingConfig(personaField);
        fieldMappingConfig.isMapped = true;
        fieldMappingConfig.isLookup = true;
        fieldMappingConfig.lookupDetail.createNewRelatedRecords = false;
        fieldMappingConfig.lookupDetail.newRelatedRecords.add(newPersonaFieldValue);
        fieldMappingConfig.lookupDetail.lookupTargetObjectName = Schema.Persona__c.getSObjectType().getDescribe().getName();
        fieldMappingConfig.salesforceFieldName = personaField;

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        mcd.mappingConfigurations.add(fieldMappingConfig);

        Map<String, Integer> columnHeaderIndexRecords = new Map<String, Integer>();
        columnHeaderIndexRecords.put(personaField, 0);

        List<List<String>> backlogItemRecords = new List<List<String>>();
        List<String> validRecord = new List<String>{newPersonaFieldValue};

        backlogItemRecords.add(validRecord);

        BacklogItemDataLoader dataLoader = new BacklogItemDataLoader(mcd, columnHeaderIndexRecords, backlogItemRecords);

        Test.startTest();
            BacklogItemUploadResult uploadResultObj = dataLoader.createRecords();
        Test.stopTest();

        List<Persona__c> personas = [Select Id, Name from Persona__c];
        List<Backlog__c> backlogItems = [Select Id, Persona__c from Backlog__c];

        System.assertEquals(1, uploadResultObj.record.Num_of_Records_Created__c,
            'The number of successful records created should be set correctly on the Upload Result object.');
        System.assertEquals(0, uploadResultObj.record.Num_of_Errors__c,
            'The number of failed record inserts should be set correctly on the Upload Result object.');
        System.assertEquals(0, personas.size(), 'No new related records should be created when create new related records is set to false.');

        System.assertEquals(1, backlogItems.size(), 'A Backlog Item should be created.');
        System.assertEquals(null, backlogItems[0].Persona__c,
            'The ignored lookup value should be blank');
    }

    static testMethod void createRecords_IdPassedAsValueNotFoundShouldCreateNewRecord(){

        String newPersonaFieldValue = UserInfo.getUserId(); // non-valid persona id
        String personaField = SObjectServices.getFullyQualifiedName('Persona__c');

        BacklogItemUploadFieldMappingConfig fieldMappingConfig = new BacklogItemUploadFieldMappingConfig(personaField);
        fieldMappingConfig.isMapped = true;
        fieldMappingConfig.isLookup = true;
        fieldMappingConfig.lookupDetail.createNewRelatedRecords = true;
        fieldMappingConfig.lookupDetail.newRelatedRecords.add(newPersonaFieldValue);
        fieldMappingConfig.lookupDetail.lookupTargetObjectName = Schema.Persona__c.getSObjectType().getDescribe().getName();
        fieldMappingConfig.salesforceFieldName = personaField;

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        mcd.mappingConfigurations.add(fieldMappingConfig);

        Map<String, Integer> columnHeaderIndexRecords = new Map<String, Integer>();
        columnHeaderIndexRecords.put(personaField, 0);

        List<List<String>> backlogItemRecords = new List<List<String>>();
        List<String> validRecord = new List<String>{newPersonaFieldValue};

        backlogItemRecords.add(validRecord);

        BacklogItemDataLoader dataLoader = new BacklogItemDataLoader(mcd, columnHeaderIndexRecords, backlogItemRecords);

        List<Persona__c> personas = [Select Id, Name from Persona__c];
        List<Backlog__c> backlogItems = [Select Id, Persona__c from Backlog__c ];
        System.assertEquals(0, personas.size(), 'We expect NO Personas to exist.');
        System.assertEquals(0, backlogItems.size(), 'We expect no new Backlog Item records to exist.');

        Test.startTest();
            BacklogItemUploadResult uploadResultObj = dataLoader.createRecords();
        Test.stopTest();

        personas = [Select Id, Name from Persona__c];
        backlogItems = [Select Id, Persona__c from Backlog__c ];

        System.assertEquals(2, uploadResultObj.record.Num_of_Records_Created__c,
            'The number of successful records created should be set correctly on the Upload Result object.');
        System.assertEquals(0, uploadResultObj.record.Num_of_Errors__c,
            'The number of failed record inserts should be set correctly on the Upload Result object.');
        System.assertEquals(1, personas.size(), 'We expect a Persona to be created.');
        System.assertEquals(newPersonaFieldValue, personas[0].Name,
            'We expect a Persona to be created with the correct name.');

        System.assertEquals(1, backlogItems.size(), 'We expect Backlog Item records to be created.');
        System.assertEquals(personas[0].Id, backlogItems[0].Persona__c,
            'We expect the Backlog Item record to be created with the correct persona value.');
    }

    static testMethod void createRecords_IdPassedAsNameValueOnExistingRecord(){

        String newPersonaFieldValue = UserInfo.getUserId(); // non-valid persona id
        String personaField = SObjectServices.getFullyQualifiedName('Persona__c');

        Persona__c testPersona = TestingUtils.buildPersonas(1)[0];
        testPersona.Name = newPersonaFieldValue;
        insert testPersona;

        BacklogItemUploadFieldMappingConfig fieldMappingConfig = new BacklogItemUploadFieldMappingConfig(personaField);
        fieldMappingConfig.isMapped = true;
        fieldMappingConfig.isLookup = true;
        fieldMappingConfig.lookupDetail.createNewRelatedRecords = true;
        fieldMappingConfig.lookupDetail.existingRelatedRecordMap = new Map<String, String>{newPersonaFieldValue => testPersona.Id};
        fieldMappingConfig.lookupDetail.lookupTargetObjectName = Schema.Persona__c.getSObjectType().getDescribe().getName();
        fieldMappingConfig.salesforceFieldName = personaField;

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        mcd.mappingConfigurations.add(fieldMappingConfig);

        Map<String, Integer> columnHeaderIndexRecords = new Map<String, Integer>();
        columnHeaderIndexRecords.put(personaField, 0);

        List<List<String>> backlogItemRecords = new List<List<String>>();
        List<String> validRecord = new List<String>{newPersonaFieldValue};

        backlogItemRecords.add(validRecord);

        BacklogItemDataLoader dataLoader = new BacklogItemDataLoader(mcd, columnHeaderIndexRecords, backlogItemRecords);

        List<Backlog__c> backlogItems = [Select Id, Persona__c from Backlog__c ];
        System.assertEquals(0, backlogItems.size(), 'We expect no new Backlog Item records to exist.');

        Test.startTest();
            BacklogItemUploadResult uploadResultObj = dataLoader.createRecords();
        Test.stopTest();

        List<Persona__c> personas = [Select Id, Name from Persona__c];
        backlogItems = [Select Id, Persona__c from Backlog__c ];

        System.assertEquals(1, uploadResultObj.record.Num_of_Records_Created__c,
            'The number of successful records created should be set correctly on the Upload Result object.');
        System.assertEquals(0, uploadResultObj.record.Num_of_Errors__c,
            'The number of failed record inserts should be set correctly on the Upload Result object.');
        System.assertEquals(1, personas.size(), 'We expect no new Persona records to be created.');
        System.assertEquals(newPersonaFieldValue, personas[0].Name,
            'We expect a Persona to have the same name.');
        System.assertEquals(1, backlogItems.size(), 'We expect Backlog Item records to be created.');
        System.assertEquals(testPersona.Id, backlogItems[0].Persona__c,
            'We expect the Backlog Item record to be created with the correct persona value.');
    }

    static testMethod void createRecords_populateExistingIdWhenIgnoringNewValues(){

        String personaField = SObjectServices.getFullyQualifiedName('Persona__c');

        Persona__c existingPersona = TestingUtils.buildPersonas(1)[0];
        existingPersona.Name = 'admin';
        insert existingPersona;

        BacklogItemUploadFieldMappingConfig fieldMappingConfig = new BacklogItemUploadFieldMappingConfig(personaField);
        fieldMappingConfig.isMapped = true;
        fieldMappingConfig.isLookup = true;
        fieldMappingConfig.lookupDetail.createNewRelatedRecords = false;
        fieldMappingConfig.lookupDetail.lookupTargetObjectName = Schema.Persona__c.getSObjectType().getDescribe().getName();
        fieldMappingConfig.salesforceFieldName = personaField;

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        mcd.mappingConfigurations.add(fieldMappingConfig);

        Map<String, Integer> columnHeaderIndexRecords = new Map<String, Integer>();
        columnHeaderIndexRecords.put(personaField, 0);

        List<List<String>> backlogItemRecords = new List<List<String>>();
        List<String> validRecord = new List<String>{existingPersona.Id};

        backlogItemRecords.add(validRecord);

        BacklogItemDataLoader dataLoader = new BacklogItemDataLoader(mcd, columnHeaderIndexRecords, backlogItemRecords);

        Test.startTest();
            BacklogItemUploadResult uploadResultObj = dataLoader.createRecords();
        Test.stopTest();

        List<Persona__c> personas = [Select Id, Name from Persona__c];
        List<Backlog__c> backlogItems = [Select Id, Persona__c from Backlog__c ];

        System.assertEquals(1, uploadResultObj.record.Num_of_Records_Created__c,
            'The number of successful records created should be set correctly on the Upload Result object.');
        System.assertEquals(0, uploadResultObj.record.Num_of_Errors__c,
            'The number of failed record inserts should be set correctly on the Upload Result object.');
        System.assertEquals(1, personas.size(), 'No new Persona records should be created.');
        System.assertEquals(1, backlogItems.size(), 'A Backlog Item record should be created.');
        System.assertEquals(existingPersona.Id, backlogItems[0].Persona__c,
            'The Backlog Item record should be created with the existing persona Id.');
    }

    static testMethod void createRecords_avoidInitializingRecordsWhenAutoNumberFieldIsPopulated(){

        String newParentBacklogValue = 'Item-0234';
        String parentBacklogField = SObjectServices.getFullyQualifiedName('Parent_User_Story__c');
        String backlogObjectType = Schema.Backlog__c.getSObjectType().getDescribe().getName();

        BacklogItemUploadFieldMappingConfig fieldMappingConfig = new BacklogItemUploadFieldMappingConfig(parentBacklogField);
        fieldMappingConfig.isMapped = true;
        fieldMappingConfig.isLookup = true;
        fieldMappingConfig.lookupDetail.createNewRelatedRecords = true;
        fieldMappingConfig.lookupDetail.newRelatedRecords.add(newParentBacklogValue);
        fieldMappingConfig.lookupDetail.lookupTargetObjectName = backlogObjectType;
        fieldMappingConfig.salesforceFieldName = parentBacklogField;

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        mcd.mappingConfigurations.add(fieldMappingConfig);

        Map<String, Integer> columnHeaderIndexRecords = new Map<String, Integer>();
        columnHeaderIndexRecords.put(parentBacklogField, 0);

        List<List<String>> backlogItemRecords = new List<List<String>>();

        Test.startTest();
            BacklogItemDataLoader dataLoader = new BacklogItemDataLoader(mcd, columnHeaderIndexRecords, backlogItemRecords);
        Test.stopTest();

        System.assertNotEquals( null, dataLoader.nonCreatableRelatedObjectToRecordNames, 'The non creatable map should be populated');
        System.assertEquals(1, dataLoader.nonCreatableRelatedObjectToRecordNames.size(), 'The non creatable map should have one object type in it');
        System.assert(dataLoader.nonCreatableRelatedObjectToRecordNames.containsKey(backlogObjectType), 'The non creatable map should have the backlog object type in it');
        System.assertEquals(1, dataLoader.nonCreatableRelatedObjectToRecordNames.get(backlogObjectType).size(), 'The non creatable map should have 1 parent backlog record in it');
        System.assert(dataLoader.nonCreatableRelatedObjectToRecordNames.get(backlogObjectType).contains(newParentBacklogValue), 'The non creatable map should have the corret record name');
        System.assert(dataLoader.relatedObjectToRecords.isEmpty(), 'The creatable record list should be empty');
    }

    static testMethod void createRecords_avoidCreatingRecordsWhenAutoNumberFieldIsPopulated(){

        String newParentBacklogValue = 'Item-0234';
        String parentBacklogField = SObjectServices.getFullyQualifiedName('Parent_User_Story__c');
        String backlogObjectType = Schema.Backlog__c.getSObjectType().getDescribe().getName();

        BacklogItemUploadFieldMappingConfig fieldMappingConfig = new BacklogItemUploadFieldMappingConfig(parentBacklogField);
        fieldMappingConfig.isMapped = true;
        fieldMappingConfig.isLookup = true;
        fieldMappingConfig.lookupDetail.createNewRelatedRecords = true;
        fieldMappingConfig.lookupDetail.newRelatedRecords.add(newParentBacklogValue);
        fieldMappingConfig.lookupDetail.lookupTargetObjectName = backlogObjectType;
        fieldMappingConfig.salesforceFieldName = parentBacklogField;

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        mcd.mappingConfigurations.add(fieldMappingConfig);

        Map<String, Integer> columnHeaderIndexRecords = new Map<String, Integer>();
        columnHeaderIndexRecords.put(parentBacklogField, 0);

        List<List<String>> backlogItemRecords = new List<List<String>>();
        List<String> validRecord = new List<String>{newParentBacklogValue};

        backlogItemRecords.add(validRecord);
        BacklogItemDataLoader dataLoader = new BacklogItemDataLoader(mcd, columnHeaderIndexRecords, backlogItemRecords);

        Test.startTest();
            BacklogItemUploadResult uploadResultObj = dataLoader.createRecords();
        Test.stopTest();

        System.assertNotEquals(null, uploadResultObj, 'The upload result object should be instantiated');
        System.assertNotEquals(null, uploadResultObj.successCsvId, 'The upload result object success CSV Id should be set');
        System.assertNotEquals(null, uploadResultObj.failureCsvId, 'The upload result object failure CSV Id should be set');

        List<Backlog__c> backlogItems = [Select Id, Parent_User_Story__c from Backlog__c ];
        Attachment successAttachment = [SELECT Id, Body FROM Attachment WHERE Id = :uploadResultObj.successCsvId];
        Attachment failureAttachment = [SELECT Id, Body FROM Attachment WHERE Id = :uploadResultObj.failureCsvId];

        System.assertEquals(1, uploadResultObj.record.Num_of_Records_Created__c,
            'The number of successful records created should be set correctly on the Upload Result object.');
        System.assertEquals(1, uploadResultObj.record.Num_of_Errors__c,
            'The number of failed record inserts should be set correctly on the Upload Result object.');
        System.assertEquals(1, backlogItems.size(), 'One Backlog Item records should be created.');
        System.assertEquals(null, backlogItems[0].Parent_User_Story__c,
            'The Backlog Item record should be created without the parent backlog.');

        List<List<String>> failureCsv = getCsvFromBlob(failureAttachment.Body);
        System.assertEquals(2, failureCsv.size(), 'a failure header row and a row for each failed record should be created');
        List<String> failureHeader = failureCsv[0];
        System.assertEquals(5, failureHeader.size(), 'The failure header row should contain the error columns');
        System.assertEquals('Status Code', failureHeader[0], 'The failure header row should contain the status code');
        System.assertEquals('Message', failureHeader[1], 'The failure header row should contain the message column');
        List<String> failureRow1 = failureCsv[1];
        System.assertEquals(BacklogItemDataLoader.AUTO_NUMBER_ERROR_MESSAGE, failureRow1[1], 'The data row should contain the error message');
        System.assertEquals(BacklogItemDataLoader.AUTO_NUMBER_ERROR_STATUS_CODE, failureRow1[0], 'The data row should contain the error status code');

        List<List<String>> successCsv = getCsvFromBlob(successAttachment.Body);
        System.assertEquals(2, successCsv.size(), 'a success header row and a row for each successful record should be created');
        List<String> successHeader = successCsv[0];
        System.assertEquals(2, successHeader.size(), 'The success header row should contain the Id and the parent backlog column');
        System.assertEquals('Id', successHeader[0], 'The success header row should contain the Id');
        System.assertEquals(parentBacklogField, successHeader[1], 'The success header row should contain the parent backlog field');
        List<String> successRow1 = successCsv[1];
        System.assertEquals(1, successRow1.size(), 'Only one value should be set in the row');
        System.assertEquals(backlogItems[0].Id, successRow1[0], 'The correct backlog id should be detected');
        System.assertNotEquals(null, successRow1[0], 'The Id of the created record should be set');
    }

    private static List<List<String>> getCsvFromBlob(Blob blobBody) {
        String body = blobBody.toString();
        List<String> rows = body.split('\n');
        List<List<String>> cells = new List<List<String>>();
        for (String row : rows) {
            //This isn't handling commas inside quoted strings the moment
            cells.add(row.split(','));
        }
        return cells;
    }
}