@isTest
private class TestALMApplicationResultServices {
    static testMethod void getAlmApplicationResults() {
        Instances__c prod = new Instances__c(Name='Production');
        insert prod;

        Instances__c sandbox = new Instances__c(Name='Sanbox');
        insert sandbox;

        DateTime now = DateTime.now();
        TestingUtils.createAlmApplicationResult(now, now.addMinutes(2), 'Success', 'Success', prod.Id, ALMJobServices.ToolType.SCAN);
        TestingUtils.createAlmApplicationResult(now, now.addMinutes(2), 'Success', 'Success', sandbox.Id, ALMJobServices.ToolType.SCAN);

        Test.startTest();
            List<ALMApplicationResultModel> actual = ALMApplicationResultServices.getAlmApplicationResults(prod.Id, ALMJobServices.ToolType.SCAN);
        Test.stopTest();

        System.assertEquals(1, actual.size(), 'The query should return all application results for the instance id');
        System.assertEquals(prod.Id, actual.get(0).instanceId, 'The Instance Id on the application result should match the requested instance id');
    }

    static testMethod void getAlmApplicationResults_ignoreCaseStatusFlags() {
        Instances__c prod = new Instances__c(Name='Production');
        insert prod;

        Instances__c sandbox = new Instances__c(Name='Sanbox');
        insert sandbox;

        DateTime now = DateTime.now();
        ALM_Application_Result__c successResult = TestingUtils.createAlmApplicationResult(now, now.addMinutes(2), 'SuCCesS', 'Success', prod.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c successWarningsResult = TestingUtils.createAlmApplicationResult(now, now.addMinutes(2), 'Success WITH WarninGS', 'Success', prod.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c failureResult = TestingUtils.createAlmApplicationResult(now, now.addMinutes(2), 'FAILUrE', 'Success', prod.Id, ALMJobServices.ToolType.SCAN);

        Map<Id, ALMApplicationResultModel> actualMap = new Map<Id, ALMApplicationResultModel>();
        Test.startTest();
            for (ALMApplicationResultModel almResultModel : ALMApplicationResultServices.getAlmApplicationResults(prod.Id, ALMJobServices.ToolType.SCAN)){
                actualMap.put(almResultModel.id, almResultModel);
            }
        Test.stopTest();

        System.assertEquals(3, actualMap.keySet().size(), 'The query should return all application results for the instance id');
        System.assertEquals(true, actualMap.get(successResult.Id).isSuccess, 'The Instance Id on the application result should match the requested instance id');
        System.assertEquals(true, actualMap.get(successWarningsResult.Id).isWarnings, 'The Instance Id on the application result should match the requested instance id');
        System.assertEquals(true, actualMap.get(failureResult.Id).isFailure, 'The Instance Id on the application result should match the requested instance id');

        System.assertEquals(false, actualMap.get(successResult.Id).isFailure, 'The Instance Id on the application result should match the requested instance id');
        System.assertEquals(false, actualMap.get(successResult.Id).isWarnings, 'The Instance Id on the application result should match the requested instance id');

        System.assertEquals(false, actualMap.get(successWarningsResult.Id).isFailure, 'The Instance Id on the application result should match the requested instance id');
        System.assertEquals(false, actualMap.get(successWarningsResult.Id).isSuccess, 'The Instance Id on the application result should match the requested instance id');

        System.assertEquals(false, actualMap.get(failureResult.Id).isWarnings, 'The Instance Id on the application result should match the requested instance id');
        System.assertEquals(false, actualMap.get(failureResult.Id).isSuccess, 'The Instance Id on the application result should match the requested instance id');
    }

    static testMethod void getAlmApplicationResults_nullRunTime() {
        Instances__c prod = new Instances__c(Name='Production');
        insert prod;

        TestingUtils.createAlmApplicationResult(null, null, 'Success', 'Success', prod.Id, ALMJobServices.ToolType.SCAN);

        Test.startTest();
            List<ALMApplicationResultModel> actual = ALMApplicationResultServices.getAlmApplicationResults(prod.Id, ALMJobServices.ToolType.SCAN);
        Test.stopTest();

        System.assertEquals(1, actual.size(), 'The query should return all application results for the instance id');
        System.assertEquals(prod.Id, actual[0].instanceId, 'The Instance Id on the application result should match the requested instance id');
        System.assertEquals(null, actual[0].endTime, 'The end time should be initialized to empty string when the run time is not set');
    }

    static testMethod void getLatestAlmApplicationResult_validSingleInstance() {
        // Set up run times for instance SCAN jobs.
        DateTime startTime = DateTime.now();
        DateTime endTime = startTime.addMinutes(1);

        Instances__c testInstance = new Instances__c(Name='Test Instance');
        insert testInstance;
        List<String> testInstanceIds = new List<String>{ testInstance.Id };

        // Create several application results inserted out-of-order to test that the method grabs the most recent one.
        ALM_Application_Result__c testApplicationResult0 = TestingUtils.createAlmApplicationResult(startTime, endTime, 'Success', 'Success', testInstance.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c testApplicationResult1 = TestingUtils.createAlmApplicationResult(startTime, endTime.addMinutes(1), 'Success', 'Success', testInstance.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c testApplicationResult2 = TestingUtils.createAlmApplicationResult(startTime, endTime.addMinutes(2), 'Success', 'Success', testInstance.Id, ALMJobServices.ToolType.SCAN);

        ALMApplicationResultModel testApplicationResultModel = new ALMApplicationResultModel(testApplicationResult2);

        Test.startTest();
            Map<String, InstanceModel.ScanResult> scanResults = ALMApplicationResultServices.getLatestAlmApplicationResult(testInstanceIds, ALMJobServices.ToolType.SCAN);
        Test.stopTest();

        System.assertEquals(1, scanResults.size(), 'There should only be one application result returned for the single valid instance.');
        InstanceModel.ScanResult scanResult = scanResults.get(testApplicationResultModel.instanceId);
        System.assertEquals(testApplicationResultModel.instanceId, scanResult.record.Instance__c, 'The ID should correspond to the most recent SCAN result.');
        System.assertEquals(testApplicationResultModel.endTime, scanResult.lastRunTime, 'The run time should correspond to the most recent SCAN result.');
    }

    static testMethod void getLatestAlmApplicationResult_validMultipleInstances() {
        // Set up run times for instance SCAN jobs.
        DateTime startTime = DateTime.now();
        DateTime endTime = startTime.addMinutes(1);

        // Set up the first test instance.
        Instances__c testInstance0 = new Instances__c(Name='Test Instance 0');
        insert testInstance0;

        // Create several application results inserted out-of-order to test that the method grabs the most recent one.
        ALM_Application_Result__c testApplicationResult0 = TestingUtils.createAlmApplicationResult(startTime, endTime, 'Success', 'Success', testInstance0.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c testApplicationResult1 = TestingUtils.createAlmApplicationResult(startTime, endTime.addMinutes(1), 'Failure', 'Failed!', testInstance0.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c testApplicationResult2 = TestingUtils.createAlmApplicationResult(startTime, endTime.addMinutes(2), SCANServices.SUCCESS_WITH_WARNINGS_STATUS, 'Success with warnings...', testInstance0.Id, ALMJobServices.ToolType.SCAN);
        ALMApplicationResultModel testApplicationResultModel0 = new ALMApplicationResultModel(testApplicationResult2);

        // Set up the second test instance.
        Instances__c testInstance1 = new Instances__c(Name='Test Instance 1');
        insert testInstance1;

        // Create several application results inserted out-of-order to test that the method grabs the most recent one.
        testApplicationResult0 = TestingUtils.createAlmApplicationResult(startTime, endTime, 'Success', 'Success', testInstance1.Id, ALMJobServices.ToolType.SCAN);
        testApplicationResult1 = TestingUtils.createAlmApplicationResult(startTime, endTime.addMinutes(1), 'Success', 'Success', testInstance1.Id, ALMJobServices.ToolType.SCAN);
        testApplicationResult2 = TestingUtils.createAlmApplicationResult(startTime, endTime.addMinutes(2), 'Failure', 'Failure!', testInstance1.Id, ALMJobServices.ToolType.SCAN);
        ALMApplicationResultModel testApplicationResultModel1 = new ALMApplicationResultModel(testApplicationResult2);

        List<String> testInstanceIds = new List<String>{ testInstance0.Id, testInstance1.Id };

        Test.startTest();
            Map<String, InstanceModel.ScanResult> scanResults = ALMApplicationResultServices.getLatestAlmApplicationResult(testInstanceIds, ALMJobServices.ToolType.SCAN);
        Test.stopTest();

        // Test number of items in SCAN results list.
        System.assertEquals(2, scanResults.size(), 'There should be two SCAN results returned for the two valid instances.');

        // Test Instance 0
        InstanceModel.ScanResult scanResult = scanResults.get(testApplicationResultModel0.instanceId);
        System.assertEquals(testApplicationResultModel0.instanceId, scanResult.record.Instance__c, 'The ID should correspond to the most recent SCAN result.');
        System.assertEquals(testApplicationResultModel0.result.toLowerCase(), scanResult.result.toLowerCase(), 'The result should correspond to the most recent SCAN result.');

        // Test Instance 1
        scanResult = scanResults.get(testApplicationResultModel1.instanceId);
        System.assertEquals(testApplicationResultModel1.instanceId, scanResult.record.Instance__c, 'The ID should correspond to the most recent SCAN result.');
        System.assertEquals(testApplicationResultModel1.result.toLowerCase(), scanResult.result.toLowerCase(), 'The result should correspond to the most recent SCAN result.');
    }

    static testMethod void getLatestAlmApplicationResult_noResults() {
        // Set up the test instance.
        Instances__c testInstance = new Instances__c(Name='Test Instance');
        insert testInstance;
        List<String> testInstanceIds = new List<String>{ testInstance.Id };

        Test.startTest();
            Map<String, InstanceModel.ScanResult> scanResults = ALMApplicationResultServices.getLatestAlmApplicationResult(testInstanceIds, ALMJobServices.ToolType.SCAN);
        Test.stopTest();

        InstanceModel.ScanResult scanResult = scanResults.get(testInstance.Id);

        String expectedLastRunTime = 'N/A';
        String expectedResult = '-';
        System.assertEquals(testInstanceIds.size(), scanResults.size(), 'The size of the returned SCAN result collection should match the size of the instance ID list.');
        System.assertEquals(expectedLastRunTime, scanResult.lastRunTime, 'The last run time should be N/A when there are no SCAN results returned for an invalid ID.');
        System.assertEquals(expectedResult, scanResult.result, 'The result should be a hyphen when there are no SCAN results');
    }

    static testMethod void getLatestAlmApplicationResult_inProgressResults() {
        Instances__c testInstance = TestingUtils.createInstance('Test Instance');
        ALM_Application_Result__c testInProgressResult = TestingUtils.createAlmApplicationResult(DateTime.now(), null, SCANServices.TOOL_STATUS_QUEUED, null, testInstance.Id, ALMJobServices.ToolType.SCAN);

        Test.startTest();

            Map<String, InstanceModel.ScanResult> actualResults = ALMApplicationResultServices.getLatestAlmApplicationResult(new List<String>{ testInstance.Id }, ALMJobServices.ToolType.SCAN);

        Test.stopTest();

        System.assertEquals('N/A', actualResults.get(testInstance.Id).lastRunTime, 'The last run time should be set properly.');
    }

    static testMethod void filterCompletedSCANJobs() {
        Instances__c instance = new Instances__c(Name='Production');
        insert instance;

        ALM_Application_Result__c unfinished = TestingUtils.createAlmApplicationResult(null, null, '', '', instance.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c nonSCAN = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), '', '', instance.Id, ALMJobServices.ToolType.AUTOMATED_TESTING);
        ALM_Application_Result__c failed = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), 'FAILED', '', instance.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c existing = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), SCANServices.SUCCESS_STATUS, '', instance.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c success = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), '', '', instance.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c oldSuccess = success.clone(true, true);
        success.Result__c = SCANServices.SUCCESS_STATUS;

        List<ALM_Application_Result__c> results = new List<ALM_Application_Result__c> {
            unfinished, nonSCAN, failed, existing, success
        };

        Map<Id, ALM_Application_Result__c> oldMap = new Map<Id, ALM_Application_Result__c>(results);
        oldMap.put(success.Id, oldSuccess);

        Test.startTest();
            List<ALM_Application_Result__c> filteredResults = ALMApplicationResultServices.filterCompletedSCANJobs(results, oldMap).get(ALMApplicationResultServices.SUCCESS_RESULT_MAP_IDENTIFIER);
        Test.stopTest();

        System.assertEquals(1, filteredResults.size(), 'Only newly successful SCAN results should be filtered');
        System.assertEquals(success.Id, filteredResults[0].Id, 'Only newly successful SCAN results should be filtered');
    }

    static testMethod void filterAllCompletedSCANJobs_basedOnRuntime() {
        Instances__c instance = new Instances__c(Name='Production');
        insert instance;

        ALM_Application_Result__c unfinished = TestingUtils.createAlmApplicationResult(null, null, '', '', instance.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c nonSCAN = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), '', '', instance.Id, ALMJobServices.ToolType.AUTOMATED_TESTING);
        ALM_Application_Result__c failed = TestingUtils.createAlmApplicationResult(DateTime.now(), null, 'FAILED', '', instance.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c existing = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), SCANServices.SUCCESS_STATUS, '', instance.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c success = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), '', '', instance.Id, ALMJobServices.ToolType.SCAN);
        ALM_Application_Result__c oldSuccess = success.clone(true, true);
        ALM_Application_Result__c oldFailure = failed.clone(true, true);
        success.Result__c = SCANServices.SUCCESS_STATUS;
        failed.Run_Time__c = DateTime.now();

        List<ALM_Application_Result__c> results = new List<ALM_Application_Result__c> {
            unfinished, nonSCAN, failed, existing, success
        };

        Map<Id, ALM_Application_Result__c> oldMap = new Map<Id, ALM_Application_Result__c>(results);
        oldMap.put(success.Id, oldSuccess);
        oldMap.put(failed.Id, oldFailure);

        Test.startTest();
            List<ALM_Application_Result__c> filteredResults = ALMApplicationResultServices.filterCompletedSCANJobs(results, oldMap).get(ALMApplicationResultServices.COMPLETED_RESULT_MAP_IDENTIFIER);
        Test.stopTest();

        System.assertEquals(2, filteredResults.size(), '2 completed SCAN results should be filtered');
        Map<Id, ALM_Application_Result__c> filteredResultsMap = new Map<Id, ALM_Application_Result__c>(filteredResults);
        System.assert(filteredResultsMap.containsKey(success.Id),'The success record should be filtered');
        System.assert(filteredResultsMap.containsKey(failed.id),'The failed record should be filtered');
    }

    static testMethod void getLatestInProgressApplicationResultForJobs() {
        Instances__c testInstance = new Instances__c(Name = 'Test Instance');
        insert testInstance;

        ALM_Job__c testJob0 = TestingUtils.createDefaultButrJob(testInstance, testInstance);
        ALM_Job__c testJob1 = TestingUtils.createDefaultButrJob(testInstance, testInstance);

        ALM_Application_Result__c testApplicationResult0 = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), SCANServices.TOOL_STATUS_QUEUED, null, testInstance.Id, ALMJobServices.ToolType.AUTOMATED_TESTING);
        testApplicationResult0.ALM_Job__c = testJob0.Id;
        Test.setCreatedDate(testApplicationResult0.Id, DateTime.now().addMinutes(-4));

        ALM_Application_Result__c testApplicationResult1 = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), SCANServices.TOOL_STATUS_QUEUED, null, testInstance.Id, ALMJobServices.ToolType.AUTOMATED_TESTING);
        testApplicationResult1.ALM_Job__c = testJob0.Id;
        Test.setCreatedDate(testApplicationResult1.Id, DateTime.now().addMinutes(-3));

        ALM_Application_Result__c testApplicationResult2 = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), SCANServices.TOOL_STATUS_RUNNING, null, testInstance.Id, ALMJobServices.ToolType.AUTOMATED_TESTING);
        testApplicationResult2.ALM_Job__c = testJob1.Id;
        Test.setCreatedDate(testApplicationResult2.Id, DateTime.now().addMinutes(-2));

        ALM_Application_Result__c testApplicationResult3 = TestingUtils.createAlmApplicationResult(DateTime.now(), DateTime.now(), SCANServices.TOOL_STATUS_RUNNING, null, testInstance.Id, ALMJobServices.ToolType.AUTOMATED_TESTING);
        testApplicationResult3.ALM_Job__c = testJob1.Id;
        Test.setCreatedDate(testApplicationResult3.Id, DateTime.now().addMinutes(-1));

        update new List<ALM_Application_Result__c>{testApplicationResult0, testApplicationResult1, testApplicationResult2, testApplicationResult3};

        Test.startTest();

            Map<Id, ALM_Application_Result__c> results = ALMApplicationResultServices.getLatestInProgressApplicationResultForJobs(new Set<Id>{testJob0.Id, testJob1.Id});

        Test.stopTest();

        System.assertEquals(2, results.size(), 'There should be one latest application result for each job.');
        System.assert(results.containsKey(testJob0.Id), 'The job should have an application result.');
        System.assert(results.containsKey(testJob1.Id), 'The job should have an application result.');
        System.assertEquals(testApplicationResult1.Id, results.get(testJob0.Id).Id, 'The proper application result should be returned.');
        System.assertEquals(testApplicationResult3.Id, results.get(testJob1.Id).Id, 'The proper application result should be returned.');
    }

    static testMethod void markResultAsFailure() {
        String testErrorMessage = 'Test Error Message';
        String testErrorCode = 'Test Error Code';

        ALM_Application_Result__c testApplicationResult = new ALM_Application_Result__c();

        Test.startTest();

            ALMApplicationResultServices.markResultAsFailure(testApplicationResult, testErrorMessage, testErrorCode);

        Test.stopTest();

        System.assertEquals(SCANServices.FAILURE_STATUS, testApplicationResult.Result__c, 'The result should be a failure.');
        System.assertEquals(testErrorMessage, testApplicationResult.Error_Message__c, 'The error message should be set properly.');
        System.assertEquals(testErrorCode.abbreviate(ALM_Application_Result__c.Error_Code__c.getDescribe().getLength()), testApplicationResult.Error_Code__c, 'The error code should be set properly.');
        System.assertNotEquals(null, testApplicationResult.Run_Time__c, 'The run time should be set.');
    }
}