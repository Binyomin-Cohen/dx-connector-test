@isTest
private class TestCodeRunSummary {

    static final String JSON_SAMPLE = '{'+
        '  \"size\" : 1,'+
        '  \"totalSize\" : 1,'+
        '  \"done\" : true,'+
        '  \"queryLocator\" : null,'+
        '  \"entityTypeName\" : \"ApexTestRunResult\",'+
        '  \"records\" : [ {'+
        '    \"attributes\" : {'+
        '      \"type\" : \"ApexTestRunResult\",'+
        '      \"url\" : \"/services/data/v39.0/tooling/sobjects/ApexTestRunResult/05m0Y00000008h1QAA\"'+
        '    },'+
        '    \"StartTime\" : \"2017-02-27T18:24:27.000+0000\",'+
        '    \"EndTime\" : \"2017-02-27T18:25:27.000+0000\",'+
        '    \"MethodsFailed\" : 15,'+
        '    \"MethodsCompleted\" : 1060,'+
        '    \"AsyncApexJobId\" : \"7070Y00000EM4UyQAL\"'+
        '  } ]'+
        '}';

    static final String JSON_MISSING_PROPERTIES = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
    static final String START_TIME = 'StartTime';
    static final String END_TIME = 'EndTime';
    static final String METHODS_FAILED = 'MethodsFailed';
    static final String METHODS_COMPLETED = 'MethodsCompleted';
    static final String ASYNC_JOB_ID = 'AsyncApexJobId';
    static Map<String, Object> expectedPropertyToResultsMap = new Map<String, Object>{
                                                               START_TIME => '2017-02-27T18:24:27.000+0000',
                                                               END_TIME => '2017-02-27T18:25:27.000+0000',
                                                               METHODS_FAILED => 15,
                                                               METHODS_COMPLETED => 1060,
                                                               ASYNC_JOB_ID => '7070Y00000EM4UyQAL'};

    static testMethod void testCodeCoverageResultsParse() {
        Test.startTest();
            CodeTestRunSummary summaryResult = (CodeTestRunSummary)JSON.deserialize(JSON_SAMPLE, CodeTestRunSummary.class);

        Test.stopTest();

        System.assertNotEquals(null, summaryResult, 'The summary result should be populated');
        System.assertEquals(1, summaryResult.records.size(), 'The correct number of results should be returned');
        CodeTestRunSummary.Records result =  summaryResult.records[0];

        System.assertEquals(expectedPropertyToResultsMap.get(START_TIME), result.startTime, 'The startTime should be correct');
        System.assertEquals(expectedPropertyToResultsMap.get(END_TIME), result.endTime, 'The endTime should be correct');
        System.assertEquals(expectedPropertyToResultsMap.get(METHODS_FAILED), result.methodsFailed, 'The methodsFailed should be correct');
        System.assertEquals(expectedPropertyToResultsMap.get(METHODS_COMPLETED), result.methodsCompleted, 'The methodsCompleted should be correct');
        System.assertEquals(expectedPropertyToResultsMap.get(ASYNC_JOB_ID), result.asyncApexJobId, 'The asyncApexJobId should be correct');

    }

    static testMethod void testValidCodeCoverageResultsDeconstruct() {
        CodeTestRunSummary summaryResult = (CodeTestRunSummary)JSON.deserialize(JSON_SAMPLE, CodeTestRunSummary.class);
        Map<String, Unit_Test_Summary__c> actualCodeSummaryRecords = new Map<String, Unit_Test_Summary__c>();

        Test.startTest();
            actualCodeSummaryRecords = summaryResult.deconstructIntoSobjectRecords();
        Test.stopTest();

        System.assertEquals(1, actualCodeSummaryRecords.size(), 'The correct number of sobject records should be instantiated');
        System.assert(actualCodeSummaryRecords.containsKey((String)expectedPropertyToResultsMap.get(ASYNC_JOB_ID)), 'The record should map to the correct async ApexJob ID.');
        Unit_Test_Summary__c actualRecord = actualCodeSummaryRecords.get((String)expectedPropertyToResultsMap.get(ASYNC_JOB_ID));
        Long expectedTestTime =
            (DateTime.valueOf(String.valueOf(expectedPropertyToResultsMap.get(END_TIME)).replace('T', ' ')).getTime() -
            DateTime.valueOf(String.valueOf(expectedPropertyToResultsMap.get(START_TIME)).replace('T', ' ')).getTime()) /
            1000;
        System.assertEquals(expectedTestTime, actualRecord.Apex_Test_Time__c, 'The Apex_Test_Time__c should be correct');
        Date expectedDate = DateTime.valueOf(((String)expectedPropertyToResultsMap.get(START_TIME)).replace('T', ' ')).Date();
        System.assertEquals(expectedDate, actualRecord.Test_Date__c, 'The Test_Date__c should be correct');
        System.assertEquals(expectedPropertyToResultsMap.get(METHODS_FAILED), actualRecord.Failed_Apex_Tests__c, 'The Failed_Apex_Tests__c should be correct');
        System.assertEquals(expectedPropertyToResultsMap.get(METHODS_COMPLETED), actualRecord.Total_Apex_Unit_Tests__c, 'The Total_Apex_Unit_Tests__c should be correct');
    }

    static testMethod void deconstructIntoSobjectRecords_nullRecords() {
        Test.startTest();

            Map<String, Unit_Test_Summary__c> actualUnitTestSummaryRecords = null;
            try {
                actualUnitTestSummaryRecords = new CodeTestRunSummary().deconstructIntoSobjectRecords();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertNotEquals(null, actualUnitTestSummaryRecords, 'The unit test summary objects list should not be null.');
        System.assert(actualUnitTestSummaryRecords.isEmpty(), 'There should be no unit test summary objects returned.');
    }

    static testMethod void unitTestSummaryResultForumlaField() {
        Unit_Test_Summary__c testSummaryNoCoverage = new Unit_Test_Summary__c(
            Apex_Total_LOC__c = 10,
            Apex_Lines_Covered__c = 0,
            Failed_Apex_Tests__c = 0
        );

        Unit_Test_Summary__c testSummaryHighCoverage = new Unit_Test_Summary__c(
            Apex_Total_LOC__c = 10,
            Apex_Lines_Covered__c = 8,
            Failed_Apex_Tests__c = 0
        );

        Unit_Test_Summary__c testSummaryLowCoverage = new Unit_Test_Summary__c(
            Apex_Total_LOC__c = 10,
            Apex_Lines_Covered__c = 2,
            Failed_Apex_Tests__c = 0
        );

        Test.startTest();
            testSummaryNoCoverage.recalculateFormulas();
            testSummaryHighCoverage.recalculateFormulas();
            testSummaryLowCoverage.recalculateFormulas();
        Test.stopTest();


        System.assertEquals('Pass', testSummaryHighCoverage.Result__c, 'The summary record should have a result of pass');
        System.assertEquals('Fail', testSummaryLowCoverage.Result__c, 'The summary record should have a result of fail');
        System.assertEquals('Fail', testSummaryNoCoverage.Result__c, 'The summary record should have a result of fail');
    }
}