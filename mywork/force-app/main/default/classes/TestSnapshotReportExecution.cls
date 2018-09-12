@isTest
private class TestSnapshotReportExecution {
    private static final String TEST_REPORT_DEVELOPER_NAME = 'Report_For_Unit_Test_Jobs_With_Snapshot';
    private static String ORG_ID = UserInfo.getOrganizationId();
    
    private static User testUser;

    private static void setupUser() {
        Integer uniqueRandomInteger = Integer.valueOf(Math.rint(Math.random()*1000000));
        String timeBasedIndentifier = String.valueOf(Datetime.now().getTime());
        testUser = TestingUtils.buildUser([SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id, timeBasedIndentifier + uniqueRandomInteger +'@'+ORG_ID+'.com');
        insert testUser;

        PermissionSet permissions = TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET;
        PermissionSetAssignment assignment = new PermissionSetAssignment(PermissionSetId = permissions.Id, AssigneeId = testUser.Id);
        insert assignment;
    }

    private static ALM_Job__c refreshJob(Id jobId) {
        return [SELECT Name, Tool__c, Last_Successful_Run__c, Errors__c, Last_Run_Time__c FROM ALM_Job__c WHERE Id = :jobId];
    }

    private static testMethod void execute_error_noSnapshotJob_cannotInsertMappings() {
        System.runAs(TestingUtils.ADMIN_USER) {
            setupUser();

            ALM_Job__c testJob = TestingUtils.createSnapshotALMJob('Some Other Tool', 'Scheduled', SObjectServices.getFullyQualifiedName('ALM_Job__c'), TEST_REPORT_DEVELOPER_NAME);

            Test.startTest();

                try {
                    TestingUtils.createSnapshotMapping(testJob.Id, 'ALM Job Name', SObjectServices.getFullyQualifiedName('Components__c'));

                    System.assert(false, 'A DMLException should be thrown when trying to map to a job of the wrong tool type.');
                } catch (DMLException e) {}

            Test.stopTest();
        }
    }

    private static testMethod void execute_error_thrownExceptionWrongReportFormat() {
        System.runAs(TestingUtils.ADMIN_USER) {
            setupUser();

            final String MOCK_REPORT_DEV_NAME = 'mockReport';

            ALM_Job__c testJob = TestingUtils.createSnapshotALMJob(ALMJobServices.ToolType.SNAPSHOT, 'Scheduled', SObjectServices.getFullyQualifiedName('ALM_Job__c'), MOCK_REPORT_DEV_NAME);

            List<Snapshot_Field_Mapping__c> testMappings = new List<Snapshot_Field_Mapping__c>();
            testMappings.add(TestingUtils.createSnapshotMapping(testJob.Id, 'ALM Job Name', SObjectServices.getFullyQualifiedName('Components__c')));
            testMappings.add(TestingUtils.createSnapshotMapping(testJob.Id, 'Tool', SObjectServices.getFullyQualifiedName('Warnings__c')));
            testMappings.add(TestingUtils.createSnapshotMapping(testJob.Id, 'Snapshot Field Mapping Name', SObjectServices.getFullyQualifiedName('Errors__c')));

            String reportInstanceJsonString = '{"reportResults":{"reportMetadata":{"reportFormat":"MATRIX","developerName":"'+MOCK_REPORT_DEV_NAME+'"}}}';
            Reports.ReportInstance reportRunResultsInstance = (Reports.ReportInstance)JSON.deserialize(reportInstanceJsonString, Reports.ReportInstance.class);
            DateTime expectedRunTime = SnapshotServices.nowTime;
            Test.startTest();

                try{
                    new SnapshotReportExecution().execute(
                        new Reports.NotificationActionContext(
                            reportRunResultsInstance,
                            new Reports.ThresholdInformation(new List<Reports.EvaluatedCondition>())
                        )
                    );
                }catch(Exception ex){
                    System.assert(false, 'We should not receive any exceptions');
                }
            Test.stopTest();

            ALM_Job__c refreshedJob = refreshJob(testJob.Id);

            System.assertEquals(null, refreshedJob.Last_Successful_Run__c, 'The succesfull timestamp should be empty');
            System.assertEquals(expectedRunTime, refreshedJob.Last_Run_Time__c, 'The last run timestamp should not be set correctly');
            System.assertNotEquals(null, refreshedJob.Errors__c, 'The error message should not be empty');
            System.assert(refreshedJob.Errors__c.contains(System.Label.Error_Report_Format), 'The error message should contain the correct message');
        }
    }
}