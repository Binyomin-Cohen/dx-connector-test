@isTest
private class TestCustomMetadataServices {
    private static final String EXPECTED_CUSTOM_METADATA_TYPE_NAME = 'Test_Custom_Metadata_Type_Name';
    private static final String EXPECTED_CUSTOM_METADATA_RECORD_LABEL = 'Test Custom Metadata Record Label';
    private static final String EXPECTED_CUSTOM_METADATA_FIELD_NAME = 'Test_Custom_Metadata_Field_Name';
    private static final String EXPECTED_CUSTOM_METADATA_FIELD_STRING_VALUE = 'Test Custom Metadata Field Value';
    private static final Integer EXPECTED_CUSTOM_METADATA_FIELD_INTEGER_VALUE = 10;
    private static final Boolean EXPECTED_CUSTOM_METADATA_FIELD_BOOLEAN_VALUE = true;
    private static final DateTime EXPECTED_CUSTOM_METADATA_FIELD_DATETIME_VALUE = DateTime.newInstance(2018, 1, 2, 3, 4, 5);
    private static final Map<String, String> EXPECTED_CUSTOM_METADATA_FIELD_TO_STRING_VALUE_MAP = new Map<String, String>{
        'Test_Custom_Metadata_Field_0' => null,
        'Test_Custom_Metadata_Field_1' => '',
        'Test_Custom_Metadata_Field_2' => ' ',
        'Test_Custom_Metadata_Field_3' => EXPECTED_CUSTOM_METADATA_FIELD_STRING_VALUE
    };
    private static final Map<String, Integer> EXPECTED_CUSTOM_METADATA_FIELD_TO_INTEGER_VALUE_MAP = new Map<String, Integer>{
        'Test_Custom_Metadata_Field_0' => null,
        'Test_Custom_Metadata_Field_1' => -15,
        'Test_Custom_Metadata_Field_2' => 0,
        'Test_Custom_Metadata_Field_3' => 3
    };
    private static final Map<String, Boolean> EXPECTED_CUSTOM_METADATA_FIELD_TO_BOOLEAN_VALUE_MAP = new Map<String, Boolean>{
        'Test_Custom_Metadata_Field_0' => false,
        'Test_Custom_Metadata_Field_1' => true,
        'Test_Custom_Metadata_Field_2' => true,
        'Test_Custom_Metadata_Field_3' => false
    };
    private static final Map<String, DateTime> EXPECTED_CUSTOM_METADATA_FIELD_TO_DATETIME_VALUE_MAP = new Map<String, DateTime>{
        'Test_Custom_Metadata_Field_0' => null,
        'Test_Custom_Metadata_Field_1' => DateTime.newInstance(2018, 1, 30, 19, 09, 45),
        'Test_Custom_Metadata_Field_2' => DateTime.newInstance(0, 0, 0, 0, 0, 0),
        'Test_Custom_Metadata_Field_3' => DateTime.newInstance(2018, 0, 0, 0, 0, 0)
    };

    private static void assert_buildCustomMetadata_withListOfValues(Map<String, Metadata.CustomMetadataValue> expectedCustomMetadataFieldToCustomMetadataValueMap, Metadata.CustomMetadata actualCustomMetadata) {
        for (Metadata.CustomMetadataValue expectedCustomMetadataValue : expectedCustomMetadataFieldToCustomMetadataValueMap.values()) {
            expectedCustomMetadataValue.field = SObjectServices.getFullyQualifiedName(expectedCustomMetadataValue.field);
        }

        System.assertEquals(SObjectServices.getFullyQualifiedName(EXPECTED_CUSTOM_METADATA_TYPE_NAME) + '.' + EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.fullName, 'The custom metadata full name should be built properly.');
        System.assertEquals(EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.label, 'The custom metadata label should be built properly.');

        System.assertEquals(expectedCustomMetadataFieldToCustomMetadataValueMap.size(), actualCustomMetadata.values.size(), 'The proper number of custom metadata values should be built.');
        for (Metadata.CustomMetadataValue actualCustomMetadataValue : actualCustomMetadata.values) {
            Metadata.CustomMetadataValue expectedCustomMetadataValue = expectedCustomMetadataFieldToCustomMetadataValueMap.get(actualCustomMetadataValue.field);
            System.assertEquals(expectedCustomMetadataValue.value, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
        }
    }

    private static void fullyQualifyMapKeys(Map<String, Object> mapToQualify) {
        for (String key : mapToQualify.keySet()) {
            Object value = mapToQualify.remove(key);
            mapToQualify.put(SObjectServices.getFullyQualifiedName(key), value);
        }
    }

    private static testMethod void buildCustomMetadata_withoutValues() {
        Test.startTest();

            Metadata.CustomMetadata actualCustomMetadata = CustomMetadataServices.buildCustomMetadata(EXPECTED_CUSTOM_METADATA_TYPE_NAME, EXPECTED_CUSTOM_METADATA_RECORD_LABEL);

        Test.stopTest();

        System.assertEquals(SObjectServices.getFullyQualifiedName(EXPECTED_CUSTOM_METADATA_TYPE_NAME) + '.' + EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.fullName, 'The custom metadata full name should be built properly.');
        System.assertEquals(EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.label, 'The custom metadata label should be built properly.');
    }

    private static testMethod void buildCustomMetadata_withValues_listOfValues_stringValues() {
        Metadata.CustomMetadataValue customMetadataValue0 = new Metadata.CustomMetadataValue();
        customMetadataValue0.field = 'Test_Custom_Metadata_Field_0';
        customMetadataValue0.value = null;

        Metadata.CustomMetadataValue customMetadataValue1 = new Metadata.CustomMetadataValue();
        customMetadataValue1.field = 'Test_Custom_Metadata_Field_1';
        customMetadataValue1.value = '';

        Metadata.CustomMetadataValue customMetadataValue2 = new Metadata.CustomMetadataValue();
        customMetadataValue2.field = 'Test_Custom_Metadata_Field_2';
        customMetadataValue2.value = ' ';

        Metadata.CustomMetadataValue customMetadataValue3 = new Metadata.CustomMetadataValue();
        customMetadataValue3.field = 'Test_Custom_Metadata_Field_3';
        customMetadataValue3.value = 'Test Custom Metadata Value 3';

        Map<String, Metadata.CustomMetadataValue> expectedCustomMetadataFieldToCustomMetadataValueMap = new Map<String, Metadata.CustomMetadataValue>{
            SObjectServices.getFullyQualifiedName(customMetadataValue0.field) => customMetadataValue0,
            SObjectServices.getFullyQualifiedName(customMetadataValue1.field) => customMetadataValue1,
            SObjectServices.getFullyQualifiedName(customMetadataValue2.field) => customMetadataValue2,
            SObjectServices.getFullyQualifiedName(customMetadataValue3.field) => customMetadataValue3
        };

        Test.startTest();

            Metadata.CustomMetadata actualCustomMetadata = CustomMetadataServices.buildCustomMetadata(EXPECTED_CUSTOM_METADATA_TYPE_NAME, EXPECTED_CUSTOM_METADATA_RECORD_LABEL, expectedCustomMetadataFieldToCustomMetadataValueMap.values());

        Test.stopTest();

        assert_buildCustomMetadata_withListOfValues(expectedCustomMetadataFieldToCustomMetadataValueMap, actualCustomMetadata);
    }

    private static testMethod void buildCustomMetadata_withValues_listOfValues_integerValues() {
        Metadata.CustomMetadataValue customMetadataValue0 = new Metadata.CustomMetadataValue();
        customMetadataValue0.field = 'Test_Custom_Metadata_Field_0';
        customMetadataValue0.value = null;

        Metadata.CustomMetadataValue customMetadataValue1 = new Metadata.CustomMetadataValue();
        customMetadataValue1.field = 'Test_Custom_Metadata_Field_1';
        customMetadataValue1.value = -15;

        Metadata.CustomMetadataValue customMetadataValue2 = new Metadata.CustomMetadataValue();
        customMetadataValue2.field = 'Test_Custom_Metadata_Field_2';
        customMetadataValue2.value = 0;

        Metadata.CustomMetadataValue customMetadataValue3 = new Metadata.CustomMetadataValue();
        customMetadataValue3.field = 'Test_Custom_Metadata_Field_3';
        customMetadataValue3.value = 3;

        Map<String, Metadata.CustomMetadataValue> expectedCustomMetadataFieldToCustomMetadataValueMap = new Map<String, Metadata.CustomMetadataValue>{
            SObjectServices.getFullyQualifiedName(customMetadataValue0.field) => customMetadataValue0,
            SObjectServices.getFullyQualifiedName(customMetadataValue1.field) => customMetadataValue1,
            SObjectServices.getFullyQualifiedName(customMetadataValue2.field) => customMetadataValue2,
            SObjectServices.getFullyQualifiedName(customMetadataValue3.field) => customMetadataValue3
        };

        Test.startTest();

            Metadata.CustomMetadata actualCustomMetadata = CustomMetadataServices.buildCustomMetadata(EXPECTED_CUSTOM_METADATA_TYPE_NAME, EXPECTED_CUSTOM_METADATA_RECORD_LABEL, expectedCustomMetadataFieldToCustomMetadataValueMap.values());

        Test.stopTest();

        assert_buildCustomMetadata_withListOfValues(expectedCustomMetadataFieldToCustomMetadataValueMap, actualCustomMetadata);
    }

    private static testMethod void buildCustomMetadata_withValues_listOfValues_booleanValues() {
        Metadata.CustomMetadataValue customMetadataValue0 = new Metadata.CustomMetadataValue();
        customMetadataValue0.field = 'Test_Custom_Metadata_Field_0';
        customMetadataValue0.value = false;

        Metadata.CustomMetadataValue customMetadataValue1 = new Metadata.CustomMetadataValue();
        customMetadataValue1.field = 'Test_Custom_Metadata_Field_1';
        customMetadataValue1.value = true;

        Metadata.CustomMetadataValue customMetadataValue2 = new Metadata.CustomMetadataValue();
        customMetadataValue2.field = 'Test_Custom_Metadata_Field_2';
        customMetadataValue2.value = true;

        Metadata.CustomMetadataValue customMetadataValue3 = new Metadata.CustomMetadataValue();
        customMetadataValue3.field = 'Test_Custom_Metadata_Field_3';
        customMetadataValue3.value = false;

        Map<String, Metadata.CustomMetadataValue> expectedCustomMetadataFieldToCustomMetadataValueMap = new Map<String, Metadata.CustomMetadataValue>{
            SObjectServices.getFullyQualifiedName(customMetadataValue0.field) => customMetadataValue0,
            SObjectServices.getFullyQualifiedName(customMetadataValue1.field) => customMetadataValue1,
            SObjectServices.getFullyQualifiedName(customMetadataValue2.field) => customMetadataValue2,
            SObjectServices.getFullyQualifiedName(customMetadataValue3.field) => customMetadataValue3
        };

        Test.startTest();

            Metadata.CustomMetadata actualCustomMetadata = CustomMetadataServices.buildCustomMetadata(EXPECTED_CUSTOM_METADATA_TYPE_NAME, EXPECTED_CUSTOM_METADATA_RECORD_LABEL, expectedCustomMetadataFieldToCustomMetadataValueMap.values());

        Test.stopTest();

        assert_buildCustomMetadata_withListOfValues(expectedCustomMetadataFieldToCustomMetadataValueMap, actualCustomMetadata);
    }

    private static testMethod void buildCustomMetadata_withValues_listOfValues_datetimeValues() {
        Metadata.CustomMetadataValue customMetadataValue0 = new Metadata.CustomMetadataValue();
        customMetadataValue0.field = 'Test_Custom_Metadata_Field_0';
        customMetadataValue0.value = null;

        Metadata.CustomMetadataValue customMetadataValue1 = new Metadata.CustomMetadataValue();
        customMetadataValue1.field = 'Test_Custom_Metadata_Field_1';
        customMetadataValue1.value = DateTime.newInstance(2018, 1, 30, 19, 09, 45);

        Metadata.CustomMetadataValue customMetadataValue2 = new Metadata.CustomMetadataValue();
        customMetadataValue2.field = 'Test_Custom_Metadata_Field_2';
        customMetadataValue2.value = DateTime.newInstance(0, 0, 0, 0, 0, 0);

        Metadata.CustomMetadataValue customMetadataValue3 = new Metadata.CustomMetadataValue();
        customMetadataValue3.field = 'Test_Custom_Metadata_Field_3';
        customMetadataValue3.value = DateTime.newInstance(2018, 0, 0, 0, 0, 0);

        Map<String, Metadata.CustomMetadataValue> expectedCustomMetadataFieldToCustomMetadataValueMap = new Map<String, Metadata.CustomMetadataValue>{
            SObjectServices.getFullyQualifiedName(customMetadataValue0.field) => customMetadataValue0,
            SObjectServices.getFullyQualifiedName(customMetadataValue1.field) => customMetadataValue1,
            SObjectServices.getFullyQualifiedName(customMetadataValue2.field) => customMetadataValue2,
            SObjectServices.getFullyQualifiedName(customMetadataValue3.field) => customMetadataValue3
        };

        Test.startTest();

            Metadata.CustomMetadata actualCustomMetadata = CustomMetadataServices.buildCustomMetadata(EXPECTED_CUSTOM_METADATA_TYPE_NAME, EXPECTED_CUSTOM_METADATA_RECORD_LABEL, expectedCustomMetadataFieldToCustomMetadataValueMap.values());

        Test.stopTest();

        assert_buildCustomMetadata_withListOfValues(expectedCustomMetadataFieldToCustomMetadataValueMap, actualCustomMetadata);
    }
    
    private static testMethod void buildCustomMetadata_withValues_mapOfValues_stringValues() {
        Test.startTest();

            Metadata.CustomMetadata actualCustomMetadata = CustomMetadataServices.buildCustomMetadata(EXPECTED_CUSTOM_METADATA_TYPE_NAME, EXPECTED_CUSTOM_METADATA_RECORD_LABEL, EXPECTED_CUSTOM_METADATA_FIELD_TO_STRING_VALUE_MAP);

        Test.stopTest();

        fullyQualifyMapKeys(EXPECTED_CUSTOM_METADATA_FIELD_TO_STRING_VALUE_MAP);

        System.assertEquals(SObjectServices.getFullyQualifiedName(EXPECTED_CUSTOM_METADATA_TYPE_NAME) + '.' + EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.fullName, 'The custom metadata full name should be built properly.');
        System.assertEquals(EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.label, 'The custom metadata label should be built properly.');

        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_TO_STRING_VALUE_MAP.size(), actualCustomMetadata.values.size(), 'The proper number of custom metadata values should be built.');
        for (Metadata.CustomMetadataValue actualCustomMetadataValue : actualCustomMetadata.values) {
            String expectedValue = EXPECTED_CUSTOM_METADATA_FIELD_TO_STRING_VALUE_MAP.get(actualCustomMetadataValue.field);
            System.assertEquals(expectedValue, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
        }
    }
    
    private static testMethod void buildCustomMetadata_withValues_mapOfValues_integerValues() {
        Test.startTest();

            Metadata.CustomMetadata actualCustomMetadata = CustomMetadataServices.buildCustomMetadata(EXPECTED_CUSTOM_METADATA_TYPE_NAME, EXPECTED_CUSTOM_METADATA_RECORD_LABEL, EXPECTED_CUSTOM_METADATA_FIELD_TO_INTEGER_VALUE_MAP);

        Test.stopTest();

        fullyQualifyMapKeys(EXPECTED_CUSTOM_METADATA_FIELD_TO_INTEGER_VALUE_MAP);

        System.assertEquals(SObjectServices.getFullyQualifiedName(EXPECTED_CUSTOM_METADATA_TYPE_NAME) + '.' + EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.fullName, 'The custom metadata full name should be built properly.');
        System.assertEquals(EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.label, 'The custom metadata label should be built properly.');

        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_TO_INTEGER_VALUE_MAP.size(), actualCustomMetadata.values.size(), 'The proper number of custom metadata values should be built.');
        for (Metadata.CustomMetadataValue actualCustomMetadataValue : actualCustomMetadata.values) {
            Integer expectedValue = EXPECTED_CUSTOM_METADATA_FIELD_TO_INTEGER_VALUE_MAP.get(actualCustomMetadataValue.field);
            System.assertEquals(expectedValue, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
        }
    }
    
    private static testMethod void buildCustomMetadata_withValues_mapOfValues_booleanValues() {
        Test.startTest();

            Metadata.CustomMetadata actualCustomMetadata = CustomMetadataServices.buildCustomMetadata(EXPECTED_CUSTOM_METADATA_TYPE_NAME, EXPECTED_CUSTOM_METADATA_RECORD_LABEL, EXPECTED_CUSTOM_METADATA_FIELD_TO_BOOLEAN_VALUE_MAP);

        Test.stopTest();

        fullyQualifyMapKeys(EXPECTED_CUSTOM_METADATA_FIELD_TO_BOOLEAN_VALUE_MAP);

        System.assertEquals(SObjectServices.getFullyQualifiedName(EXPECTED_CUSTOM_METADATA_TYPE_NAME) + '.' + EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.fullName, 'The custom metadata full name should be built properly.');
        System.assertEquals(EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.label, 'The custom metadata label should be built properly.');

        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_TO_BOOLEAN_VALUE_MAP.size(), actualCustomMetadata.values.size(), 'The proper number of custom metadata values should be built.');
        for (Metadata.CustomMetadataValue actualCustomMetadataValue : actualCustomMetadata.values) {
            Boolean expectedValue = EXPECTED_CUSTOM_METADATA_FIELD_TO_BOOLEAN_VALUE_MAP.get(actualCustomMetadataValue.field);
            System.assertEquals(expectedValue, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
        }
    }
    
    private static testMethod void buildCustomMetadata_withValues_mapOfValues_datetimeValues() {
        Test.startTest();

            Metadata.CustomMetadata actualCustomMetadata = CustomMetadataServices.buildCustomMetadata(EXPECTED_CUSTOM_METADATA_TYPE_NAME, EXPECTED_CUSTOM_METADATA_RECORD_LABEL, EXPECTED_CUSTOM_METADATA_FIELD_TO_DATETIME_VALUE_MAP);

        Test.stopTest();

        fullyQualifyMapKeys(EXPECTED_CUSTOM_METADATA_FIELD_TO_DATETIME_VALUE_MAP);

        System.assertEquals(SObjectServices.getFullyQualifiedName(EXPECTED_CUSTOM_METADATA_TYPE_NAME) + '.' + EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.fullName, 'The custom metadata full name should be built properly.');
        System.assertEquals(EXPECTED_CUSTOM_METADATA_RECORD_LABEL, actualCustomMetadata.label, 'The custom metadata label should be built properly.');

        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_TO_DATETIME_VALUE_MAP.size(), actualCustomMetadata.values.size(), 'The proper number of custom metadata values should be built.');
        for (Metadata.CustomMetadataValue actualCustomMetadataValue : actualCustomMetadata.values) {
            DateTime expectedValue = EXPECTED_CUSTOM_METADATA_FIELD_TO_DATETIME_VALUE_MAP.get(actualCustomMetadataValue.field);
            System.assertEquals(expectedValue, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
        }
    }

    private static testMethod void buildCustomMetadataValues_stringValues() {
        Test.startTest();

            List<Metadata.CustomMetadataValue> actualCustomMetadataValues = CustomMetadataServices.buildCustomMetadataValues(EXPECTED_CUSTOM_METADATA_FIELD_TO_STRING_VALUE_MAP);

        Test.stopTest();

        fullyQualifyMapKeys(EXPECTED_CUSTOM_METADATA_FIELD_TO_STRING_VALUE_MAP);

        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_TO_STRING_VALUE_MAP.size(), actualCustomMetadataValues.size(), 'The proper number of custom metadata values should be built.');
        for (Metadata.CustomMetadataValue actualCustomMetadataValue : actualCustomMetadataValues) {
            String expectedValue = EXPECTED_CUSTOM_METADATA_FIELD_TO_STRING_VALUE_MAP.get(actualCustomMetadataValue.field);
            System.assertEquals(expectedValue, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
        }
    }

    private static testMethod void buildCustomMetadataValues_integerValues() {
        Test.startTest();

            List<Metadata.CustomMetadataValue> actualCustomMetadataValues = CustomMetadataServices.buildCustomMetadataValues(EXPECTED_CUSTOM_METADATA_FIELD_TO_INTEGER_VALUE_MAP);

        Test.stopTest();

        fullyQualifyMapKeys(EXPECTED_CUSTOM_METADATA_FIELD_TO_INTEGER_VALUE_MAP);

        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_TO_INTEGER_VALUE_MAP.size(), actualCustomMetadataValues.size(), 'The proper number of custom metadata values should be built.');
        for (Metadata.CustomMetadataValue actualCustomMetadataValue : actualCustomMetadataValues) {
            Integer expectedValue = EXPECTED_CUSTOM_METADATA_FIELD_TO_INTEGER_VALUE_MAP.get(actualCustomMetadataValue.field);
            System.assertEquals(expectedValue, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
        }
    }

    private static testMethod void buildCustomMetadataValues_booleanValues() {
        Test.startTest();

            List<Metadata.CustomMetadataValue> actualCustomMetadataValues = CustomMetadataServices.buildCustomMetadataValues(EXPECTED_CUSTOM_METADATA_FIELD_TO_BOOLEAN_VALUE_MAP);

        Test.stopTest();

        fullyQualifyMapKeys(EXPECTED_CUSTOM_METADATA_FIELD_TO_BOOLEAN_VALUE_MAP);

        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_TO_BOOLEAN_VALUE_MAP.size(), actualCustomMetadataValues.size(), 'The proper number of custom metadata values should be built.');
        for (Metadata.CustomMetadataValue actualCustomMetadataValue : actualCustomMetadataValues) {
            Boolean expectedValue = EXPECTED_CUSTOM_METADATA_FIELD_TO_BOOLEAN_VALUE_MAP.get(actualCustomMetadataValue.field);
            System.assertEquals(expectedValue, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
        }
    }

    private static testMethod void buildCustomMetadataValues_datetimeValues() {
        Test.startTest();

            List<Metadata.CustomMetadataValue> actualCustomMetadataValues = CustomMetadataServices.buildCustomMetadataValues(EXPECTED_CUSTOM_METADATA_FIELD_TO_DATETIME_VALUE_MAP);

        Test.stopTest();

        fullyQualifyMapKeys(EXPECTED_CUSTOM_METADATA_FIELD_TO_DATETIME_VALUE_MAP);

        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_TO_DATETIME_VALUE_MAP.size(), actualCustomMetadataValues.size(), 'The proper number of custom metadata values should be built.');
        for (Metadata.CustomMetadataValue actualCustomMetadataValue : actualCustomMetadataValues) {
            DateTime expectedValue = EXPECTED_CUSTOM_METADATA_FIELD_TO_DATETIME_VALUE_MAP.get(actualCustomMetadataValue.field);
            System.assertEquals(expectedValue, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
        }
    }

    private static testMethod void buildCustomMetadataValue_stringValue() {
        Test.startTest();

            Metadata.CustomMetadataValue actualCustomMetadataValue = CustomMetadataServices.buildCustomMetadataValue(EXPECTED_CUSTOM_METADATA_FIELD_NAME, EXPECTED_CUSTOM_METADATA_FIELD_STRING_VALUE);

        Test.stopTest();

        System.assertEquals(SObjectServices.getFullyQualifiedName(EXPECTED_CUSTOM_METADATA_FIELD_NAME), actualCustomMetadataValue.field, 'The custom metadata field should be built properly.');
        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_STRING_VALUE, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
    }

    private static testMethod void buildCustomMetadataValue_integerValue() {
        Test.startTest();

            Metadata.CustomMetadataValue actualCustomMetadataValue = CustomMetadataServices.buildCustomMetadataValue(EXPECTED_CUSTOM_METADATA_FIELD_NAME, EXPECTED_CUSTOM_METADATA_FIELD_INTEGER_VALUE);

        Test.stopTest();

        System.assertEquals(SObjectServices.getFullyQualifiedName(EXPECTED_CUSTOM_METADATA_FIELD_NAME), actualCustomMetadataValue.field, 'The custom metadata field should be built properly.');
        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_INTEGER_VALUE, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
    }

    private static testMethod void buildCustomMetadataValue_booleanValue() {
        Test.startTest();

            Metadata.CustomMetadataValue actualCustomMetadataValue = CustomMetadataServices.buildCustomMetadataValue(EXPECTED_CUSTOM_METADATA_FIELD_NAME, EXPECTED_CUSTOM_METADATA_FIELD_BOOLEAN_VALUE);

        Test.stopTest();

        System.assertEquals(SObjectServices.getFullyQualifiedName(EXPECTED_CUSTOM_METADATA_FIELD_NAME), actualCustomMetadataValue.field, 'The custom metadata field should be built properly.');
        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_BOOLEAN_VALUE, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
    }

    private static testMethod void buildCustomMetadataValue_datetimeValue() {
        Test.startTest();

            Metadata.CustomMetadataValue actualCustomMetadataValue = CustomMetadataServices.buildCustomMetadataValue(EXPECTED_CUSTOM_METADATA_FIELD_NAME, EXPECTED_CUSTOM_METADATA_FIELD_DATETIME_VALUE);

        Test.stopTest();

        System.assertEquals(SObjectServices.getFullyQualifiedName(EXPECTED_CUSTOM_METADATA_FIELD_NAME), actualCustomMetadataValue.field, 'The custom metadata field should be built properly.');
        System.assertEquals(EXPECTED_CUSTOM_METADATA_FIELD_DATETIME_VALUE, actualCustomMetadataValue.value, 'The custom metadata value should be built properly.');
    }
}