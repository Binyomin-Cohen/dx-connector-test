@isTest
private class TestVCRepoSyncApplicationResultCleaner {
    private static List<ALM_Application_Result__c> createApplicationResults(Integer numberOfResults, Id vcRepoId, Id jobId, DateTime now, Integer createdTimeOffset, Boolean distributeCreatedTime) {
        if (now == null) {
            now = DateTime.now();
        }
        if (createdTimeOffset == null) {
            createdTimeOffset = 0;
        }

        if (jobId == null) {
            ALM_Job__c job = new ALM_Job__c(VC_Repo__c = vcRepoId, Tool__c = ALMJobServices.getToolName(ALMJobServices.ToolType.VC_REPO_SYNC));
            insert job;
            jobId = job.Id;
        }

        List<ALM_Application_Result__c> results = new List<ALM_Application_Result__c>();
        for (Integer i = 0; i < numberOfResults; ++i) {
            results.add(new ALM_Application_Result__c(
                ALM_Job__c = jobId,
                Result__c = 'Success'
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

    private static void assertResults(List<ALM_Application_Result__c> testResults, List<ALM_Application_Result__c> actualResults) {
        List<ALM_Application_Result__c> expectedResults = TestingUtils.sortResults(testResults, VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT);
        System.assertEquals(expectedResults.size(), actualResults.size(), 'The proper number of application results should be retained.');
        for (Integer i = 0; i < actualResults.size(); ++i) {
            System.assertEquals(expectedResults[i].Id, actualResults[i].Id, 'The proper application results should be retained.');
        }
    }

    private static testMethod void noDeletions_noRepo_noResults() {
        Test.startTest();

            try {
                Database.executeBatch(new VCRepoSyncApplicationResultCleaner());
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown. Exception: ' + e.getMessage());
            }

        Test.stopTest();
    }

    private static testMethod void noDeletions_noRepo() {
        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        testResults.addAll(createApplicationResults(VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT, null, null, DateTime.now(), 0, true));

        Test.startTest();

            try {
                Database.executeBatch(new VCRepoSyncApplicationResultCleaner());
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown. Exception: ' + e.getMessage());
            }

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults);
    }

    private static testMethod void noDeletions_singleRepo_noResults() {
        VC_Repository__c vcRepo = new VC_Repository__c();
        insert vcRepo;

        Test.startTest();

            try {
                Database.executeBatch(new VCRepoSyncApplicationResultCleaner());
            } catch (Exception e) {
                System.assert(false, 'No exceptions should be thrown. Exception: ' + e.getMessage());
            }

        Test.stopTest();
    }

    private static testMethod void noDeletions_singleRepo_properTool() {
        VC_Repository__c vcRepo = new VC_Repository__c();
        insert vcRepo;

        List<ALM_Application_Result__c> testResults = createApplicationResults(VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT, vcRepo.Id, null, DateTime.now(), 0, true);

        Test.startTest();

            Database.executeBatch(new VCRepoSyncApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults);
    }

    private static testMethod void noDeletions_singleRepo_otherTool() {
        VC_Repository__c vcRepo = new VC_Repository__c();
        insert vcRepo;

        ALM_Application_Result__c testResult = new ALM_Application_Result__c(Tool__c = ALMJobServices.getToolName(ALMJobServices.ToolType.SCAN));
        insert testResult;

        Test.startTest();

            Database.executeBatch(new VCRepoSyncApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(new List<ALM_Application_Result__c>{ testResult }, actualResults);
    }

    private static testMethod void noDeletions_multipleRepos() {
        VC_Repository__c vcRepo0 = new VC_Repository__c();
        VC_Repository__c vcRepo1 = new VC_Repository__c();
        insert new List<VC_Repository__c>{ vcRepo0, vcRepo1 };

        List<ALM_Application_Result__c> testResultsRepo0 = createApplicationResults(VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT, vcRepo0.Id, null, DateTime.now(), 0, true);
        List<ALM_Application_Result__c> testResultsRepo1 = createApplicationResults(VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT, vcRepo1.Id, null, DateTime.now(), 0, true);

        Test.startTest();

            Database.executeBatch(new VCRepoSyncApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResultsRepo0 = [SELECT Id FROM ALM_Application_Result__c WHERE ALM_Job__r.VC_Repo__c = :vcRepo0.Id];
        assertResults(testResultsRepo0, actualResultsRepo0);

        List<ALM_Application_Result__c> actualResultsRepo1 = [SELECT Id FROM ALM_Application_Result__c WHERE ALM_Job__r.VC_Repo__c = :vcRepo1.Id];
        assertResults(testResultsRepo1, actualResultsRepo1);
    }

    private static testMethod void deletions_singleRepo() {
        VC_Repository__c vcRepo = new VC_Repository__c();
        insert vcRepo;

        List<ALM_Application_Result__c> testResults = createApplicationResults(VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT + 5, vcRepo.Id, null, DateTime.now(), 0, true);

        Test.startTest();

            Database.executeBatch(new VCRepoSyncApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults);
    }

    private static testMethod void deletions_singleRepo_multipleJobs() {
        VC_Repository__c vcRepo = new VC_Repository__c();
        insert vcRepo;

        ALM_Job__c job0 = new ALM_Job__c(VC_Repo__c = vcRepo.Id, Tool__c = ALMJobServices.getToolName(ALMJobServices.ToolType.VC_REPO_SYNC));
        ALM_Job__c job1 = new ALM_Job__c(VC_Repo__c = vcRepo.Id, Tool__c = ALMJobServices.getToolName(ALMJobServices.ToolType.VC_REPO_SYNC));
        insert new List<ALM_Job__c>{ job0, job1 };

        List<ALM_Application_Result__c> testResults = new List<ALM_Application_Result__c>();
        DateTime now = DateTime.now();
        testResults.addAll(createApplicationResults(VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT + 5, vcRepo.Id, job0.Id, now, 0, true));
        testResults.addAll(createApplicationResults(VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT + 5, vcRepo.Id, job1.Id, now.addMinutes(1), 0, true));

        Test.startTest();

            Database.executeBatch(new VCRepoSyncApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResults = [SELECT Id FROM ALM_Application_Result__c ORDER BY CreatedDate DESC];
        assertResults(testResults, actualResults);
    }

    private static testMethod void deletions_multipleRepos() {
        VC_Repository__c vcRepo0 = new VC_Repository__c();
        VC_Repository__c vcRepo1 = new VC_Repository__c();
        VC_Repository__c vcRepo2 = new VC_Repository__c();
        insert new List<VC_Repository__c>{ vcRepo0, vcRepo1, vcRepo2 };

        List<ALM_Application_Result__c> testResultsRepo0 = createApplicationResults(VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT + 5, vcRepo0.Id, null, DateTime.now(), 2, true);
        List<ALM_Application_Result__c> testResultsRepo1 = createApplicationResults(VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT, vcRepo1.Id, null, DateTime.now(), 0, true);
        List<ALM_Application_Result__c> testResultsRepo2 = createApplicationResults(VCRepoSyncApplicationResultCleaner.RECORD_RETENTION_COUNT + 5, vcRepo2.Id, null, DateTime.now(), 1, true);

        Test.startTest();

            Database.executeBatch(new VCRepoSyncApplicationResultCleaner());

        Test.stopTest();

        List<ALM_Application_Result__c> actualResultsRepo0 = [SELECT Id FROM ALM_Application_Result__c WHERE ALM_Job__r.VC_Repo__c = :vcRepo0.Id];
        assertResults(testResultsRepo0, actualResultsRepo0);

        List<ALM_Application_Result__c> actualResultsRepo1 = [SELECT Id FROM ALM_Application_Result__c WHERE ALM_Job__r.VC_Repo__c = :vcRepo1.Id];
        assertResults(testResultsRepo1, actualResultsRepo1);

        List<ALM_Application_Result__c> actualResultsRepo2 = [SELECT Id FROM ALM_Application_Result__c WHERE ALM_Job__r.VC_Repo__c = :vcRepo2.Id];
        assertResults(testResultsRepo2, actualResultsRepo2);
    }
}