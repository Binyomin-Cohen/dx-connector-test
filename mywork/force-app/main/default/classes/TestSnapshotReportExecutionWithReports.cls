@isTest(SeeAllData=true)
private class TestSnapshotReportExecutionWithReports {
	private static final String TEST_REPORT_DEVELOPER_NAME = 'Report_For_Unit_Test_Jobs_With_Snapshot';
    private static final String TEST_REPORT_FOLDER_NAME = 'Bluewolf Sightline';
    private static String ORG_ID = UserInfo.getOrganizationId();
    private static User testUser;

	private static Report testReport {
        get{
            if (testReport == null) {
                testReport = [SELECT Id, DeveloperName FROM Report WHERE DeveloperName = :TEST_REPORT_DEVELOPER_NAME AND folderName = :TEST_REPORT_FOLDER_NAME LIMIT 1];
            }
            return testReport;
        } set;
    }

    private static void setupUser() {
        Integer uniqueRandomInteger = Integer.valueOf(Math.rint(Math.random()*1000000));
        String timeBasedIndentifier = String.valueOf(Datetime.now().getTime());
        testUser = TestingUtils.buildUser([SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id, timeBasedIndentifier + uniqueRandomInteger +'@'+ORG_ID+'.com');
        insert testUser;

        PermissionSet permissions = TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET;
        PermissionSetAssignment assignment = new PermissionSetAssignment(PermissionSetId = permissions.Id, AssigneeId = testUser.Id);
        insert assignment;
    }

    private static void runReportAndExecuteSnapshot(ALM_Job__c job) {
        System.runAs(testUser) {
            Reports.ReportMetadata metadata = Reports.ReportManager.describeReport(testReport.Id).getReportMetadata();
            metadata.setReportFilters(new List<Reports.ReportFilter>{new Reports.ReportFilter(
                SObjectServices.getFullyQualifiedName('ALM_Job__c.Id'),
                'equals',
                job.Id
            )});

            Test.startTest();

                Reports.ReportInstance instance = Reports.ReportManager.runAsyncReport(testReport.Id, metadata, true);

            Test.stopTest();

            new SnapshotReportExecution().execute(
                new Reports.NotificationActionContext(
                    instance,
                    new Reports.ThresholdInformation(new List<Reports.EvaluatedCondition>())
                )
            );
        }
    }

    private static ALM_Job__c refreshJob(Id jobId) {
        return [SELECT Name, Tool__c, Last_Successful_Run__c, Errors__c, Last_Run_Time__c FROM ALM_Job__c WHERE Id = :jobId];
    }

    private static List<ALM_Job__c> retrieveNewTargetRecords() {
        return [
            SELECT Components__c, Warnings__c, Errors__c
            FROM ALM_Job__c
            WHERE CreatedById = :testUser.Id
        ];
    }

    private static void assertNoSnapshot(ALM_Job__c job) {
        ALM_Job__c refreshedJob = refreshJob(job.Id);
        List<ALM_Job__c> newTargetRecords = retrieveNewTargetRecords();

        System.assertEquals(0, newTargetRecords.size(), 'No new target records should be created.');
        System.assert(String.isBlank(refreshedJob.Errors__c), 'The job\'s errors should be blank.');
        System.assertEquals(null, refreshedJob.Last_Run_Time__c, 'The job\'s last run time should not be updated.');
    }

/* TODO: 
        this is commented out due to salesforce issue that we have a case open for causing 
            'System.UnexpectedException: Error processing messages' errors
	private static testMethod void execute_success() {
        System.runAs(TestingUtils.ADMIN_USER) {
            setupUser();

            ALM_Job__c testJob = TestingUtils.createSnapshotALMJob(ALMJobServices.ToolType.SNAPSHOT, 'Scheduled', SObjectServices.getFullyQualifiedName('ALM_Job__c'), TEST_REPORT_DEVELOPER_NAME);

            executeSuccessAndAssert(testJob);
        }
    }


    private static testMethod void execute_success_clearOutPriorErrors() {
        System.runAs(TestingUtils.ADMIN_USER) {
            setupUser();
            String errors = 'Some fake errors';
            ALM_Job__c testJob = TestingUtils.createSnapshotALMJob(ALMJobServices.ToolType.SNAPSHOT, 'Scheduled', SObjectServices.getFullyQualifiedName('ALM_Job__c'), TEST_REPORT_DEVELOPER_NAME, errors);

            executeSuccessAndAssert(testJob);
        }
    }
*/
    
    private static void executeSuccessAndAssert(ALM_Job__c testJob) {
        List<Snapshot_Field_Mapping__c> testMappings = new List<Snapshot_Field_Mapping__c>();
        testMappings.add(TestingUtils.createSnapshotMapping(testJob.Id, 'ALM Job Name', SObjectServices.getFullyQualifiedName('Components__c')));
        testMappings.add(TestingUtils.createSnapshotMapping(testJob.Id, 'Tool', SObjectServices.getFullyQualifiedName('Warnings__c')));
        testMappings.add(TestingUtils.createSnapshotMapping(testJob.Id, 'Snapshot Field Mapping Name', SObjectServices.getFullyQualifiedName('Errors__c')));

        runReportAndExecuteSnapshot(testJob);

        ALM_Job__c refreshedJob = refreshJob(testJob.Id);
        List<ALM_Job__c> newTargetRecords = retrieveNewTargetRecords();

        Set<Id> testMappingIds = new Set<Id>();
        for (Snapshot_Field_Mapping__c mapping : testMappings) {
            testMappingIds.add(mapping.Id);
        }
        List<Snapshot_Field_Mapping__c> refreshedMappings = [SELECT Name FROM Snapshot_Field_Mapping__c WHERE Id IN :testMappingIds];
        System.assertEquals(3, newTargetRecords.size(), 'Three new target records should be created.');

        System.assertEquals(refreshedJob.Name, newTargetRecords[0].Components__c, 'The target record\'s name mapping should match.');
        System.assertEquals(refreshedJob.Name, newTargetRecords[1].Components__c, 'The target record\'s name mapping should match.');
        System.assertEquals(refreshedJob.Name, newTargetRecords[2].Components__c, 'The target record\'s name mapping should match.');

        System.assertEquals(refreshedJob.Tool__c, newTargetRecords[0].Warnings__c, 'The target record\'s tool mapping should match.');
        System.assertEquals(refreshedJob.Tool__c, newTargetRecords[1].Warnings__c, 'The target record\'s tool mapping should match.');
        System.assertEquals(refreshedJob.Tool__c, newTargetRecords[2].Warnings__c, 'The target record\'s tool mapping should match.');
            
        Set<String> mappingNames = new Set<String>();
        for (Snapshot_Field_Mapping__c mapping : refreshedMappings) {
            mappingNames.add(mapping.Name);
        }
        for (ALM_Job__c newTargetRecord : newTargetRecords) {
            System.assert(mappingNames.contains(newTargetRecord.Errors__c), 'The target record\'s snapshot field name mapping should match.');
            mappingNames.remove(newTargetRecord.Errors__c);
        }
        System.assert(mappingNames.isEmpty(), 'All target record snapshot field name mappings should match.');
        
        System.assert(String.isBlank(refreshedJob.Errors__c), 'The job\'s errors should be blank.');
        System.assertNotEquals(null, refreshedJob.Last_Run_Time__c, 'The job\'s last run time should be updated.');
    }
/* TODO: 
        this is commented out due to salesforce issue that we have a case open for causing 
            'System.UnexpectedException: Error processing messages' errors


	private static testMethod void execute_error_noSnapshotJob_doesNotExecute() {
        System.runAs(TestingUtils.ADMIN_USER) {
            setupUser();

            ALM_Job__c testJob = TestingUtils.createSnapshotALMJob('Some Other Tool', 'Scheduled', SObjectServices.getFullyQualifiedName('ALM_Job__c'), TEST_REPORT_DEVELOPER_NAME);

            runReportAndExecuteSnapshot(testJob);

            assertNoSnapshot(testJob);
        }
    }

    private static testMethod void execute_error_noMappings() {
        System.runAs(TestingUtils.ADMIN_USER) {
            setupUser();

            ALM_Job__c testJob = TestingUtils.createSnapshotALMJob(ALMJobServices.ToolType.SNAPSHOT, 'Scheduled', SObjectServices.getFullyQualifiedName('ALM_Job__c'), TEST_REPORT_DEVELOPER_NAME);

            runReportAndExecuteSnapshot(testJob);

            assertNoSnapshot(testJob);
        }
    }
*/
}