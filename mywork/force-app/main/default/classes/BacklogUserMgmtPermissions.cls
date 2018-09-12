public with sharing class BacklogUserMgmtPermissions implements ApplicationPermissions {

    public static final Map<String, Schema.DescribeSObjectResult> OBJECTS_TO_DESCRIBE = new Map<String, Schema.DescribeSObjectResult> {
       SObjectServices.getFullyQualifiedName('Backlog_User__c') => Backlog_User__c.sObjectType.getDescribe()
    };

    public PermissionServices.PermissionLevel hasPermission() {
        PermissionServices.PermissionLevel permissionsLevel = PermissionServices.PermissionLevel.NONE;

        if (hasObjectPermissions() && hasRecordTypePermissions() && hasFLSPermissions()) {
            permissionsLevel = PermissionServices.PermissionLevel.FULL;
        } else if (hasObjectReadPermissions() && hasRecordTypePermissions() && hasFLSPermissions()) {
            permissionsLevel = PermissionServices.PermissionLevel.READ_ONLY;
        }

        return permissionsLevel;
    }

    public Boolean hasFLSPermissions() {
        return true;
    }

    public Boolean hasObjectPermissions() {
        return PermissionServices.hasObjectFullPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasObjectReadPermissions() {
        return PermissionServices.hasObjectReadPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasRecordTypePermissions() {
        return true;
    }
}