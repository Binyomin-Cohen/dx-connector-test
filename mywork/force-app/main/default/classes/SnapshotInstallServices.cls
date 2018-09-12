public with sharing class SnapshotInstallServices {
    @TestVisible
    public static String SNAPSHOT_REPORT_DEVELOPER_NAME = 'Sprint_Snapshot';
    @TestVisible
    public static String SNAPSHOT_TARGET_OBJECT_NAME = SObjectServices.getFullyQualifiedName('Burndown_Snapshot__c');

    @TestVisible
    private static Map<String, String> COLUMN_NAME_TO_FIELD_NAME = new Map<String,String>{
        'Backlog Item: Key' => SObjectServices.getFullyQualifiedName('Item_Key__c'),
        'Backlog Item: Status' => SObjectServices.getFullyQualifiedName('Status__c'),
        'Backlog Item: Dev Effort' => SObjectServices.getFullyQualifiedName('Effort__c')
    };

    @TestVisible
    private static list<String> errors = new List<String>();

    public static void createAlmJobSnapshotAndMappings() {
        ALM_Job__c snapshotJob = new ALM_Job__c(Tool__c = ALMJobServices.getToolName(ALMJobServices.ToolType.SNAPSHOT),
                                                Report_Developer_Name__c = SNAPSHOT_REPORT_DEVELOPER_NAME,
                                                Target_Object_Api_Name__c = SNAPSHOT_TARGET_OBJECT_NAME);

        try {
            insert snapshotJob;
        } catch (DMLException dex) {
            errors.add(dex.getMessage());
        }
        if (errors.isEmpty()) {
            List<Snapshot_Field_Mapping__c> mappingsToInsert = new List<Snapshot_Field_Mapping__c>();

            for (String column : COLUMN_NAME_TO_FIELD_NAME.keySet()) {
                String field = COLUMN_NAME_TO_FIELD_NAME.get(column);

                Snapshot_Field_Mapping__c mapping = new Snapshot_Field_Mapping__c(ALM_Job__c = snapshotJob.Id,
                                                                          Report_Column__c = column,
                                                                          Target_Field_Api_Name__c = field);
                mappingsToInsert.add(mapping);
            }

            try {
                insert mappingsToInsert;
            } catch (DMLException dex) {
                errors.add(dex.getMessage());
            }
        }
        if (!errors.isEmpty()) {
            String body = String.join(errors, '\n');

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] mailTo = new String[] {'productdev@bluewolfgroup.com'};
            mail.setToAddresses(mailTo);
            mail.setSubject('Errors occurred during the snapshot post install process');
            mail.setPlainTextBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
        }
    }
}