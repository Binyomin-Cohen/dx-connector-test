@isTest(SeeAllData=true)
private class TestSnapshotServicesWithReports {
	private static final String TEST_REPORT_TABULAR_DEVELOPER_NAME = 'Report_For_Unit_Test_Snapshots';
    private static final String TEST_REPORT_SUMMARY_DEVELOPER_NAME = 'Report_For_Unit_Test_Jobs_With_Snapshot';
    private static final String TEST_REPORT_FOLDER_NAME = 'Bluewolf Sightline';
    private static final String TEST_REPORT_COLUMN_NAME = 'Test Report Column Name';
    private static final String SNAPSHOT_TOOL_NAME = ALMJobServices.getToolName(ALMJobServices.ToolType.SNAPSHOT);

    private static Report testTabularReport {
        get {
            if (testTabularReport == null) {
                testTabularReport = [SELECT Id, DeveloperName FROM Report WHERE DeveloperName = :TEST_REPORT_TABULAR_DEVELOPER_NAME AND folderName = :TEST_REPORT_FOLDER_NAME LIMIT 1];
            }
            return testTabularReport;
        } set;
    }

    private static Report testSummaryReport {
        get {
            if(testSummaryReport == null){
                testSummaryReport = [SELECT Id, DeveloperName FROM Report WHERE DeveloperName = :TEST_REPORT_SUMMARY_DEVELOPER_NAME AND folderName = :TEST_REPORT_FOLDER_NAME LIMIT 1];
            }
            return testSummaryReport;
        } set;
    }

    static UnitTest.DataGenerator snapshotMappings = new TestingUtils.SnapshotMappingDG();

	static Reports.ReportResults setupAndRunReport(){
        Reports.ReportMetadata reportMetadata = Reports.ReportManager.describeReport(testSummaryReport.Id).getReportMetadata();

        //Add a filter for the IDs of the alm jobs created in this unit test
        //Because running reports in unit tests disrespects see all data.
        List<Reports.ReportFilter> filters = new List<Reports.ReportFilter>();
        Reports.ReportFilter newFilter = new Reports.ReportFilter();
        newFilter.setColumn(SObjectServices.getFullyQualifiedName('ALM_Job__c.Id'));
        newFilter.setOperator('equals');
        newFilter.setValue(String.join(new List<Id>(UnitTest.getIds('All ALM_Jobs')), ','));
        filters.add(newFilter);
        reportMetadata.setReportFilters(filters);

        //Add another field to the report
        List<String> currentColumns = reportMetadata.getDetailColumns();
        currentColumns.add(SObjectServices.getFullyQualifiedName('Snapshot_Field_Mapping__c') + '.' + SObjectServices.getFullyQualifiedName('Target_Field_Api_Name__c'));
        reportMetadata.setDetailColumns(currentColumns);

        //Set the sort column
        Reports.SortColumn sortingCol = new Reports.SortColumn();
        sortingCol.setSortColumn(SObjectServices.getFullyQualifiedName('Snapshot_Field_Mapping__c.Name'));
        sortingCol.setSortOrder(Reports.ColumnSortOrder.ASCENDING);
        reportMetadata.setSortBy(new List<Reports.SortColumn>{sortingCol});

        return Reports.ReportManager.runReport(testSummaryReport.Id,reportMetadata,true);
    }

    private static Reports.ReportResults runReport(Id reportId) {
        Reports.ReportMetadata metadata = Reports.ReportManager.describeReport(reportId).getReportMetadata();
        metadata.setReportFilters(new List<Reports.ReportFilter>{new Reports.ReportFilter(
            SObjectServices.getFullyQualifiedName('Snapshot_Field_Mapping__c') + '.' + SObjectServices.getFullyQualifiedName('Report_Column__c'),
            'equals',
            TEST_REPORT_COLUMN_NAME
        )});

        return Reports.ReportManager.runReport(reportId, metadata, true);
    }

	@isTest(SeeAllData='true')
    static void testOrganizeReportResultsFactMap() {

        final String SNAPSHOT_NAME_FIELD_LABEL = 'Snapshot Field Mapping Name';
        final String SNAPSHOT_TARGET_FIELD_LABEL = 'Target Field Api Name';

        final Integer NUM_JOB_RECORDS = 2;
        final Integer NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB = 3;

        List<ALM_Job__c>almJobsToInsert = new List<ALM_Job__c>();
        for(Integer i = 0; i < NUM_JOB_RECORDS; i++){
            almJobsToInsert.add(new ALM_Job__c(Tool__c = SNAPSHOT_TOOL_NAME));
        }

        UnitTest.addData( almJobsToInsert ).tag('All ALM_Jobs');

        UnitTest.get('All ALM_Jobs').insertAll();

        UnitTest.forEach('All ALM_Jobs')
                .create(NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB, snapshotMappings)
                .copyProperty('ID->' + SObjectServices.getFullyQualifiedName('ALM_Job__c'))
                .tag('All Snapshot Mappings');

        UnitTest.get('All Snapshot Mappings').insertAll();

        Reports.ReportResults result = setupAndRunReport();

        Test.startTest();
            List<Map<String, String>> reportMappedResults = SnapshotServices.organizeReportResultsFactMap(result, '0_0');
            reportMappedResults.addAll(SnapshotServices.organizeReportResultsFactMap(result, '1_0'));
        Test.stopTest();

        System.assertEquals( NUM_JOB_RECORDS * NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB, reportMappedResults.size(), 'The correct number of records should be parsed');

        Set<String> insertedFieldMappingNames = new Set<String>();
        Set<String> actualParsedFieldMappingNames = new Set<String>();

        for(Snapshot_Field_Mapping__c testMapping : [SELECT Name FROM Snapshot_Field_Mapping__c WHERE Id in : UnitTest.getIds('All Snapshot Mappings')]){
            insertedFieldMappingNames.add(testMapping.Name);
        }

        for(Map<String, String> cell : reportMappedResults){
            System.assert(cell.containsKey(SNAPSHOT_NAME_FIELD_LABEL), 'The name field should be present on each cell');
            actualParsedFieldMappingNames.add(cell.get(SNAPSHOT_NAME_FIELD_LABEL));

            System.assert(cell.containsKey(SNAPSHOT_TARGET_FIELD_LABEL), 'The target field should be present on each cell');
            System.assertEquals( null, cell.get(SNAPSHOT_TARGET_FIELD_LABEL), 'The target field should be null since it was not populated' );
        }
        System.assertEquals(insertedFieldMappingNames, actualParsedFieldMappingNames, 'The correct snapshot records should be parsed');
    }

    @isTest(SeeAllData='true')
    static void testMapGroupingLevelToGroupingLabel() {

        Test.startTest();
            Map<Integer, String> groupingLevelToGroupingLabel = SnapshotServices.mapGroupingLevelToGroupingLabel(Reports.ReportManager.describeReport(testSummaryReport.Id).getReportExtendedMetadata());
        Test.stopTest();
        System.assertEquals(2, groupingLevelToGroupingLabel.size(), 'The correct number of groupings should be detected');

        System.assertEquals('ALM Job Name', groupingLevelToGroupingLabel.get(0), 'The correct grouping should be detected at level 1');
        System.assertEquals('Tool', groupingLevelToGroupingLabel.get(1), 'The correct grouping should be detected at level 2');

    }

	@isTest(SeeAllData='true')
    static void testMapGroupingKeyToGroupingValue() {

        final String SNAPSHOT_NAME_FIELD_LABEL = 'Snapshot Field Mapping Name';
        final String SNAPSHOT_TARGET_FIELD_LABEL = 'Target Field Api Name';

        final Integer NUM_JOB_RECORDS = 2;
        final Integer NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB = 3;

        List<ALM_Job__c>almJobsToInsert = new List<ALM_Job__c>();
        for(Integer i = 0; i < NUM_JOB_RECORDS; i++){
            almJobsToInsert.add(new ALM_Job__c(Tool__c = SNAPSHOT_TOOL_NAME));
        }

        UnitTest.addData( almJobsToInsert ).tag('All ALM_Jobs');

        UnitTest.get('All ALM_Jobs').insertAll();

        UnitTest.forEach('All ALM_Jobs')
                .create(NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB, snapshotMappings)
                .copyProperty('ID->' + SObjectServices.getFullyQualifiedName('ALM_Job__c'))
                .tag('All Snapshot Mappings');

        UnitTest.get('All Snapshot Mappings').insertAll();

        Reports.ReportResults result = setupAndRunReport();

        Test.startTest();
             Map<String, String> groupingKeyToGroupingValue = SnapshotServices.mapGroupingKeyToGroupingValue(new Map<String, String>(), result.getGroupingsDown().getGroupings());
        Test.stopTest();

        System.assertEquals(4, groupingKeyToGroupingValue.size(), 'The correct number of grouping labels should be detected');

        List<ALM_Job__c> testSnapshots = [SELECT
                                                    Id, Name, Target_Object_Api_Name__c, Errors__c
                                                  FROM ALM_Job__c
                                                  WHERE Id in :UnitTest.getIds('All ALM_Jobs')
                                                  ORDER BY Name ASC];

        System.assertEquals(testSnapshots[0].Name, groupingKeyToGroupingValue.get('0'), 'The correct grouping label should be detected');
        System.assertEquals(testSnapshots[1].Name, groupingKeyToGroupingValue.get('1'), 'The correct grouping label should be detected');
        System.assertEquals(SNAPSHOT_TOOL_NAME, groupingKeyToGroupingValue.get('0_0'), 'The correct grouping label should be detected');
        System.assertEquals(SNAPSHOT_TOOL_NAME, groupingKeyToGroupingValue.get('1_0'), 'The correct grouping label should be detected');
    }

	@isTest(SeeAllData=true)
    private static void organizeReportResults_tabular() {
        System.assertEquals(Reports.ReportFormat.TABULAR, Reports.ReportManager.describeReport(testTabularReport.Id).getReportMetadata().getReportFormat(), 'The report should be in a tabular format.');

        final Integer numberOfMappings = 3;

        ALM_Job__c testJob = TestingUtils.createSnapshotALMJob(ALMJobServices.ToolType.SNAPSHOT, 'Scheduled', SObjectServices.getFullyQualifiedName('ALM_Job__c'), TEST_REPORT_TABULAR_DEVELOPER_NAME);

        List<Snapshot_Field_Mapping__c> testMappings = new List<Snapshot_Field_Mapping__c>();
        for (Integer i = 0; i < numberOfMappings; ++i) {
            testMappings.add(TestingUtils.createSnapshotMapping(testJob.Id, TEST_REPORT_COLUMN_NAME));
        }

        Set<Id> testMappingIds = new Set<Id>();
        for (Snapshot_Field_Mapping__c testMapping : testMappings) {
            testMappingIds.add(testMapping.Id);
        }

        Reports.ReportResults reportRunResults = runReport(testTabularReport.Id);

        Test.startTest();

            List<Map<String, String>> organizedResults = SnapshotServices.organizeReportResults(reportRunResults);

        Test.stopTest();

        Map<String, String> snapshotNameToReportColumn = new Map<String, String>();
        for (Map<String, String> organizedResultMap : organizedResults) {
            snapshotNameToReportColumn.put(organizedResultMap.get('Snapshot Field Mapping Name'), organizedResultMap.get('Report Column'));
        }

        List<Snapshot_Field_Mapping__c> refreshedMappings = [SELECT Name, Report_Column__c FROM Snapshot_Field_Mapping__c WHERE Id IN :testMappingIds];
        Map<String, String> refreshedMappingNameToRefreshedMappingReportColumn = new Map<String, String>();
        for (Snapshot_Field_Mapping__c refreshedMapping : refreshedMappings) {
            refreshedMappingNameToRefreshedMappingReportColumn.put(refreshedMapping.Name, refreshedMapping.Report_Column__c);
        }

        System.assertEquals(numberOfMappings, snapshotNameToReportColumn.keySet().size(), 'The proper number of snapshot record results should exist.');

        for (String refreshedMappingName : refreshedMappingNameToRefreshedMappingReportColumn.keySet()) {
            System.assertEquals(refreshedMappingNameToRefreshedMappingReportColumn.get(refreshedMappingName), snapshotNameToReportColumn.get(refreshedMappingName), 'The snapshot report columns should match.');
        }
    }

/* TODO:
        this is commented out due to salesforce issue that we have a case open for causing 
            'System.UnexpectedException: Error processing messages' errors

    @isTest(SeeAllData=true)
    private static void organizeReportResults_summary() {
        System.assertEquals(Reports.ReportFormat.SUMMARY, Reports.ReportManager.describeReport(testSummaryReport.Id).getReportMetadata().getReportFormat(), 'The report should be in a summary format.');

        List<ALM_Job__c> testJobs = new List<ALM_Job__c>();
        testJobs.add(TestingUtils.createSnapshotALMJob(ALMJobServices.ToolType.SNAPSHOT, 'Scheduled', SObjectServices.getFullyQualifiedName('ALM_Job__c'), TEST_REPORT_SUMMARY_DEVELOPER_NAME));
        testJobs.add(TestingUtils.createSnapshotALMJob(ALMJobServices.ToolType.SNAPSHOT, 'On Hold', SObjectServices.getFullyQualifiedName('ALM_Job__c'), null));

        Set<Id> testJobIds = new Set<Id>();
        for (ALM_Job__c testJob : testJobs) {
            testJobIds.add(testJob.Id);
        }

        List<Snapshot_Field_Mapping__c> testMappings = new List<Snapshot_Field_Mapping__c>();
        testMappings.add(TestingUtils.createSnapshotMapping(testJobs[0].Id, TEST_REPORT_COLUMN_NAME));
        testMappings.add(TestingUtils.createSnapshotMapping(testJobs[0].Id, TEST_REPORT_COLUMN_NAME));
        testMappings.add(TestingUtils.createSnapshotMapping(testJobs[1].Id, TEST_REPORT_COLUMN_NAME));

        Set<Id> testMappingIds = new Set<Id>();
        for (Snapshot_Field_Mapping__c testMapping : testMappings) {
            testMappingIds.add(testMapping.Id);
        }

        Reports.ReportResults reportRunResults = runReport(testSummaryReport.Id);

        Test.startTest();

            List<Map<String, String>> organizedResults = SnapshotServices.organizeReportResults(reportRunResults);

        Test.stopTest();

        Map<String, Set<String>> jobNameToSnapshotNames = new Map<String, Set<String>>();
        for (Map<String, String> organizedResultMap : organizedResults) {
            if (jobNameToSnapshotNames.get(organizedResultMap.get('ALM Job Name')) == null) {
                jobNameToSnapshotNames.put(organizedResultMap.get('ALM Job Name'), new Set<String>());
            }

            jobNameToSnapshotNames.get(organizedResultMap.get('ALM Job Name')).add(organizedResultMap.get('Snapshot Field Mapping Name'));
        }
        List<ALM_Job__c> refreshedJobs = [SELECT Name FROM ALM_Job__c WHERE Id IN :testJobIds];
        List<Snapshot_Field_Mapping__c> refreshedMappings = [SELECT Name FROM Snapshot_Field_Mapping__c WHERE Id IN :testMappingIds];

        System.assertEquals(2, jobNameToSnapshotNames.get(refreshedJobs[0].Name).size(), 'The first job should be associated with two snapshots.');
        System.assert(jobNameToSnapshotNames.get(refreshedJobs[0].Name).contains(refreshedMappings[0].Name), 'The first job should be associated with the proper snapshots.');
        System.assert(jobNameToSnapshotNames.get(refreshedJobs[0].Name).contains(refreshedMappings[1].Name), 'The first job should be associated with the proper snapshots.');
        System.assertEquals(1, jobNameToSnapshotNames.get(refreshedJobs[1].Name).size(), 'The second job should be associated with one snapshot.');
        System.assert(jobNameToSnapshotNames.get(refreshedJobs[1].Name).contains(refreshedMappings[2].Name), 'The first job should be associated with the proper snapshots.');
    }
*/

    @isTest(SeeAllData=true)
    private static void organizeReportResults_summary_bulk_groupings() {
        final Integer NUM_JOB_RECORDS = 20;
        final Integer NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB = 3;

        List<ALM_Job__c>almJobsToInsert = new List<ALM_Job__c>();
        for(Integer i = 0; i < NUM_JOB_RECORDS; i++){
            almJobsToInsert.add(new ALM_Job__c(Tool__c = SNAPSHOT_TOOL_NAME));
        }

        UnitTest.addData( almJobsToInsert ).tag('All ALM_Jobs');

        UnitTest.get('All ALM_Jobs').insertAll();

        UnitTest.forEach('All ALM_Jobs')
                .create(NUM_SNAPSHOT_MAPPING_RECORDS_PER_JOB, snapshotMappings)
                .copyProperty('ID->' + SObjectServices.getFullyQualifiedName('ALM_Job__c'))
                .tag('All Snapshot Mappings');

        UnitTest.get('All Snapshot Mappings').insertAll();

        Reports.ReportResults reportRunResults = setupAndRunReport();

        Test.startTest();

            List<Map<String, String>> organizedResults = SnapshotServices.organizeReportResults(reportRunResults);

        Test.stopTest();
        List<Snapshot_Field_Mapping__c> actualMappings = [SELECT Id, Name, Alm_Job__r.Name FROM Snapshot_Field_Mapping__c WHERE Id in :UnitTest.getIds('All Snapshot Mappings')];
        Map<String, List<Snapshot_Field_Mapping__c>> snapshotMappingsGroupedByAlmJobName = Groupby.strings('Alm_Job__r.Name', actualMappings);

        final String JOB_NAME_COL = 'ALM Job Name';
        Set<String> returnedJobNames = new Set<String>();

        for (Map<String, String> cell : organizedResults) {
            returnedJobNames.add(cell.get(JOB_NAME_COL));
        }
        System.assertEquals(snapshotMappingsGroupedByAlmJobName.keySet(), returnedJobNames, 'All groupings should be detected');
    }
}