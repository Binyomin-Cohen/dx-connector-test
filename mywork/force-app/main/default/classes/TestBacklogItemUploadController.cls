@isTest
private class TestBacklogItemUploadController {

    static testMethod void controllerInitialization(){

        Test.startTest();
            BacklogItemUploadController testController = new BacklogItemUploadController();
        Test.stopTest();

        System.assertNotEquals(null, testController.namespace,'The namespace should not be null');
        System.assert(!testController.namespace.endsWith('__'),'The namespace should not end with underscores');
        System.assertEquals(SObjectServices.CURRENT_NAMESPACE, testController.namespace,
            'We expect the namespace to be initialized properly.');         
    }

    static testMethod void mappingConfigurationData(){

        Test.startTest();
            BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        Test.stopTest();

        System.assertEquals(new List<BacklogItemUploadFieldMappingConfig>(), mcd.mappingConfigurations,
            'We expect the mappingConfigurations to be initialized properly.');
        System.assertEquals(new List<BacklogItemUploadFieldMappingConfig>(), mcd.requiredMappingConfigurations,
            'We expect the requiredMappingConfigurations to be initialized properly.');
        System.assertEquals(new List<String>(), mcd.requiredFieldApiNames,
            'We expect the requiredFieldApiNames to be initialized properly.');
        System.assertEquals(new List<String>(), mcd.lookupFieldApiNames,
            'We expect the lookupFieldApiNames to be initialized properly.');
        System.assertEquals(new List<String>(), mcd.unmappedFields,
            'We expect the unmappedFields to be initialized properly.');
        System.assertEquals(new List<String>(), mcd.uploadedColumnNames,
            'We expect the uploadedColumnNames to be initialized properly.');
        System.assertEquals(new List<String>(), mcd.allBacklogItemFields,
            'We expect the allBacklogItemFields to be initialized properly.');
        System.assertEquals(SObjectServices.getFullyQualifiedName('Backlog__c'), mcd.backlogItemObjectApiName,
            'We expect the object api name initialized properly.');
        System.assertEquals(Schema.describeSObjects( new List<String>{mcd.backlogItemObjectApiName})[0].getLabelPlural(), mcd.backlogItemObjectLabelPlural,
            'We expect the object label name initialized properly.');            
    }

    static testMethod void mappingConfigurationData_autoMapFields(){

        final String TEST_FIELD_1 = 'SomeField1__c';
        final String TEST_FIELD_2 = 'SomeField2';
        final String TEST_FIELD_3 = 'SomeField3';
        final String TEST_FIELD_4 = 'SomeField4Id';
        final String TEST_FIELD_1_LABEL = 'Some Field 1';
        final String TEST_FIELD_2_LABEL = 'Some Field 2';
        final String TEST_FIELD_3_LABEL = 'Some Field 3';
        final String TEST_FIELD_4_LABEL = 'Some Field 4';

        final String OTHER_USER_INPUT_FIELD = 'some other field';

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        // @preCondidtion fields
        mcd.unmappedFields.add(TEST_FIELD_1);
        mcd.unmappedFields.add(TEST_FIELD_2);
        mcd.unmappedFields.add(TEST_FIELD_3);
        mcd.unmappedFields.add(TEST_FIELD_4);
        mcd.requiredFieldApiNames.add(TEST_FIELD_4);
        mcd.lookupFieldApiNames.add(TEST_FIELD_2);

        // Describe call, label to api name
        Map<String, String> labelToApiName = new Map<String, String>();
        labelToApiName.put(TEST_FIELD_1_LABEL.toLowerCase(), TEST_FIELD_1);
        labelToApiName.put(TEST_FIELD_2_LABEL.toLowerCase(), TEST_FIELD_2);
        labelToApiName.put(TEST_FIELD_3_LABEL.toLowerCase(), TEST_FIELD_3);
        labelToApiName.put(TEST_FIELD_4_LABEL.toLowerCase(), TEST_FIELD_4);

        // User loaded CSV columns
        mcd.mappingConfigurations.add(new BacklogItemUploadFieldMappingConfig(TEST_FIELD_1_LABEL));
        mcd.mappingConfigurations.add(new BacklogItemUploadFieldMappingConfig(TEST_FIELD_2));
        mcd.mappingConfigurations.add(new BacklogItemUploadFieldMappingConfig(OTHER_USER_INPUT_FIELD));
        mcd.mappingConfigurations.add(new BacklogItemUploadFieldMappingConfig(TEST_FIELD_4_LABEL));

        Test.startTest();
            mcd.autoMapFields(labelToApiName);
        Test.stopTest();

        System.assertEquals(4, mcd.mappingConfigurations.size(),
            'We expect the mappingConfigurations to contain the user loaded CSV columns.');
        System.assertEquals(TEST_FIELD_1_LABEL, mcd.mappingConfigurations[0].columnName,
            'We expect the mappingConfiguration to contain the correct CSV column name');
        System.assertEquals(TEST_FIELD_1, mcd.mappingConfigurations[0].salesforceFieldName,
            'We expect the mappingConfiguration to be auto-mapped correctly.');
        System.assert(mcd.mappingConfigurations[0].isMapped,
            'We expect the mappingConfiguration to be mapped.');
        System.assert(!mcd.mappingConfigurations[0].isRequired, 'We expect the mappingConfiguration to NOT be required.');
        System.assert(!mcd.mappingConfigurations[0].isLookup, 'We expect the mappingConfiguration to NOT be a lookup field.');

        System.assertEquals(TEST_FIELD_2, mcd.mappingConfigurations[1].columnName,
            'We expect the mappingConfiguration to contain the correct CSV column name');
        System.assertEquals(TEST_FIELD_2, mcd.mappingConfigurations[1].salesforceFieldName,
            'We expect the mappingConfiguration to be auto-mapped correctly.');
        System.assert(mcd.mappingConfigurations[1].isMapped,
            'We expect the mappingConfiguration to be mapped.');
        System.assert(!mcd.mappingConfigurations[1].isRequired, 'We expect the mappingConfiguration to NOT be required.');
        System.assert(mcd.mappingConfigurations[1].isLookup, 'We expect the mappingConfiguration to be a lookup field.');

        System.assertEquals(OTHER_USER_INPUT_FIELD, mcd.mappingConfigurations[2].columnName,
            'We expect the mappingConfiguration to contain the correct CSV column name');
        System.assert(String.isEmpty(mcd.mappingConfigurations[2].salesforceFieldName),
            'We expect the mappingConfiguration to NOT be auto-mapped.');
        System.assert(!mcd.mappingConfigurations[2].isMapped, 'We expect the mappingConfiguration to NOT be mapped.');
        System.assert(!mcd.mappingConfigurations[2].isRequired, 'We expect the mappingConfiguration to NOT be required.');
        System.assert(!mcd.mappingConfigurations[2].isLookup, 'We expect the mappingConfiguration to NOT be a lookup field.');

        System.assertEquals(TEST_FIELD_4_LABEL, mcd.mappingConfigurations[3].columnName,
            'We expect the mappingConfiguration to contain the correct CSV column name');
        System.assertEquals(TEST_FIELD_4, mcd.mappingConfigurations[3].salesforceFieldName,
            'We expect the mappingConfiguration to be auto-mapped correctly.');
        System.assert(mcd.mappingConfigurations[3].isMapped, 'We expect the mappingConfiguration to be mapped.');
        System.assert(mcd.mappingConfigurations[3].isRequired, 'We expect the mappingConfiguration to be required.');
        System.assert(!mcd.mappingConfigurations[3].isLookup, 'We expect the mappingConfiguration to NOT be a lookup field.');

        System.assertEquals(1, mcd.unmappedFields.size(),
            'We expect there to only one unmapped field.');
        System.assertEquals(TEST_FIELD_3, mcd.unmappedFields[0],
            'We expect the correct unmapped field to remain after auto-mapping.');

        System.assertEquals(new List<BacklogItemUploadFieldMappingConfig>(), mcd.requiredMappingConfigurations,
            'We expect the requiredMappingConfigurations to remain empty.');
        System.assertEquals(1, mcd.requiredFieldApiNames.size(),
            'We expect the requiredFieldApiNames to remain the same.');
        System.assertEquals(TEST_FIELD_4, mcd.requiredFieldApiNames[0],
            'We expect the requiredFieldApiNames to be correct.');
        System.assertEquals(1, mcd.lookupFieldApiNames.size(),
            'We expect the lookupFieldApiNames to remain the same.');
        System.assertEquals(TEST_FIELD_2, mcd.lookupFieldApiNames[0],
            'We expect the lookupFieldApiNames to be correct.');
    }

    static testMethod void mappingConfigurationData_populateRequiredMappingConfigurations(){

        final String TEST_FIELD_1 = 'SomeField1__c';
        final String TEST_FIELD_2 = 'SomeField2';
        final String TEST_FIELD_4 = 'SomeField4Id';
        final String TEST_FIELD_1_LABEL = 'Some Field 1';
        final String TEST_FIELD_2_LABEL = 'Some Field 2';
        final String TEST_FIELD_4_LABEL = 'Some Field 4';

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();

        mcd.unmappedFields.add(TEST_FIELD_1);
        mcd.unmappedFields.add(TEST_FIELD_2);
        mcd.requiredFieldApiNames.add(TEST_FIELD_2);
        mcd.requiredFieldApiNames.add(TEST_FIELD_4);

        // User loaded CSV columns
        mcd.mappingConfigurations.add(new BacklogItemUploadFieldMappingConfig(TEST_FIELD_1));
        mcd.mappingConfigurations.add(new BacklogItemUploadFieldMappingConfig(TEST_FIELD_2)); // unmapped required field
        mcd.mappingConfigurations.add(new BacklogItemUploadFieldMappingConfig(TEST_FIELD_4)); // mapped required field
        mcd.mappingConfigurations[0].isMapped = false;
        mcd.mappingConfigurations[0].isRequired = false;
        mcd.mappingConfigurations[1].isMapped = false;
        mcd.mappingConfigurations[1].isRequired = true;
        mcd.mappingConfigurations[2].isMapped = true;
        mcd.mappingConfigurations[2].isRequired = true;
        mcd.mappingConfigurations[2].salesforceFieldName = TEST_FIELD_4;

        Test.startTest();
            mcd.populateRequiredMappingConfigurations();
        Test.stopTest();

        System.assertEquals(1, mcd.unmappedFields.size(),
            'We expect the unmappedRequiredFields to be the correct size, all removing unmapped required fields');
        System.assertEquals(TEST_FIELD_1, mcd.unmappedFields[0],
            'We expect the unmappedRequiredFields to be the correct.');
        Set<String> mappingConfigSet = new Set<String>();
        System.assertEquals(2, mcd.mappingConfigurations.size(),
            'We expect the mappingConfigurations to be the correct size after removing the automapped required fields');
        for (BacklogItemUploadFieldMappingConfig fmc : mcd.mappingConfigurations){
            mappingConfigSet.add(fmc.columnName);
        }
        System.assertEquals(new Set<String>{TEST_FIELD_1, TEST_FIELD_2}, mappingConfigSet,
            'We expect the correct remaining mapping configurations to be correct.');

        Set<String> requiredMappingConfigSet = new Set<String>();
        System.assertEquals(2, mcd.requiredMappingConfigurations.size(),
            'We expect the requiredMappingConfigurations to be the correct size.');
        for (BacklogItemUploadFieldMappingConfig fmc : mcd.requiredMappingConfigurations){
            requiredMappingConfigSet.add(fmc.salesforceFieldName);
        }
        System.assertEquals( new Set<String>{TEST_FIELD_2, TEST_FIELD_4}, requiredMappingConfigSet,
            'We expect the correct required mapping configurations to be correct.');
    }


    static testMethod void buildMappingConfigurations(){

        final String TEST_FIELD_1 = 'SomeField1Lookup';
        final String TEST_FIELD_2 = 'SomeField2Required';
        final String REAL_TEST_FIELD_1 = SObjectServices.getFullyQualifiedName('Persona__c');
        final String REAL_TEST_FIELD_2 = SObjectServices.getFullyQualifiedName('Dev_Effort__c');

        final String TEST_FIELD_1_LABEL = 'Some Field1 Lookup';
        final String TEST_FIELD_2_LABEL = 'Some Field2 Required';
        final String REAL_TEST_FIELD_1_LABEL = 'Persona ';
        final String REAL_TEST_FIELD_2_LABEL = 'Dev Effort';

        List<String> userInputColumns = new List<String>{TEST_FIELD_1, TEST_FIELD_2, REAL_TEST_FIELD_1};

        Set<String> userInputColumnSet = new Set<String>(userInputColumns);

        BacklogItemUploadController.backlogItemFieldInfo = new SObjectServices.SObjectFieldInfo(Schema.SObjectType.Backlog__c);
        // Expected Functionality - instead of calling SObjectFieldInfo.populateFieldInfo
        BacklogItemUploadController.backlogItemFieldInfo.fieldsAvailable.add(REAL_TEST_FIELD_1);
        BacklogItemUploadController.backlogItemFieldInfo.fieldsAvailable.add(REAL_TEST_FIELD_2);
        BacklogItemUploadController.backlogItemFieldInfo.required.add(TEST_FIELD_2);
        BacklogItemUploadController.backlogItemFieldInfo.lookups.add(TEST_FIELD_1);
        BacklogItemUploadController.backlogItemFieldInfo.labelToApiNames.put(TEST_FIELD_1_LABEL, TEST_FIELD_1);
        BacklogItemUploadController.backlogItemFieldInfo.labelToApiNames.put(TEST_FIELD_2_LABEL, TEST_FIELD_2);
        BacklogItemUploadController.backlogItemFieldInfo.labelToApiNames.put(REAL_TEST_FIELD_1_LABEL, REAL_TEST_FIELD_1);
        BacklogItemUploadController.backlogItemFieldInfo.labelToApiNames.put(REAL_TEST_FIELD_2_LABEL, REAL_TEST_FIELD_2);


        Set<String> unmapped = new Set<String>(BacklogItemUploadController.backlogItemFieldInfo.fieldsAvailable);
        Set<String> required = new Set<String>(BacklogItemUploadController.backlogItemFieldInfo.required);
        Set<String> lookups = new Set<String>(BacklogItemUploadController.backlogItemFieldInfo.lookups);

        Test.startTest();
            BacklogItemUploadMappingConfig mcd = BacklogItemUploadController.buildMappingConfigurations(userInputColumns);
        Test.stopTest();

        System.assertNotEquals(null, mcd, 'We expect the result to NOT be null.');
        System.assertEquals(userInputColumns, mcd.uploadedColumnNames,
            'We expect the uploaded columns result to be correct, all column names user has uploaded.');
        System.assertEquals(lookups, new Set<String>(mcd.lookupFieldApiNames), 'We expect the backlog item fields result to be correct.');
        System.assertEquals(required, new Set<String>(mcd.requiredFieldApiNames), 'We expect the backlog item lookup fields result to be correct.');

        System.assert(!mcd.allBacklogItemFields.isEmpty(), 'We expect the all backlog item fields to be populated.');
        System.assertEquals(BacklogItemUploadController.backlogItemFieldInfo.labelToApiNames.values(), mcd.allBacklogItemFields,
            'We expect the backlog item fields result to be correct.');
        System.assertEquals(userInputColumns.size(), mcd.mappingConfigurations.size(),
            'We expect the size of the mappingConfigurations to be correct after auto-mapped required fields are removed.');
        System.assertEquals(1, mcd.requiredMappingConfigurations.size(), 'We expect the size of the requiredMappingConfigurations to be correct. ');
        System.assertEquals(TEST_FIELD_2, mcd.requiredMappingConfigurations[0].salesforceFieldName, 'We expect the size of the requiredMappingConfigurations to be correct.');

        Map<String, BacklogItemUploadFieldMappingConfig> mappingConfigColumns = new Map<String, BacklogItemUploadFieldMappingConfig>();
        for (BacklogItemUploadFieldMappingConfig fmconfig : mcd.mappingConfigurations){
            mappingConfigColumns.put(fmconfig.columnName, fmconfig);
        }
        System.assertEquals(new Set<String>(userInputColumns), mappingConfigColumns.keySet(),
            'We expect the mappingConfigurations to be initialized correctly, all input fields except auto-mapped required fields.');
        System.assertEquals(REAL_TEST_FIELD_1, mappingConfigColumns.get(REAL_TEST_FIELD_1).salesforceFieldName,
            'We expect the real mappingConfigurations to be automapped correctly.');
        System.assertEquals(new Set<String>{REAL_TEST_FIELD_2}, new Set<String>(mcd.unmappedFields),
            'We expect the backlog item unmapped fields result to be the remaining unmapped real fields');

    }

    static testMethod void getRelatedRecords() {

        String EXISTING_PERSONA = 'administrator';
        String NEW_PERSONA = 'admin';

        Persona__c persona1 = new Persona__c(Name=EXISTING_PERSONA);
        insert persona1;

        List<String> lookupValues = new List<String>{ EXISTING_PERSONA, NEW_PERSONA, persona1.Id};

        BacklogItemUploadFieldMappingConfig fieldConfig = new BacklogItemUploadFieldMappingConfig('lookupColumn');
        fieldConfig.isLookup = true;
        fieldConfig.salesforceFieldName = SObjectServices.getFullyQualifiedName('Persona__c');

        Test.startTest();

            BacklogItemUploadFieldMappingConfig.LookupDetail result = BacklogItemUploadController.getRelatedRecords(JSON.serialize(fieldConfig), lookupValues);

        Test.stopTest();

        System.assertEquals(new Set<String>{EXISTING_PERSONA}, result.existingRelatedRecordMap.keySet(), 'Existing values should be mapped.');
        System.assertEquals(persona1.Id, result.existingRelatedRecordMap.get(EXISTING_PERSONA), 'Existing values should be mapped to their id.');
        System.assertEquals(1, result.newRelatedRecords.size(), 'Non existing values should be returned');
        System.assertEquals(NEW_PERSONA, result.newRelatedRecords[0], 'Non existing values should be returned');
        System.assertEquals(SObjectServices.getFullyQualifiedName('Persona__c'), result.lookupTargetObjectName, 'The target sobject type should be populated on the config');
        System.assertEquals(Schema.describeSObjects( new List<String>{SObjectServices.getFullyQualifiedName('Persona__c')})[0].getLabel(), result.lookupTargetObjectLabel, 'The target sobject label should be populated on the config');
        System.assertEquals(true, result.createNewRelatedRecords, 'The createNewRecords value should be defaulted to true');
    }

    static testMethod void getRelatedRecords_ignoreBlankValues() {
        List<String> lookupValues = new List<String>{ null, '', '    ' };

        BacklogItemUploadFieldMappingConfig fieldConfig = new BacklogItemUploadFieldMappingConfig('lookupColumn');
        fieldConfig.isLookup = true;
        fieldConfig.salesforceFieldName = SObjectServices.getFullyQualifiedName('Persona__c');

        Test.startTest();

            BacklogItemUploadFieldMappingConfig.LookupDetail result = BacklogItemUploadController.getRelatedRecords(JSON.serialize(fieldConfig), lookupValues);

        Test.stopTest();

        System.assertEquals(0, result.newRelatedRecords.size(), 'blank values should be ignored');
        System.assertEquals(0, result.existingRelatedRecordMap.size(), 'blank values should be ignored');
    }

    static testMethod void getRelatedRecords_unsupportedType() {
        String EXISTING_USER = UserInfo.getUserId();
        String NEW_USER = 'Jerry Kwong';

        List<String> lookupValues = new List<String>{ EXISTING_USER, NEW_USER};

        BacklogItemUploadFieldMappingConfig fieldConfig = new BacklogItemUploadFieldMappingConfig('lookupColumn');
        fieldConfig.isLookup = true;
        fieldConfig.salesforceFieldName = SObjectServices.getFullyQualifiedName('OwnerId');

        Test.startTest();

            BacklogItemUploadFieldMappingConfig.LookupDetail result = BacklogItemUploadController.getRelatedRecords(JSON.serialize(fieldConfig), lookupValues);

        Test.stopTest();

        System.assertEquals(1, result.newRelatedRecords.size(), 'Non existing values should be returned');
        System.assertEquals(NEW_USER, result.newRelatedRecords[0], 'Non existing values should be returned' + result.newRelatedRecords);
        System.assertEquals(true, result.hasLookupError, 'Unsupported Object types should be marked as having a lookup error');
    }

    private static BacklogItemUploadFieldMappingConfig createSimpleMappedFieldMappingConfig(String columnName, String salesforceField){
        BacklogItemUploadFieldMappingConfig fmc = new BacklogItemUploadFieldMappingConfig(columnName);
        fmc.isMapped = true;
        fmc.salesforceFieldName = salesforceField;
        return fmc;
    }

    static testMethod void createRecords() {

        String persona1 = 'Admin';
        Persona__c testPersona = TestingUtils.buildPersonas(1)[0];
        testPersona.Name = persona1;
        insert testPersona;

        String IN_PROGRESS_STATUS = 'In-Progress';
        String DEV_COMPLETE_STATUS = 'Dev Complete';

        Set<String> expectedStatuses = new Set<String>{IN_PROGRESS_STATUS, DEV_COMPLETE_STATUS};

        String expectedNewProject1 = 'New Project 1';
        String expectedNewProject2 = 'New Project 2';
        String expectedNewSprint1 = 'New Sprint 1';

        String instance1 = 'Dev Sandbox 1';
        String release1 = 'Release Number 1';

        String devEffortField = SObjectServices.getFullyQualifiedName('Dev_Effort__c'); // number
        String epicFieldLabel = 'Big Backlog Or Not';
        String epicField = SObjectServices.getFullyQualifiedName('Epic__c'); // boolean/checkbox
        String statusField = SObjectServices.getFullyQualifiedName('Status__c'); // string
        String closeDateField = SObjectServices.getFullyQualifiedName('Closed_Date__c'); // datetime
        String recordTypeIdField = 'RecordTypeId'; // lookup error field
        // Real Lookup Error Fields
        List<Schema.RecordTypeInfo> rtList = new List<Schema.RecordTypeInfo>();
        for (Schema.RecordTypeInfo rt : Backlog__c.SObjectType.getDescribe().getRecordTypeInfos()){
            if (rt.isAvailable() && !rt.isMaster()){
                rtList.add(rt);
            }
        }
        System.assert(rtList.size() > 0, 'We expect at least one record type on Backlog__c.');

        // Lookup records to be created (Project__c lookup record required, Current_Sprint__c not required, Instances__c set to ignore, Release__c has lookupError, Persona__c)
        String projectField = SObjectServices.getFullyQualifiedName('Project__c');
        String currentSprintField = SObjectServices.getFullyQualifiedName('Current_Sprint__c');
        String instanceField = SObjectServices.getFullyQualifiedName('Instance__c');
        String releaseField = SObjectServices.getFullyQualifiedName('Release__c');
        String personaField = SObjectServices.getFullyQualifiedName('Persona__c');


        BacklogItemUploadFieldMappingConfig projectFieldMappingConfig = new BacklogItemUploadFieldMappingConfig(projectField);
        BacklogItemUploadFieldMappingConfig currentSprintFieldMappingConfig = new BacklogItemUploadFieldMappingConfig(currentSprintField);
        BacklogItemUploadFieldMappingConfig instanceFieldMappingConfig = new BacklogItemUploadFieldMappingConfig(instanceField);
        BacklogItemUploadFieldMappingConfig releaseFieldMappingConfig = new BacklogItemUploadFieldMappingConfig(releaseField);
        BacklogItemUploadFieldMappingConfig personaFieldMappingConfig = new BacklogItemUploadFieldMappingConfig(personaField);
        BacklogItemUploadFieldMappingConfig recordTypeIdFieldMappingConfig = new BacklogItemUploadFieldMappingConfig(recordTypeIdField);

        projectFieldMappingConfig.isMapped = true;
        projectFieldMappingConfig.isLookup = true;
        projectFieldMappingConfig.salesforceFieldName = projectField;
        projectFieldMappingConfig.lookupDetail.createNewRelatedRecords = true;
        projectFieldMappingConfig.lookupDetail.newRelatedRecords.add(expectedNewProject1);
        projectFieldMappingConfig.lookupDetail.newRelatedRecords.add(expectedNewProject2);
        projectFieldMappingConfig.lookupDetail.lookupTargetObjectName = Schema.Project__c.getSObjectType().getDescribe().getName();

        currentSprintFieldMappingConfig.isMapped = true;
        currentSprintFieldMappingConfig.isLookup = true;
        currentSprintFieldMappingConfig.salesforceFieldName = currentSprintField;
        currentSprintFieldMappingConfig.lookupDetail.createNewRelatedRecords = true;
        currentSprintFieldMappingConfig.lookupDetail.newRelatedRecords.add(expectedNewSprint1);
        currentSprintFieldMappingConfig.lookupDetail.newRelatedRecords.add(expectedNewSprint1);
        currentSprintFieldMappingConfig.lookupDetail.lookupTargetObjectName = Schema.Sprint__c.getSObjectType().getDescribe().getName();

        instanceFieldMappingConfig.isMapped = true;
        instanceFieldMappingConfig.isLookup = true;
        instanceFieldMappingConfig.salesforceFieldName = instanceField;
        instanceFieldMappingConfig.lookupDetail.createNewRelatedRecords = false;
        instanceFieldMappingConfig.lookupDetail.newRelatedRecords.add(instance1);
        instanceFieldMappingConfig.lookupDetail.lookupTargetObjectName = Schema.Instances__c.getSObjectType().getDescribe().getName();

        releaseFieldMappingConfig.isMapped = true;
        releaseFieldMappingConfig.isLookup = true;
        releaseFieldMappingConfig.salesforceFieldName = releaseField;
        releaseFieldMappingConfig.lookupDetail.createNewRelatedRecords = true;
        releaseFieldMappingConfig.lookupDetail.hasLookupError = true;
        releaseFieldMappingConfig.lookupDetail.newRelatedRecords.add(release1);
        releaseFieldMappingConfig.lookupDetail.lookupTargetObjectName = Schema.Release__c.getSObjectType().getDescribe().getName();

        personaFieldMappingConfig.isMapped = true;
        personaFieldMappingConfig.isLookup = true;
        personaFieldMappingConfig.salesforceFieldName = personaField;
        personaFieldMappingConfig.lookupDetail.hasLookupError = false;
        personaFieldMappingConfig.lookupDetail.createNewRelatedRecords = false;
        personaFieldMappingConfig.lookupDetail.existingRelatedRecordMap = new Map<String, String>{persona1 => testPersona.Id};
        personaFieldMappingConfig.lookupDetail.lookupTargetObjectName = Schema.Persona__c.getSObjectType().getDescribe().getName();

        recordTypeIdFieldMappingConfig.isMapped = true;
        recordTypeIdFieldMappingConfig.isLookup = true;
        recordTypeIdFieldMappingConfig.lookupDetail.hasLookupError = true;
        recordTypeIdFieldMappingConfig.lookupDetail.existingRelatedRecordMap = new Map<String, String>{rtList[0].getName() => rtList[0].getRecordTypeId()};
        recordTypeIdFieldMappingConfig.salesforceFieldName = recordTypeIdField;

        BacklogItemUploadMappingConfig mcd = new BacklogItemUploadMappingConfig();
        mcd.mappingConfigurations.add(currentSprintFieldMappingConfig);
        mcd.mappingConfigurations.add(instanceFieldMappingConfig);
        mcd.mappingConfigurations.add(releaseFieldMappingConfig);
        mcd.mappingConfigurations.add(personaFieldMappingConfig);
        mcd.mappingConfigurations.add(recordTypeIdFieldMappingConfig);
        mcd.requiredMappingConfigurations.add(projectFieldMappingConfig);
        // non-lookup fields
        mcd.mappingConfigurations.add(createSimpleMappedFieldMappingConfig(devEffortField, devEffortField));
        // should use the mapped salesforce field to get mapping, not column label
        mcd.mappingConfigurations.add(createSimpleMappedFieldMappingConfig(epicFieldLabel, epicField));
        mcd.mappingConfigurations.add(createSimpleMappedFieldMappingConfig(statusField, statusField));
        mcd.mappingConfigurations.add(createSimpleMappedFieldMappingConfig(closeDateField, closeDateField));

        // Column to Index
        String mappingConfigDataSON = JSON.serialize(mcd);
        Map<String, Integer> columnHeaderIndexRecords = new Map<String, Integer>();
        columnHeaderIndexRecords.put(devEffortField, 0);
        columnHeaderIndexRecords.put(epicFieldLabel, 1);
        columnHeaderIndexRecords.put(statusField, 2);
        columnHeaderIndexRecords.put(closeDateField, 3);

        columnHeaderIndexRecords.put(projectField, 4);
        columnHeaderIndexRecords.put(currentSprintField, 5);
        columnHeaderIndexRecords.put(instanceField, 6);
        columnHeaderIndexRecords.put(releaseField, 7);
        columnHeaderIndexRecords.put(personaField, 8);
        columnHeaderIndexRecords.put(recordTypeIdField, 9);

        // Backlog item fields to be created
        Datetime expectedCloseDate = DateTime.newInstance(1993, 6, 6, 3, 3, 3);
        String testDatetime = expectedCloseDate.format('yyyy-MM-dd HH:mm:ss');

        List<List<String>> backlogItemRecords = new List<List<String>>();
        List<String> backlogItemRecord1 = new List<String>{'4', 'true', IN_PROGRESS_STATUS, testDatetime, expectedNewProject1, expectedNewSprint1, instance1, release1, persona1, rtList[0].getName()};
        List<String> backlogItemRecord2 = new List<String>{'9', 'false', DEV_COMPLETE_STATUS, testDatetime, expectedNewProject2, expectedNewSprint1, instance1, release1, testPersona.Id, rtList[0].getRecordTypeId()};
        backlogItemRecords.add(backlogItemRecord1);
        backlogItemRecords.add(backlogItemRecord2);

        String backlogItemRecordsJSON = JSON.serialize(backlogItemRecords);

        System.assertEquals(1, [Select Id From Persona__c].size(), 'Persona records should exist.');
        System.assert([Select Id From Project__c].isEmpty(), 'No project records should exist.');
        System.assert([Select Id From Sprint__c].isEmpty(), 'No sprint records should exist.');
        System.assert([Select Id From Instances__c].isEmpty(), 'No instance records should exist.');
        System.assert([Select Id From Release__c].isEmpty(), 'No release records should exist.');
        System.assert([Select Id From Backlog__c].isEmpty(), 'No Backlog Item records should exist.');

        BacklogItemUploadResult uploadResultObj;

        Test.startTest();
            try{
                uploadResultObj = BacklogItemUploadController.createRecords(mappingConfigDataSON, JSON.serialize(columnHeaderIndexRecords), backlogItemRecordsJSON);
            } catch (Exception e){
                System.assert(false, 'We do not expect an error to be thrown: ' + e);
            }
        Test.stopTest();


        System.assertNotEquals(null, uploadResultObj, 'We expect to get back an Upload Result object.');
        System.assertNotEquals(null, uploadResultObj.record, 'We expect to get back a record on the Upload Result object.');
        System.assertEquals(5, uploadResultObj.record.Num_of_Records_Created__c,
            'We expect to get back the correct number of records created on the Upload Result object.');
        System.assertEquals(0, uploadResultObj.record.Num_of_Errors__c,
            'We expect to get back the correct number of errors on the Upload Result object.');
        System.assertNotEquals(null, uploadResultObj.successCsvId, 'We expect to get back a success attachment on the Upload Result object.');
        System.assertNotEquals(null, uploadResultObj.failureCSVId, 'We expect to get back a failure attachment on the Upload Result object.');
        List<Attachment> attachments = [Select Id from Attachment Where ParentId = :uploadResultObj.record.Id];
        System.assertEquals(2, attachments.size(), 'We expect a success and failure attachment to be created.');
        System.assert([Select Id From Instances__c].isEmpty(), 'No instance records should exist.');
        System.assert([Select Id From Release__c].isEmpty(), 'No release records should exist.');

        Map<String, List<Project__c>> actualProjectMap = (Map<String, List<Project__c>>) GroupBy.strings(Schema.Project__c.Name,
            [Select Id, Name From Project__c]);
        System.assertEquals(2, actualProjectMap.size(), 'Project records should exist.');
        System.assertEquals(new Set<String>{expectedNewProject1, expectedNewProject2}, actualProjectMap.keySet(),
            'We expect the correct project records to be created.');

        Map<String, List<Sprint__c>> actualSprintMap = (Map<String, List<Sprint__c>>) GroupBy.strings(Schema.Sprint__c.Name,
            [Select Id, Name From Sprint__c]);
        System.assertEquals(1, actualSprintMap.size(), 'Sprint records should exist.');
        System.assertEquals(new Set<String>{expectedNewSprint1}, actualSprintMap.keySet(),
            'We expect the correct sprint records to be created.');

        Map<String, List<Backlog__c>> actualBacklogItemStatusMap = (Map<String, List<Backlog__c>>) GroupBy.strings(Schema.Backlog__c.Status__c,
            [Select Id, Dev_Effort__c, Epic__c, Status__c, Closed_Date__c, Project__c, RecordTypeId,
                    Current_Sprint__c, Instance__c, Release__c, Persona__c From Backlog__c]);
        System.assertEquals(2, actualBacklogItemStatusMap.size(), 'Backlog Item records should exist.');
        System.assertEquals(expectedStatuses, actualBacklogItemStatusMap.keySet(),
            'We expect to get back the correct statuses on the backlgo items created.');
        System.assertEquals(1, actualBacklogItemStatusMap.get(IN_PROGRESS_STATUS).size(), 'The correct number of backlog items should exist');
        System.assertEquals(1, actualBacklogItemStatusMap.get(DEV_COMPLETE_STATUS).size(), 'The correct number of backlog items should exist');
        System.assertEquals(4, actualBacklogItemStatusMap.get(IN_PROGRESS_STATUS)[0].Dev_Effort__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(true, actualBacklogItemStatusMap.get(IN_PROGRESS_STATUS)[0].Epic__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(expectedCloseDate, actualBacklogItemStatusMap.get(IN_PROGRESS_STATUS)[0].Closed_Date__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(actualProjectMap.get(expectedNewProject1)[0].Id, actualBacklogItemStatusMap.get(IN_PROGRESS_STATUS)[0].Project__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(actualSprintMap.get(expectedNewSprint1)[0].Id, actualBacklogItemStatusMap.get(IN_PROGRESS_STATUS)[0].Current_Sprint__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(null, actualBacklogItemStatusMap.get(IN_PROGRESS_STATUS)[0].Instance__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(null, actualBacklogItemStatusMap.get(IN_PROGRESS_STATUS)[0].Release__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(testPersona.Id, actualBacklogItemStatusMap.get(IN_PROGRESS_STATUS)[0].Persona__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(rtList[0].getRecordTypeId(), actualBacklogItemStatusMap.get(IN_PROGRESS_STATUS)[0].RecordTypeId,
            'We expect the backlog item to have the correct value.');

        System.assertEquals(9, actualBacklogItemStatusMap.get(DEV_COMPLETE_STATUS)[0].Dev_Effort__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(false, actualBacklogItemStatusMap.get(DEV_COMPLETE_STATUS)[0].Epic__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(expectedCloseDate, actualBacklogItemStatusMap.get(DEV_COMPLETE_STATUS)[0].Closed_Date__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(actualProjectMap.get(expectedNewProject2)[0].Id, actualBacklogItemStatusMap.get(DEV_COMPLETE_STATUS)[0].Project__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(actualSprintMap.get(expectedNewSprint1)[0].Id, actualBacklogItemStatusMap.get(DEV_COMPLETE_STATUS)[0].Current_Sprint__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(null, actualBacklogItemStatusMap.get(DEV_COMPLETE_STATUS)[0].Instance__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(null, actualBacklogItemStatusMap.get(DEV_COMPLETE_STATUS)[0].Release__c,
            'We expect the backlog item to have the correct value.');
        System.assertEquals(testPersona.Id, actualBacklogItemStatusMap.get(DEV_COMPLETE_STATUS)[0].Persona__c,
            'The lookup value should replace the name on the record when it is an existing value.');
        System.assertEquals(rtList[0].getRecordTypeId(), actualBacklogItemStatusMap.get(DEV_COMPLETE_STATUS)[0].RecordTypeId,
            'We expect the backlog item to have the correct value.');



    }

}