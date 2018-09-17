//
// Generated by JSON2Apex http://JSON2apex.herokuapp.com/
//

@IsTest
public class TestCodeTestRunResult{

    static final String JSON_SAMPLE = '{'+
    '  \"size\" : 3,'+
    '  \"totalSize\" : 3,'+
    '  \"done\" : true,'+
    '  \"queryLocator\" : null,'+
    '  \"entityTypeName\" : \"ApexTestResult\",'+
    '  \"records\" : [ {'+
    '    \"attributes\" : {'+
    '      \"type\" : \"ApexTestResult\",'+
    '      \"url\" : \"/services/data/v39.0/tooling/sobjects/ApexTestResult/07M0Y000003BECoUAO\"'+
    '    },'+
    '    \"AsyncApexJobId\" : \"7070Y00000EM4UyQAL\",'+
    '    \"MethodName\" : \"testCreateCustomBacklog\",'+
    '    \"Outcome\" : \"Pass\",'+
    '    \"Message\" : null,'+
    '    \"StackTrace\" : null,'+
    '    \"RunTime\" : 55,'+
    '    \"ApexLogId\" : \"07L0Y000001zcCNUAY\",'+
    '    \"ApexClass\" : {'+
    '      \"attributes\" : {'+
    '        \"type\" : \"ApexClass\",'+
    '        \"url\" : \"/services/data/v39.0/tooling/sobjects/ApexClass/01p0Y000006eh62QAA\"'+
    '      },'+
    '      \"Name\" : \"TestBacklogManagementHomeController\"'+
    '    }'+
    '  }, {'+
    '    \"attributes\" : {'+
    '      \"type\" : \"ApexTestResult\",'+
    '      \"url\" : \"/services/data/v39.0/tooling/sobjects/ApexTestResult/07M0Y000003BELWUA4\"'+
    '    },'+
    '    \"AsyncApexJobId\" : \"7070Y00000EM4UyQAL\",'+
    '    \"MethodName\" : \"almPrivateCustomSetting_Fresh_Install\",'+
    '    \"Outcome\" : \"Fail\",'+
    '    \"Message\" : \"System.DmlException: Insert failed. First exception on row 0; first error: UNABLE_TO_LOCK_ROW, unable to obtain exclusive access to this record: []\",'+
    '    \"StackTrace\" : \"Class.PopulateAlmPrivateCustomSetting.populateCustomSetting: line 12, column 1\\nClass.BwAlmPmPostInstall.onInstall: line 9, column 1\\nClass.System.Test.testInstall: line 41, column 1\\nClass.TestBwAlmPmPostInstall.almPrivateCustomSetting_Fresh_Install: line 98, column 1\",'+
    '    \"RunTime\" : 9618,'+
    '    \"ApexLogId\" : \"07L0Y000001zcChUAI\",'+
    '    \"ApexClass\" : {'+
    '      \"attributes\" : {'+
    '        \"type\" : \"ApexClass\",'+
    '        \"url\" : \"/services/data/v39.0/tooling/sobjects/ApexClass/01p0Y000006eh67QAA\"'+
    '      },'+
    '      \"Name\" : \"TestBwAlmPmPostInstall\"'+
    '    }'+
    '  }, {'+
    '    \"attributes\" : {'+
    '      \"type\" : \"ApexTestResult\",'+
    '      \"url\" : \"/services/data/v39.0/tooling/sobjects/ApexTestResult/07M0Y000003BEJGUA4\"'+
    '    },'+
    '    \"AsyncApexJobId\" : \"7070Y00000EM4UyQAL\",'+
    '    \"MethodName\" : \"getRolesByName_valid\",'+
    '    \"Outcome\" : \"Pass\",'+
    '    \"Message\" : null,'+
    '    \"StackTrace\" : null,'+
    '    \"RunTime\" : 50,'+
    '    \"ApexLogId\" : \"07L0Y000001zcDuUAI\",'+
    '    \"ApexClass\" : {'+
    '      \"attributes\" : {'+
    '        \"type\" : \"ApexClass\",'+
    '        \"url\" : \"/services/data/v39.0/tooling/sobjects/ApexClass/01p0Y000006eh5jQAA\"'+
    '      },'+
    '      \"Name\" : \"TestALMUserServices\"'+
    '    }'+
    '  } ]'+
    '}';

    static final String JSON_SAMPLE_MISSING_PROPERTIES = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
    static final String RUN_TIME = 'RunTime';
    static final String OUTCOME = 'Outcome';
    static final String ASYNC_APEX_JOB_ID = 'AsyncApexJobId';
    static final String STACK_TRACE = 'StackTrace';
    static Map<String, Map<String, Object>> expectedMethodNameToResultsMap;

    static void setup() {
        expectedMethodNameToResultsMap = new Map<String, Map<String, Object>>();

        expectedMethodNameToResultsMap.put('testCreateCustomBacklog', new Map<String, Object>{RUN_TIME => 55,
                                                                                                OUTCOME => 'Pass',
                                                                                                ASYNC_APEX_JOB_ID => '7070Y00000EM4UyQAL',
                                                                                                STACK_TRACE => null});

        expectedMethodNameToResultsMap.put('almPrivateCustomSetting_Fresh_Install', new Map<String, Object>{RUN_TIME => 9618,
                                                                                                OUTCOME => 'Fail',
                                                                                                ASYNC_APEX_JOB_ID => '7070Y00000EM4UyQAL',
                                                                                                STACK_TRACE => 'Class.PopulateAlmPrivateCustomSetting.populateCustomSetting:'
                                                                                                                +' line 12, column 1\nClass.BwAlmPmPostInstall.onInstall: line 9,'
                                                                                                                +' column 1\nClass.System.Test.testInstall: line 41, '
                                                                                                                +'column 1\nClass.TestBwAlmPmPostInstall.almPrivateCustomSetting_Fresh_Install:'
                                                                                                                +' line 98, column 1'});

        expectedMethodNameToResultsMap.put('getRolesByName_valid', new Map<String, Object>{RUN_TIME => 50,
                                                                                                OUTCOME => 'Pass',
                                                                                                ASYNC_APEX_JOB_ID => '7070Y00000EM4UyQAL',
                                                                                                STACK_TRACE => null});
    }

    static testMethod void testValidTestRunResultParse() {
        setup();

        Test.startTest();
            CodeTestRunResult testRunResult = (CodeTestRunResult)JSON.deserialize(JSON_SAMPLE, CodeTestRunResult.class);
        Test.stopTest();

        System.assertNotEquals(null, testRunResult, 'The result should be instantiated');
        System.assertEquals(3, testRunResult.size, 'The size should be correct');
        System.assertEquals(3, testRunResult.totalSize, 'The totalSize should be correct');
        System.assert(testRunResult.done, 'The done value should be correct');
        System.assertEquals(null, testRunResult.queryLocator, 'The queryLocator value should be correct');
        System.assertEquals('ApexTestResult', testRunResult.entityTypeName, 'The entityTypeName value should be correct');
        System.assertNotEquals(null, testRunResult.records, 'The records list should be set');
        System.assertEquals(3, testRunResult.records.size(), 'The records size value should be correct');

        Set<String>actualMethodNames = new Set<String>();

        for (CodeTestRunResult.Records resultTestRunRecord : testRunResult.records) {
            actualMethodNames.add(resultTestRunRecord.methodName);
        }

        System.assert(expectedMethodNameToResultsMap.keySet().containsAll(actualMethodNames), 'All of the expected method names should be found');

        for (CodeTestRunResult.Records resultTestRunRecord : testRunResult.records) {
            String methodName = resultTestRunRecord.methodName;
            Integer expectedRunTime = (Integer)expectedMethodNameToResultsMap.get(methodName).get(RUN_TIME);
            String expectedOutCome = (String)expectedMethodNameToResultsMap.get(methodName).get(OUTCOME);
            String expectedJobId = (String)expectedMethodNameToResultsMap.get(methodName).get(ASYNC_APEX_JOB_ID);
            String expectedStackTrace = (String)expectedMethodNameToResultsMap.get(methodName).get(STACK_TRACE);

            Integer actualRunTime = resultTestRunRecord.runTime;
            String actualOutCome = resultTestRunRecord.outcome;
            String actualJobId = resultTestRunRecord.asyncApexJobId;
            String actualStackTrace = (String)resultTestRunRecord.stackTrace;

            System.assertEquals(expectedRunTime, actualRunTime, 'The runtimes should be correct for '+methodName);
            System.assertEquals(expectedOutCome, actualOutCome, 'The outcome should be correct for '+methodName);
            System.assertEquals(expectedJobId, actualJobId, 'The jobId should be correct for '+methodName);
            System.assertEquals(expectedStackTrace, actualStackTrace, 'The stacktrace should be correct for '+methodName);
        }
    }

    static testMethod void testValidTestRunResultDeconstruct() {
        setup();

        CodeTestRunResult testRunResult = (CodeTestRunResult)JSON.deserialize(JSON_SAMPLE, CodeTestRunResult.class);
        List<Unit_Test_Failure__c> actualCodeTestRunRecords = new List<Unit_Test_Failure__c>();

        Test.startTest();
            actualCodeTestRunRecords = testRunResult.deconstructIntoSobjectRecords();
        Test.stopTest();

        System.assertEquals(1, actualCodeTestRunRecords.size(), 'The correct number of sobject records should be instantiated');
        Unit_Test_Failure__c actualRecord = actualCodeTestRunRecords[0];
        System.assertEquals('almPrivateCustomSetting_Fresh_Install', actualRecord.Method_Name__c, 'The correct method should be picked up as a failure');
        System.assertEquals('07L0Y000001zcChUAI', actualRecord.Apex_Log_Id__c, 'The correct apexlogid be picked up as a failure');
        System.assertEquals('TestBwAlmPmPostInstall', actualRecord.Class_Name__c, 'The correct classname should be picked up as a failure');
        System.assertEquals('System.DmlException: Insert failed. First exception on row 0; first error: UNABLE_TO_LOCK_ROW, unable to obtain exclusive access to this record: []', actualRecord.Message__c, 'The correct message should be picked up as a failure');
        System.assertEquals(expectedMethodNameToResultsMap.get('almPrivateCustomSetting_Fresh_Install').get(RUN_TIME), actualRecord.Run_Time__c, 'The correct runtime should be picked up as a failure');
        System.assertEquals(expectedMethodNameToResultsMap.get('almPrivateCustomSetting_Fresh_Install').get(STACK_TRACE), actualRecord.Stack_Trace__c, 'The correct stacktrace should be picked up as a failure');
    }

    static testMethod void deconstructIntoSobjectRecords_nullRecords() {
        Test.startTest();

            List<Unit_Test_Failure__c> actualUnitTestFailureRecords = null;
            try {
                actualUnitTestFailureRecords = new CodeTestRunResult().deconstructIntoSobjectRecords();
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown.');
            }

        Test.stopTest();

        System.assertNotEquals(null, actualUnitTestFailureRecords, 'The unit test failure objects list should not be null.');
        System.assert(actualUnitTestFailureRecords.isEmpty(), 'There should be no unit test failure objects returned.');
    }
}