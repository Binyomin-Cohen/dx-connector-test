@isTest
private class TestSnapshotServices {
    private static final String SNAPSHOT_TOOL_NAME = ALMJobServices.getToolName(ALMJobServices.ToolType.SNAPSHOT);

    static UnitTest.DataGenerator snapshotMappings = new TestingUtils.SnapshotMappingDG();

    static testMethod void testInsertTargetRecords() {

        final Integer NUM_RECORDS = 100;

        UnitTest.addData(new List<User>{new User()}).tag('Invalid User').dummyinsert();

        List<ALM_Job__c>almJobsToInsert = new List<ALM_Job__c>();
        for(Integer i = 0; i < NUM_RECORDS; i++){
            almJobsToInsert.add(new ALM_Job__c());
        }

        UnitTest.addData( almJobsToInsert ).tag('All ALM_Jobs');

        UnitTest.get('All ALM_Jobs')
            .divide( 2 )
                .part('Valid ALM_Jobs')
                .part('Invalid ALM_Jobs');

        UnitTest.get('InValid ALM_Jobs').property('OwnerId').assignFrom('Invalid User');

        String actualErrorString;

        Test.StartTest();
            actualErrorString = SnapshotServices.insertRecords( UnitTest.get('All ALM_Jobs').getList() );
        Test.StopTest();

        System.assert( String.IsNotBlank( actualErrorString ), 'The error string should be constructed' );

        List<String>errorLines = actualErrorString.split(SnapshotServices.ERROR_LINE_SEPARATOR);

        System.assertEquals( NUM_RECORDS / 2, errorLines.size(), 'Half the total amount of records should in the error string' );

        List<ALM_Job__c> successfulJobs = [Select Id from ALM_Job__c];

        UnitTest.analyze('Valid ALM_Jobs').assertEquivalence(successfulJobs, 'The only the expected successful records should persist');
    }

    static testMethod void testTranslateGroupingKeyToGroupingLevel() {

        Test.startTest();
            Integer result1 = SnapshotServices.translateGroupingKeyToGroupingLevel('');
            Integer result2 = SnapshotServices.translateGroupingKeyToGroupingLevel('_kjkds_skjdksjd0_');
            Integer result3 = SnapshotServices.translateGroupingKeyToGroupingLevel('__6');
            Integer result4 = SnapshotServices.translateGroupingKeyToGroupingLevel('6__');
        Test.stopTest();

        System.assertEquals(0, result1, 'The correct number of underscores should be found');
        System.assertEquals(3, result2, 'The correct number of underscores should be found');
        System.assertEquals(2, result3, 'The correct number of underscores should be found');
        System.assertEquals(2, result4, 'The correct number of underscores should be found');
    }

    static testMethod void testMapReportResultsIntoTargetObject_All_Supported_Field_Types() {

        final Date TODAY_DATE = Date.today();
        final DateTime NOW_TIME = DateTime.now();

        final Integer NUM_JOB_RECORDS = 1;
        final String TARGET_TEXT = SObjectServices.getFullyQualifiedName('Sample_Text__c');
        final String TARGET_TEXT_AREA = SObjectServices.getFullyQualifiedName('Sample_Text_Area__c');
        final String TARGET_TEXT_RICH = SObjectServices.getFullyQualifiedName('Sample_Rich_Text__c');
        final String TARGET_TEXT_AREA_LONG = SObjectServices.getFullyQualifiedName('Sample_Text_Area_Long__c');
        final String TARGET_TEXT_ENCRYPTED = SObjectServices.getFullyQualifiedName('Sample_Encrypted_Text__c');
        final String TARGET_CURRENCY = SObjectServices.getFullyQualifiedName('Sample_Currency__c');
        final String TARGET_DATE = SObjectServices.getFullyQualifiedName('Sample_Date__c');
        final String TARGET_DATE_TIME = SObjectServices.getFullyQualifiedName('Sample_Date_Time__c');
        final String TARGET_EMAIL = SObjectServices.getFullyQualifiedName('Sample_Email__c');
        final String TARGET_INTEGER = SObjectServices.getFullyQualifiedName('Sample_Integer__c');
        final String TARGET_MULTIPICKLIST = SObjectServices.getFullyQualifiedName('Sample_Multi_picklist__c');
        final String TARGET_PICKLIST = SObjectServices.getFullyQualifiedName('Sample_Picklist__c');
        final String TARGET_NUMBER = SObjectServices.getFullyQualifiedName('Sample_Number__c');
        final String TARGET_PERCENT = SObjectServices.getFullyQualifiedName('Sample_Percent__c');
        final String TARGET_PHONE = SObjectServices.getFullyQualifiedName('Sample_Phone__c');
        final String TARGET_CHECKBOX = SObjectServices.getFullyQualifiedName('Sample_Checkbox__c');
        final String TARGET_URL = SObjectServices.getFullyQualifiedName('Sample_URL__c');

        final String SOURCE_TEXT = 'Sample Text';
        final String SOURCE_TEXT_AREA = 'Sample Text Area';
        final String SOURCE_TEXT_RICH = 'Sample Rich Text';
        final String SOURCE_TEXT_AREA_LONG = 'Sample Text Area Long';
        final String SOURCE_TEXT_ENCRYPTED = 'Sample Encrypted Text';
        final String SOURCE_CURRENCY = 'My Currency';
        final String SOURCE_DATE = 'My Date';
        final String SOURCE_DATE_TIME = 'My Date Time';
        final String SOURCE_EMAIL = 'My Email';
        final String SOURCE_INTEGER = 'My Integer';
        final String SOURCE_MULTIPICKLIST = 'My MultiPicklist';
        final String SOURCE_PICKLIST = 'My Source Picklist';
        final String SOURCE_NUMBER = 'My Number';
        final String SOURCE_PERCENT = 'My Percent';
        final String SOURCE_PHONE = 'My Phone';
        final String SOURCE_CHECKBOX = 'My Checkbox';
        final String SOURCE_URL = 'My Url';

        final String VALUE_TEXT = 'Sample Text';
        final String VALUE_TEXT_AREA = 'Sample Text \n Area';
        final String VALUE_TEXT_RICH = 'Sample Rich Text';
        final String VALUE_TEXT_AREA_LONG = 'Sample Text Area \n Long';
        final String VALUE_TEXT_ENCRYPTED = 'Sample Encrypted Text';
        final String VALUE_CURRENCY = '£45,000.00';
        final String VALUE_DATE = TODAY_DATE.format();
        final String VALUE_DATE_TIME = NOW_TIME.format();
        final String VALUE_EMAIL = 'test@test.com';
        final String VALUE_INTEGER = '23';
        final String VALUE_MULTIPICKLIST = '1; five';
        final String VALUE_PICKLIST = 'five';
        final String VALUE_NUMBER = '23.5';
        final String VALUE_PERCENT = '100%';
        final String VALUE_PHONE = '+44 20 7234 3456';
        final String VALUE_CHECKBOX = 'true';
        final String VALUE_URL = '&lt;a href=&quot;javascript:openPopupFocus%28%27https%3A%2F%2Fwww.google.com%27%2C%20%27_blank%27%2C%20620%2C%20430%2C%20%27width%3D620%2Cheight%3D430%2Cresizable%3Dyes%2Ctoolbar%3Dyes%2Cstatus%3Dyes%2Cscrollbars%3Dyes%2Cmenubar%3Dyes%2Cdirectories%3Dyes%2Clocation%3Dyes%2Cdependant%3Dno%27%2C%20false%2C%20true%29%3B&quot; title=&quot;https://www.google.com (New Window)&quot;&gt;https://www.google.com&lt;/a&gt;';

        final List<String> targetFieldApiNames = new List<String>{TARGET_TEXT,TARGET_TEXT_AREA,TARGET_TEXT_RICH,TARGET_TEXT_AREA_LONG,TARGET_TEXT_ENCRYPTED,
                                                            TARGET_CURRENCY, TARGET_DATE, TARGET_DATE_TIME, TARGET_EMAIL, TARGET_INTEGER, TARGET_MULTIPICKLIST,
                                                            TARGET_PICKLIST, TARGET_NUMBER, TARGET_PERCENT, TARGET_PHONE, TARGET_CHECKBOX, TARGET_URL};

        final List<String> sourceColumnNames = new List<String>{SOURCE_TEXT,SOURCE_TEXT_AREA,SOURCE_TEXT_RICH,SOURCE_TEXT_AREA_LONG,SOURCE_TEXT_ENCRYPTED,
                                                            SOURCE_CURRENCY, SOURCE_DATE, SOURCE_DATE_TIME, SOURCE_EMAIL, SOURCE_INTEGER, SOURCE_MULTIPICKLIST,
                                                            SOURCE_PICKLIST, SOURCE_NUMBER, SOURCE_PERCENT, SOURCE_PHONE, SOURCE_CHECKBOX, SOURCE_URL};

        final Integer NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB = sourceColumnNames.size();

        List<ALM_Job__c>almJobsToInsert = new List<ALM_Job__c>();
        for(Integer i = 0; i < NUM_JOB_RECORDS; i++){
            almJobsToInsert.add(new ALM_Job__c(Tool__c = SNAPSHOT_TOOL_NAME, Target_Object_Api_Name__c = SObjectServices.getFullyQualifiedName('Account_Snapshot__c') ));
        }

        UnitTest.addData( almJobsToInsert ).tag('All ALM_Jobs');

        UnitTest.get('All ALM_Jobs').insertAll();

        UnitTest.forEach('All ALM_Jobs')
                .create(NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB, snapshotMappings)
                .copyProperty('ID->' + SObjectServices.getFullyQualifiedName('ALM_Job__c'))
                .tag('All Snapshot Mappings');

        UnitTest.get('All Snapshot Mappings')
                .property(SObjectServices.getFullyQualifiedName('Target_Field_Api_Name__c')).assignFrom(targetFieldApiNames)
                .property(SObjectServices.getFullyQualifiedName('Report_Column__c')).assignFrom(sourceColumnNames);

        UnitTest.get('All Snapshot Mappings').insertAll();

        ALM_Job__c testSnapshot = [SELECT
                                                Id, Target_Object_Api_Name__c, Errors__c,
                                                (SELECT Id, ALM_Job__c, Report_Column__c, Target_Field_Api_Name__c FROM Snapshot_Field_Mappings__r)
                                            FROM ALM_Job__c];

        List<Map<String,String>> reportResults = new List<Map<String,String>>{
            new Map<String, String>{SOURCE_TEXT => VALUE_TEXT, SOURCE_TEXT_AREA => VALUE_TEXT_AREA,
                                    SOURCE_TEXT_RICH => VALUE_TEXT_RICH, SOURCE_TEXT_AREA_LONG => VALUE_TEXT_AREA_LONG,
                                    SOURCE_TEXT_ENCRYPTED => VALUE_TEXT_ENCRYPTED, SOURCE_CURRENCY => VALUE_CURRENCY,
                                    SOURCE_DATE => VALUE_DATE, SOURCE_DATE_TIME => VALUE_DATE_TIME,
                                    SOURCE_EMAIL => VALUE_EMAIL, SOURCE_INTEGER => VALUE_INTEGER,
                                    SOURCE_MULTIPICKLIST => VALUE_MULTIPICKLIST, SOURCE_PICKLIST => VALUE_PICKLIST,
                                    SOURCE_NUMBER => VALUE_NUMBER, SOURCE_PERCENT => VALUE_PERCENT,
                                    SOURCE_PHONE => VALUE_PHONE, SOURCE_CHECKBOX => VALUE_CHECKBOX,
                                    SOURCE_URL => VALUE_URL}
        };

        Test.startTest();
            List<Account_Snapshot__c> actualAccountSnapshots = ( List<Account_Snapshot__c> ) SnapshotServices.mapReportResultsIntoTargetObject(reportResults, testSnapshot);
        Test.stopTest();

        System.assertEquals(1, actualAccountSnapshots.size(), 'Only one account should be populated');
        System.assertEquals(VALUE_TEXT, actualAccountSnapshots[0].Sample_Text__c, 'The account snapshot text should be captured and converted accurately');
        System.assertEquals(VALUE_TEXT_AREA, actualAccountSnapshots[0].Sample_Text_Area__c, 'The account snapshot text area should be captured and converted accurately');
        System.assertEquals(VALUE_TEXT_RICH, actualAccountSnapshots[0].Sample_Rich_Text__c, 'The account snapshot text rich should be captured and converted accurately');
        System.assertEquals(VALUE_TEXT_AREA_LONG, actualAccountSnapshots[0].Sample_Text_Area_Long__c, 'The account snapshot text long should be captured and converted accurately');
        System.assertEquals(VALUE_TEXT_ENCRYPTED, actualAccountSnapshots[0].Sample_Encrypted_Text__c, 'The account snapshot text encrypted should be captured and converted accurately');
        System.assertEquals(VALUE_EMAIL, actualAccountSnapshots[0].Sample_Email__c, 'The account snapshot email should be captured and converted accurately');
        System.assertEquals(VALUE_MULTIPICKLIST, actualAccountSnapshots[0].Sample_Multi_picklist__c, 'The account snapshot multi picklist should be captured and converted accurately');
        System.assertEquals(VALUE_PICKLIST, actualAccountSnapshots[0].Sample_Picklist__c, 'The account snapshot picklist should be captured and converted accurately');
        System.assertEquals(VALUE_PHONE, actualAccountSnapshots[0].Sample_Phone__c, 'The account snapshot phone should be captured and converted accurately');
        System.assertEquals(45000.00, actualAccountSnapshots[0].Sample_Currency__c, 'The account snapshot currency should be captured and converted accurately');
        System.assertEquals(true, actualAccountSnapshots[0].Sample_Checkbox__c, 'The account snapshot checkbox should be captured and converted accurately');
        System.assertEquals(23, actualAccountSnapshots[0].Sample_Integer__c, 'The account snapshot integer should be captured and converted accurately');
        System.assertEquals(23.5, actualAccountSnapshots[0].Sample_Number__c, 'The account snapshot number should be captured and converted accurately');
        System.assertEquals(TODAY_DATE, actualAccountSnapshots[0].Sample_Date__c, 'The account snapshot date should be captured and converted accurately');
        System.assertEquals(VALUE_DATE_TIME, actualAccountSnapshots[0].Sample_Date_Time__c.format(), 'The account snapshot date time should be captured and converted accurately');
        System.assertEquals(100, actualAccountSnapshots[0].Sample_Percent__c, 'The account snapshot percent should be captured and converted accurately');
        System.assertEquals('https://www.google.com', actualAccountSnapshots[0].Sample_URL__c, 'The account snapshot url should be captured and converted accurately');
    }

    static testMethod void testGenerateFieldAPINamesToType() {

        Map<String, Schema.SOAPType> EXPECTED_FIELD_API_TO_SOAP_TYPE = new Map<String, Schema.SOAPType>{
            SObjectServices.getFullyQualifiedName('sample_checkbox__c') => Schema.SOAPType.BOOLEAN,
            SObjectServices.getFullyQualifiedName('sample_currency__c') => Schema.SOAPType.DOUBLE,
            SObjectServices.getFullyQualifiedName('sample_date__c') => Schema.SOAPType.DATE,
            SObjectServices.getFullyQualifiedName('sample_date_time__c') => Schema.SOAPType.DATETIME,
            SObjectServices.getFullyQualifiedName('sample_email__c') => Schema.SOAPType.STRING,
            SObjectServices.getFullyQualifiedName('sample_number__c') => Schema.SOAPType.DOUBLE,
            SObjectServices.getFullyQualifiedName('sample_integer__c') => Schema.SOAPType.DOUBLE,
            SObjectServices.getFullyQualifiedName('sample_percent__c') => Schema.SOAPType.DOUBLE,
            SObjectServices.getFullyQualifiedName('sample_phone__c') => Schema.SOAPType.STRING,
            SObjectServices.getFullyQualifiedName('sample_picklist__c') => Schema.SOAPType.STRING,
            SObjectServices.getFullyQualifiedName('sample_multi_picklist__c') => Schema.SOAPType.STRING,
            SObjectServices.getFullyQualifiedName('sample_text__c') => Schema.SOAPType.STRING,
            SObjectServices.getFullyQualifiedName('sample_text_area__c') => Schema.SOAPType.STRING,
            SObjectServices.getFullyQualifiedName('sample_text_area_long__c') => Schema.SOAPType.STRING,
            SObjectServices.getFullyQualifiedName('sample_rich_text__c') => Schema.SOAPType.STRING,
            SObjectServices.getFullyQualifiedName('sample_encrypted_text__c') => Schema.SOAPType.STRING,
            SObjectServices.getFullyQualifiedName('sample_url__c') => Schema.SOAPType.STRING
        };

        Test.startTest();
            Map<String, Schema.SOAPType> actualTypeMap = SnapshotServices.generateFieldAPINamesToType(Schema.getGlobalDescribe().get(SObjectServices.getFullyQualifiedName('Account_Snapshot__c')).getDescribe().fields.getMap());
        Test.stopTest();

        System.assert(actualTypeMap.keySet().containsAll(EXPECTED_FIELD_API_TO_SOAP_TYPE.keySet()), 'All Keys should be detected');

        for(String fieldApi : EXPECTED_FIELD_API_TO_SOAP_TYPE.keySet()){
            System.assertEquals(EXPECTED_FIELD_API_TO_SOAP_TYPE.get(fieldApi), actualTypeMap.get(fieldApi), 'The correct soap type should be detected for '+ fieldApi);
        }

    }

    static testMethod void testMapReportResultsIntoTargetObject_sobjectFieldMappingError() {
        final Integer NUM_JOB_RECORDS = 1;
        final String TARGET_TEXT = SObjectServices.getFullyQualifiedName('Sample_TextERROR__c');
        final String TARGET_TEXT_AREA = SObjectServices.getFullyQualifiedName('Sample_Text_Area__c');
        final String TARGET_OBJECT = SObjectServices.getFullyQualifiedName('Account_Snapshot__c');

        final String SOURCE_TEXT = 'Sample Text';
        final String SOURCE_TEXT_AREA = 'Sample Text Area';

        final String VALUE_TEXT = 'Sample Text';
        final String VALUE_TEXT_AREA = 'Sample Text \n Area';

        final List<String> targetFieldApiNames = new List<String>{TARGET_TEXT,TARGET_TEXT_AREA};

        final List<String> sourceColumnNames = new List<String>{SOURCE_TEXT,SOURCE_TEXT_AREA};

        final Integer NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB = sourceColumnNames.size();

        List<ALM_Job__c>almJobsToInsert = new List<ALM_Job__c>();
        for(Integer i = 0; i < NUM_JOB_RECORDS; i++){
            almJobsToInsert.add(new ALM_Job__c(Tool__c = SNAPSHOT_TOOL_NAME, Target_Object_Api_Name__c = TARGET_OBJECT ));
        }

        UnitTest.addData( almJobsToInsert ).tag('All ALM_Jobs');

        UnitTest.get('All ALM_Jobs').insertAll();

        UnitTest.forEach('All ALM_Jobs')
                .create(NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB, snapshotMappings)
                .copyProperty('ID->' + SObjectServices.getFullyQualifiedName('ALM_Job__c'))
                .tag('All Snapshot Mappings');

        UnitTest.get('All Snapshot Mappings')
                .property(SObjectServices.getFullyQualifiedName('Target_Field_Api_Name__c')).assignFrom(targetFieldApiNames)
                .property(SObjectServices.getFullyQualifiedName('Report_Column__c')).assignFrom(sourceColumnNames);

        UnitTest.get('All Snapshot Mappings').insertAll();

        ALM_Job__c testSnapshot = [SELECT
                                                Id, Target_Object_Api_Name__c, Errors__c,
                                                (SELECT Id, ALM_Job__c, Report_Column__c, Target_Field_Api_Name__c FROM Snapshot_Field_Mappings__r)
                                            FROM ALM_Job__c];

        List<Map<String,String>> reportResults = new List<Map<String,String>>{
            new Map<String, String>{SOURCE_TEXT => VALUE_TEXT, SOURCE_TEXT_AREA => VALUE_TEXT_AREA}
        };
        List<Account_Snapshot__c> actualAccountSnapshots;
        Test.startTest();
            try{
                actualAccountSnapshots = ( List<Account_Snapshot__c> ) SnapshotServices.mapReportResultsIntoTargetObject(reportResults, testSnapshot);
                System.assert(false, 'We should receive a mapping exception');
            }catch(Exception ex){
                System.assert(ex.getMessage().contains(System.Label.Snapshot_Report_Data_Conversion_Error),'The error message should contain the correct label');
                System.assert(ex.getMessage().contains(TARGET_TEXT.toLowerCase()),'The error message should contain the correct field that caused the error');
                System.assert(ex.getMessage().contains(TARGET_OBJECT),'The error message should contain the correct object that caused the error');
            }
        Test.stopTest();

        System.assertEquals(null, actualAccountSnapshots, 'No account snapshots should be populated');
    }

    static testMethod void testMapReportResultsIntoTargetObject_reportColumnMappingError() {
        final Integer NUM_JOB_RECORDS = 1;
        final String TARGET_TEXT = SObjectServices.getFullyQualifiedName('Sample_Text__c');
        final String TARGET_TEXT_AREA = SObjectServices.getFullyQualifiedName('Sample_Text_Area__c');
        final String TARGET_OBJECT = SObjectServices.getFullyQualifiedName('Account_Snapshot__c');

        final String SOURCE_TEXT = 'Sample Text';
        final String SOURCE_TEXT_MISSING = SOURCE_TEXT + '_missing';
        final String SOURCE_TEXT_AREA = 'Sample Text Area';

        final String VALUE_TEXT = 'Sample Text';
        final String VALUE_TEXT_AREA = 'Sample Text \n Area';

        final List<String> targetFieldApiNames = new List<String>{TARGET_TEXT,TARGET_TEXT_AREA};

        final List<String> sourceColumnNames = new List<String>{SOURCE_TEXT_MISSING,SOURCE_TEXT_AREA};

        final Integer NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB = sourceColumnNames.size();

        List<ALM_Job__c>almJobsToInsert = new List<ALM_Job__c>();
        for(Integer i = 0; i < NUM_JOB_RECORDS; i++){
            almJobsToInsert.add(new ALM_Job__c(Tool__c = SNAPSHOT_TOOL_NAME, Target_Object_Api_Name__c = TARGET_OBJECT ));
        }

        UnitTest.addData( almJobsToInsert ).tag('All ALM_Jobs');

        UnitTest.get('All ALM_Jobs').insertAll();

        UnitTest.forEach('All ALM_Jobs')
                .create(NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB, snapshotMappings)
                .copyProperty('ID->' + SObjectServices.getFullyQualifiedName('ALM_Job__c'))
                .tag('All Snapshot Mappings');

        UnitTest.get('All Snapshot Mappings')
                .property(SObjectServices.getFullyQualifiedName('Target_Field_Api_Name__c')).assignFrom(targetFieldApiNames)
                .property(SObjectServices.getFullyQualifiedName('Report_Column__c')).assignFrom(sourceColumnNames);

        UnitTest.get('All Snapshot Mappings').insertAll();

        ALM_Job__c testSnapshot = [SELECT
                                                Id, Target_Object_Api_Name__c, Errors__c,
                                                (SELECT Id, ALM_Job__c, Report_Column__c, Target_Field_Api_Name__c FROM Snapshot_Field_Mappings__r)
                                            FROM ALM_Job__c];

        List<Map<String,String>> reportResults = new List<Map<String,String>>{
            new Map<String, String>{SOURCE_TEXT => VALUE_TEXT, SOURCE_TEXT_AREA => VALUE_TEXT_AREA}
        };
        List<Account_Snapshot__c> actualAccountSnapshots;
        Test.startTest();
            try{
                actualAccountSnapshots = ( List<Account_Snapshot__c> ) SnapshotServices.mapReportResultsIntoTargetObject(reportResults, testSnapshot);
                System.assert(false, 'We should receive a mapping exception');
            }catch(Exception ex){
                System.assert(ex.getMessage().contains(System.Label.Snapshot_Report_Data_Conversion_Error),'The error message should contain the correct label');
                System.assert(ex.getMessage().contains(SOURCE_TEXT_MISSING),'The error message should contain the correct report column that caused the error');
            }
        Test.stopTest();

        System.assertEquals(null, actualAccountSnapshots, 'No account snapshots should be populated');
    }

    static testMethod void testMapReportResultsIntoTargetObject_dataTypeMismatchMappingError() {
        final Integer NUM_JOB_RECORDS = 1;
        final String TARGET_TEXT = SObjectServices.getFullyQualifiedName('Sample_Date__c');
        final String TARGET_TEXT_AREA = SObjectServices.getFullyQualifiedName('Sample_Text_Area__c');
        final String TARGET_OBJECT = SObjectServices.getFullyQualifiedName('Account_Snapshot__c');

        final String SOURCE_TEXT = 'Sample Text';
        final String SOURCE_TEXT_AREA = 'Sample Text Area';

        final String VALUE_TEXT = 'Sample Text';
        final String VALUE_TEXT_AREA = 'Sample Text \n Area';

        final List<String> targetFieldApiNames = new List<String>{TARGET_TEXT,TARGET_TEXT_AREA};

        final List<String> sourceColumnNames = new List<String>{SOURCE_TEXT,SOURCE_TEXT_AREA};

        final Integer NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB = sourceColumnNames.size();

        List<ALM_Job__c>almJobsToInsert = new List<ALM_Job__c>();
        for(Integer i = 0; i < NUM_JOB_RECORDS; i++){
            almJobsToInsert.add(new ALM_Job__c(Tool__c = SNAPSHOT_TOOL_NAME, Target_Object_Api_Name__c = TARGET_OBJECT ));
        }

        UnitTest.addData( almJobsToInsert ).tag('All ALM_Jobs');

        UnitTest.get('All ALM_Jobs').insertAll();

        UnitTest.forEach('All ALM_Jobs')
                .create(NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB, snapshotMappings)
                .copyProperty('ID->' + SObjectServices.getFullyQualifiedName('ALM_Job__c'))
                .tag('All Snapshot Mappings');

        UnitTest.get('All Snapshot Mappings')
                .property(SObjectServices.getFullyQualifiedName('Target_Field_Api_Name__c')).assignFrom(targetFieldApiNames)
                .property(SObjectServices.getFullyQualifiedName('Report_Column__c')).assignFrom(sourceColumnNames);

        UnitTest.get('All Snapshot Mappings').insertAll();

        ALM_Job__c testSnapshot = [SELECT
                                                Id, Target_Object_Api_Name__c, Errors__c,
                                                (SELECT Id, ALM_Job__c, Report_Column__c, Target_Field_Api_Name__c FROM Snapshot_Field_Mappings__r)
                                            FROM ALM_Job__c];

        List<Map<String,String>> reportResults = new List<Map<String,String>>{
            new Map<String, String>{SOURCE_TEXT => VALUE_TEXT, SOURCE_TEXT_AREA => VALUE_TEXT_AREA}
        };
        List<Account_Snapshot__c> actualAccountSnapshots;
        Test.startTest();
            try{
                actualAccountSnapshots = ( List<Account_Snapshot__c> ) SnapshotServices.mapReportResultsIntoTargetObject(reportResults, testSnapshot);
                System.assert(false, 'We should receive a mapping exception');
            }catch(Exception ex){
                System.assert(ex.getMessage().contains(System.Label.Snapshot_Report_Data_Conversion_Error),'The error message should contain the correct label');
            }
        Test.stopTest();

        System.assertEquals(null, actualAccountSnapshots, 'No account snapshots should be populated');
    }

    private static testMethod void organizeReportResults_formatNotSupported() {
        String reportResultsJsonString = '{"reportMetadata":{"reportFormat":"MATRIX"}}';
        Reports.ReportResults reportRunResults = (Reports.ReportResults)JSON.deserialize(reportResultsJsonString, Reports.ReportResults.class);

        Test.startTest();

            try{
                List<Map<String, String>> organizedResults = SnapshotServices.organizeReportResults(reportRunResults);
                System.assert(false, 'We should receive a report type not supported exception');
            }catch(Exception ex){
                System.assert(ex.getMessage().contains(System.Label.Error_Report_Format),'The error message should contain the correct label');
            }

        Test.stopTest();
    }

}