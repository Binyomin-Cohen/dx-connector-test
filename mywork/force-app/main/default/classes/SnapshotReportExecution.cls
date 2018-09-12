public with sharing class SnapshotReportExecution implements Reports.NotificationAction{

    public void execute(Reports.NotificationActionContext context) {
        Reports.ReportResults results = context.getReportInstance().getReportResults();

        //Find the alm job based on the report Id, this will allow us to determine
        //the mapping into the target object.
        //if there is no mapping, then we will not proceed.
        List<ALM_Job__c> snapshots = [
            SELECT
                Id, Target_Object_Api_Name__c, Errors__c,
                (SELECT Id, ALM_Job__c, Report_Column__c, Target_Field_Api_Name__c FROM Snapshot_Field_Mappings__r)
            FROM ALM_Job__c
            WHERE Tool__c = :ALMJobServices.getToolName(ALMJobServices.ToolType.SNAPSHOT)
            AND Report_Developer_Name__c = :results.getReportMetadata().getDeveloperName()
            LIMIT 1
        ];

        if (snapshots.isEmpty()
        || snapshots[0].Snapshot_Field_Mappings__r == null
        || snapshots[0].Snapshot_Field_Mappings__r.isEmpty()) {
            return;
        }

        ALM_Job__c snapshot = snapshots[0];
        String errors = '';

        try{
            List<Map<String, String>> reportFlattenedData = SnapshotServices.organizeReportResults(results);

            List<SObject> targetObjectsToInsert = SnapshotServices.mapReportResultsIntoTargetObject(reportFlattenedData, snapshot);

            errors = SnapshotServices.insertRecords(targetObjectsToInsert);
        }catch(Exception ex){
            errors = 'Error occurred at : ' + SnapshotServices.nowTime.format()
                                            + SnapshotServices.ERROR_LINE_SEPARATOR
                                            + ex.getMessage();
        }

        if (String.IsNotBlank(errors)) {
            snapshot.Errors__c = errors.abbreviate(ALM_Job__c.Errors__c.getDescribe().getLength());
        } else{
            snapshot.Last_Successful_Run__c = SnapshotServices.nowTime;
            snapshot.Errors__c = '';
        }
        snapshot.Last_Run_Time__c = SnapshotServices.nowTime;

        try {
            update snapshot;
        } catch (Exception e) {
            System.debug(e.getMessage());
        }
    }
}