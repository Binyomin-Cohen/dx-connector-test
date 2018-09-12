@isTest
private class TestSnapshotInstallServices {

    static testMethod void createAlmJobSnapshotAndMappings_success() {
        Integer emailsSent = Limits.getEmailInvocations();

        Test.startTest();
            SnapshotInstallServices.createAlmJobSnapshotAndMappings();
        Test.stopTest();

        List<ALM_Job__c> snapshots = [
            SELECT
                Id, Target_Object_Api_Name__c, Tool__c, Report_Developer_Name__c, Errors__c,
                (SELECT Id, ALM_Job__c, Report_Column__c, Target_Field_Api_Name__c FROM Snapshot_Field_Mappings__r)
            FROM ALM_Job__c
        ];
        System.assertEquals(0, SnapshotInstallServices.errors.size(), 'No error strings should have been created');
        System.assertEquals(emailsSent, Limits.getEmailInvocations(), 'No emails should have been sent since we do not expect any errors');
        System.assertEquals(1, snapshots.size(), 'One snapshot record should have been created');
        ALM_Job__c snapshotCreated = snapshots[0];
        System.assertEquals(ALMJobServices.getToolName(ALMJobServices.ToolType.SNAPSHOT), snapshotCreated.Tool__c,'The tool should be correctly set');
        System.assertEquals(SnapshotInstallServices.SNAPSHOT_REPORT_DEVELOPER_NAME, snapshotCreated.Report_Developer_Name__c,'The report should be correctly set');
        System.assertEquals(SnapshotInstallServices.SNAPSHOT_TARGET_OBJECT_NAME, snapshotCreated.Target_Object_Api_Name__c,'The target should be correctly set');
        System.assertEquals(SnapshotInstallServices.COLUMN_NAME_TO_FIELD_NAME.size(), snapshotCreated.Snapshot_Field_Mappings__r.size(),'The correct number of field mappings should be created');

        Map<String, List<Snapshot_Field_Mapping__c>> mappingsGroupedByColumnName = Groupby.Strings(Snapshot_Field_Mapping__c.Report_Column__c, snapshotCreated.Snapshot_Field_Mappings__r);
        System.assertEquals(SnapshotInstallServices.COLUMN_NAME_TO_FIELD_NAME.size(), mappingsGroupedByColumnName.size(),'The correct number of groupings should exist');

        for (String column : SnapshotInstallServices.COLUMN_NAME_TO_FIELD_NAME.keySet()) {
            String target = SnapshotInstallServices.COLUMN_NAME_TO_FIELD_NAME.get(column);
            System.assert( mappingsGroupedByColumnName.containsKey(column), 'The column '+column+' should exist in the list of mappings');
            System.assertEquals( target, mappingsGroupedByColumnName.get(column)[0].Target_Field_Api_Name__c, 'The target '+target+' should be correctly mapped to the column ' + column);
        }

    }
}