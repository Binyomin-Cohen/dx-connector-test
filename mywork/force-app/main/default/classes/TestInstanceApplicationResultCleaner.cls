@isTest
private class TestInstanceApplicationResultCleaner {
    private static List<ALM_Application_Result__c> createApplicationResults(Integer numberOfResults, Id instanceId, ALMJobServices.ToolType toolType, String status, DateTime now, Integer createdTimeOffset, Boolean distributeCreatedTime, Boolean setCreatedDate) {
        return createApplicationResults(numberOfResults, instanceId, ALMJobServices.getToolName(toolType), status, now, createdTimeOffset, distributeCreatedTime, setCreatedDate);
    }

    private static List<ALM_Application_Result__c> createApplicationResults(Integer numberOfResults, Id instanceId, String toolType, String status, DateTime now, Integer createdTimeOffset, Boolean distributeCreatedTime, Boolean setRunTime) {
        if (now == null) {
            now = DateTime.now();
        }
        if (createdTimeOffset == null) {
            createdTimeOffset = 0;
        }

        List<ALM_Application_Result__c> results = new List<ALM_Application_Result__c>();
        for (Integer i = 0; i < numberOfResults; ++i) {
            results.add(new ALM_Application_Result__c(
                Instance__c = instanceId,
                Tool__c = toolType,
                Result__c = status,
                Run_Time__c = setRunTime ? now : null
            ));
        }
        insert results;

        for (Integer i = 0; i < results.size(); ++i) {
            DateTime createdTime = distributeCreatedTime ? now.addDays(-1 * i) : now;
            createdTime = createdTime.addDays(-1 * createdTimeOffset);

            Test.setCreatedDate(results[i].Id, createdTime);
        }

        results = [SELECT Id, CreatedDate FROM ALM_Application_Result__c WHERE Id IN :results ORDER BY CreatedDate DESC];

        return results;
    }

    private static void assertResults(List<ALM_Application_Result__c> testResults, List<ALM_Application_Result__c> actualResults, Integer resultRetentionCount) {
        List<ALM_Application_Result__c> expectedResults = TestingUtils.sortResults(testResults, resultRetentionCount);
        System.assertEquals(expectedResults.size(), actualResults.size(), 'The proper number of application results should be retained.');
        for (Integer i = 0; i < actualResults.size(); ++i) {
            System.assertEquals(expectedResults[i].Id, actualResults[i].Id, 'The proper application results should be retained.');
        }
    }

    private static testMethod void noDeletions_singleTool_singleInstance_defaultRetention() {
        Instances__c testInstance = new Instances__c();
        insert testInstance;

        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(5, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, DateTime.now(), 0, true, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id, CreatedDate FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, testResults.size());
    }

    private static testMethod void noDeletions_singleTool_singleInstance_defaultRetention_jobRunning() {
        Instances__c testInstance = new Instances__c();
        insert testInstance;

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        List<ALM_Application_Result__c> jobInProgressResults = createApplicationResults(1, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.FAILURE_STATUS, now, 0, false, true);
        jobInProgressResults[0].Error_Code__c = ALMJobServices.ERROR_CODE_JOB_IN_PROGRESS;
        update jobInProgressResults;
        testResults.addAll(jobInProgressResults);
        testResults.addAll(createApplicationResults(1, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.TOOL_STATUS_QUEUED, now, 1, true, false));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id, CreatedDate FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, testResults.size());
    }

    private static testMethod void noDeletions_otherTool_singleInstance_defaultRetention() {
        Instances__c testInstance = new Instances__c();
        insert testInstance;

        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(15, testInstance.Id, 'Other Tool', SCANServices.SUCCESS_STATUS, DateTime.now(), 0, true, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, testResults.size());
    }

    private static testMethod void noDeletions_singleTool_singleInstance_customRetention() {
        insert new ALMSettings__c(Sync_History_Retention__c = 1);

        Instances__c testInstance = new Instances__c();
        insert testInstance;

        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(5, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, DateTime.now(), 0, true, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, testResults.size());
    }

    private static testMethod void noDeletions_singleTool_multipleInstances_defaultRetention() {
        Instances__c testInstance0 = new Instances__c();
        Instances__c testInstance1 = new Instances__c();
        insert new List<Instances__c>{testInstance0, testInstance1};

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(5, testInstance0.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 0, true, true));
        testResults.addAll(createApplicationResults(10, testInstance1.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 5, true, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, testResults.size());
    }

    private static testMethod void noDeletions_singleTool_multipleInstances_customRetention() {
        insert new ALMSettings__c(Sync_History_Retention__c = 30);

        Instances__c testInstance0 = new Instances__c();
        Instances__c testInstance1 = new Instances__c();
        insert new List<Instances__c>{testInstance0, testInstance1};

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(5, testInstance0.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 0, true, true));
        testResults.addAll(createApplicationResults(15, testInstance1.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 5, true, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, testResults.size());
    }

    private static testMethod void deletions_singleTool_noInstance_defaultRetention() {
        createApplicationResults(15, null, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, DateTime.now(), 0, true, true);

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        System.assertEquals(0, actualResults.size(), 'All orphaned application results should be deleted.');
    }

    private static testMethod void noDeletions_otherTool_noInstance_defaultRetention() {
        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(15, null, 'Other Tool', SCANServices.SUCCESS_STATUS, DateTime.now(), 0, true, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, testResults.size());
    }

    private static testMethod void deletions_singleTool_singleInstance_defaultRetention_unfinishedResultRemains() {
        Instances__c testInstance = new Instances__c();
        insert testInstance;

        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(15, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, DateTime.now(), 0, true, true));
        testResults[0].Run_Time__c = null;
        update testResults[0];

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c WHERE Run_Time__c = null];
        System.assertEquals(1, actualResults.size(), 'The unfinished application result should not be deleted.');
        System.assertEquals(testResults[0].Id, actualResults[0].Id, 'The proper application result should not be deleted.');
    }

    private static testMethod void deletions_singleTool_singleInstance_defaultRetention() {
        Instances__c testInstance = new Instances__c();
        insert testInstance;

        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(15, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, DateTime.now(), 0, true, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, 10);
    }

    private static testMethod void deletions_singleTool_multipleInstances_defaultRetention() {
        Instances__c testInstance0 = new Instances__c();
        Instances__c testInstance1 = new Instances__c();
        insert new List<Instances__c>{testInstance0, testInstance1};

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResultsInstance0 = createApplicationResults(5, testInstance0.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 0, true, true);
        List<ALM_Application_Result__c> testResultsInstance1 = createApplicationResults(15, testInstance1.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 5, true, true);

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResultsInstance0 = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance0.Id];
        assertResults(testResultsInstance0, actualResultsInstance0, testResultsInstance0.size());

        List<ALM_Application_Result__c> actualResultsInstance1 = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance1.Id];
        assertResults(testResultsInstance0, actualResultsInstance0, 10);
    }

    private static testMethod void deletions_singleTool_multipleInstances_customRetention() {
        insert new ALMSettings__c(Sync_History_Retention__c = 1);

        Instances__c testInstance0 = new Instances__c();
        Instances__c testInstance1 = new Instances__c();
        insert new List<Instances__c>{testInstance0, testInstance1};

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResultsInstance0 = createApplicationResults(5, testInstance0.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 1, true, true);
        List<ALM_Application_Result__c> testResultsInstance1 = createApplicationResults(15, testInstance1.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 0, false, true);
        testResultsInstance1.addAll(createApplicationResults(5, testInstance1.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 1, true, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResultsInstance0 = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance0.Id ORDER BY CreatedDate DESC];
        assertResults(testResultsInstance0, actualResultsInstance0, 5);

        List<ALM_Application_Result__c> actualResultsInstance1 = [SELECT CreatedDate FROM ALM_Application_Result__c WHERE Instance__c = :testInstance1.Id ORDER BY CreatedDate DESC];
        System.assertEquals(15, actualResultsInstance1.size(), 'All eligible application results should be deleted.');
        for (ALM_Application_Result__c actualResult : actualResultsInstance1) {
            if (actualResult.CreatedDate > now) {
                System.assert(false, 'No remaining application results should be older than the retention threshold.');
            }
        }
    }

    private static testMethod void deletions_multipleTools_singleInstance_defaultRetention() {
        Instances__c testInstance = new Instances__c();
        insert testInstance;

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResultsScan = createApplicationResults(15, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 0, true, true);
        List<ALM_Application_Result__c> testResultsButr = createApplicationResults(15, testInstance.Id, ALMJobServices.ToolType.AUTOMATED_TESTING, SCANServices.SUCCESS_STATUS, now, 0, true, true);

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResultsScan = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance.Id AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN) ORDER BY CreatedDate DESC];
        assertResults(testResultsScan, actualResultsScan, 10);

        List<ALM_Application_Result__c> actualResultsButr = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance.Id AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING) ORDER BY CreatedDate DESC];
        assertResults(testResultsButr, actualResultsButr, 10);
    }

    private static testMethod void deletions_multipleTools_singleInstance_customRetention() {
        insert new ALMSettings__c(Sync_History_Retention__c = 30);

        Instances__c testInstance = new Instances__c();
        insert testInstance;

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResultsScan = createApplicationResults(10, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 0, true, true);
        List<ALM_Application_Result__c> testResultsButr = createApplicationResults(10, testInstance.Id, ALMJobServices.ToolType.AUTOMATED_TESTING, SCANServices.SUCCESS_STATUS, now, 0, true, true);
        testResultsScan.addAll(createApplicationResults(10, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 25, true, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResultsScan = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance.Id AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN) ORDER BY CreatedDate DESC];
        assertResults(testResultsScan, actualResultsScan, 15);

        List<ALM_Application_Result__c> actualResultsButr = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance.Id AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING) ORDER BY CreatedDate DESC];
        assertResults(testResultsButr, actualResultsButr, 15);
    }

    private static testMethod void deletions_multipleTools_multipleInstances_defaultRetention() {
        Instances__c testInstance0 = new Instances__c();
        Instances__c testInstance1 = new Instances__c();
        insert new List<Instances__c>{testInstance0, testInstance1};

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResultsInstance0 = createApplicationResults(15, testInstance0.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 0, true, true);
        List<ALM_Application_Result__c> testResultsInstance1 = createApplicationResults(15, testInstance1.Id, ALMJobServices.ToolType.AUTOMATED_TESTING, SCANServices.SUCCESS_STATUS, now, 0, true, true);

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResultsInstance0 = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance0.Id ORDER BY CreatedDate DESC];
        assertResults(testResultsInstance0, actualResultsInstance0, 10);

        List<ALM_Application_Result__c> actualResultsInstance1 = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance1.Id ORDER BY CreatedDate DESC];
        assertResults(testResultsInstance1, actualResultsInstance1, 10);
    }

    private static testMethod void deletions_multipleTools_multipleInstances_customRetention() {
        insert new ALMSettings__c(Sync_History_Retention__c = 1);

        Instances__c testInstance0 = new Instances__c();
        Instances__c testInstance1 = new Instances__c();
        insert new List<Instances__c>{testInstance0, testInstance1};

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResultsScanInstance0 = createApplicationResults(15, testInstance0.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 1, true, true);
        List<ALM_Application_Result__c> testResultsButrInstance0 = createApplicationResults(15, testInstance0.Id, ALMJobServices.ToolType.AUTOMATED_TESTING, SCANServices.SUCCESS_STATUS, now, 1, true, true);
        createApplicationResults(15, testInstance1.Id, ALMJobServices.ToolType.AUTOMATED_TESTING, SCANServices.SUCCESS_STATUS, now, 0, false, true);
        createApplicationResults(5, testInstance1.Id, ALMJobServices.ToolType.AUTOMATED_TESTING, SCANServices.SUCCESS_STATUS, now, 1, true, true);

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResultsScanInstance0 = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance0.Id AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN) ORDER BY CreatedDate DESC];
        assertResults(testResultsScanInstance0, actualResultsScanInstance0, 10);

        List<ALM_Application_Result__c> actualResultsButrInstance0 = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance0.Id AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING) ORDER BY CreatedDate DESC];
        assertResults(testResultsButrInstance0, actualResultsButrInstance0, 10);

        List<ALM_Application_Result__c> actualResultsButrInstance1 = [SELECT CreatedDate FROM ALM_Application_Result__c WHERE Instance__c = :testInstance1.Id AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.AUTOMATED_TESTING) ORDER BY CreatedDate DESC];
        System.assertEquals(15, actualResultsButrInstance1.size(), 'All eligible application BUTR results should be deleted.');
        for (ALM_Application_Result__c actualResult : actualResultsButrInstance1) {
            if (actualResult.CreatedDate > now) {
                System.assert(false, 'No remaining application results should be older than the retention threshold.');
            }
        }
    }

    private static testMethod void deletions_singleTool_singleInstance_queued() {
        Instances__c testInstance = new Instances__c();
        insert testInstance;

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(1, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.TOOL_STATUS_QUEUED, now, 0, false, false));
        testResults.addAll(createApplicationResults(8, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 1, true, true));
        createApplicationResults(1, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.TOOL_STATUS_QUEUED, now, 9, false, false);
        testResults.addAll(createApplicationResults(1, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 10, false, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance.Id AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN) ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, 10);
    }

    private static testMethod void deletions_singleTool_singleInstance_running() {
        Instances__c testInstance = new Instances__c();
        insert testInstance;

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(1, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.TOOL_STATUS_RUNNING, now, 0, false, false));
        testResults.addAll(createApplicationResults(8, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 1, true, true));
        createApplicationResults(1, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.TOOL_STATUS_RUNNING, now, 9, false, false);
        testResults.addAll(createApplicationResults(1, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 10, false, true));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance.Id AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN) ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, 10);
    }

    private static testMethod void deletions_singleTool_singleInstance_queued_stuck() {
        Instances__c testInstance = new Instances__c();
        insert testInstance;

        DateTime now = DateTime.now();
        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(1, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.SUCCESS_STATUS, now, 0, false, true));
        testResults.addAll(createApplicationResults(1, testInstance.Id, ALMJobServices.ToolType.SCAN, SCANServices.TOOL_STATUS_QUEUED, now, 1, true, false));

        Test.startTest();

            Database.executeBatch(new InstanceApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c WHERE Instance__c = :testInstance.Id AND Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN) ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults, 1);
    }
}