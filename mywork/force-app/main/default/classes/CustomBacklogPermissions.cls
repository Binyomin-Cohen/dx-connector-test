public with sharing class CustomBacklogPermissions implements ApplicationPermissions {
    public static final Map<String, Schema.DescribeSObjectResult> OBJECTS_TO_DESCRIBE = new Map<String, Schema.DescribeSObjectResult> {
        SObjectServices.getFullyQualifiedName('Custom_Backlog__c') => Custom_Backlog__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Backlog__c') => Backlog__c.sObjectType.getDescribe()
    };


    public PermissionServices.PermissionLevel hasPermission() {
        PermissionServices.PermissionLevel permissionsLevel = PermissionServices.PermissionLevel.NONE;

        if (hasObjectPermissions() && hasRecordTypePermissions() && hasFLSPermissions() && accessCustomBacklogs) {
            permissionsLevel = PermissionServices.PermissionLevel.FULL;
        } else if (hasObjectReadPermissions() && hasRecordTypePermissions() && hasFLSPermissions() && accessCustomBacklogs) {
            permissionsLevel = PermissionServices.PermissionLevel.READ_ONLY;
        }

        return permissionsLevel;
    }

    public Boolean hasFLSPermissions() {
        return true;
    }

    public Boolean hasObjectPermissions(){
        return PermissionServices.hasObjectFullPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasObjectReadPermissions(){
        return PermissionServices.hasObjectReadPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasRecordTypePermissions(){
        return true;
    }

    private Boolean accessCustomBacklogs {
        get {
            return ALMSettings__c.getInstance().Enable_Custom_Backlogs__c;
        }
        private set;
    }
}