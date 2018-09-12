public with sharing class AdminRolesPermissions implements ApplicationPermissions {

    public static final Map<String, Schema.DescribeSObjectResult> OBJECTS_TO_DESCRIBE = new Map<String, Schema.DescribeSObjectResult> {
        SObjectServices.getFullyQualifiedName('ALM_User_Role__c') => ALM_User_Role__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Sprint_User__c') => Sprint_User__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Backlog_User__c') => Backlog_User__c.sObjectType.getDescribe()
    };

    public PermissionServices.PermissionLevel hasPermission() {
        PermissionServices.PermissionLevel permissionsLevel = PermissionServices.PermissionLevel.NONE;

        if (hasObjectPermissions() && hasRecordTypePermissions() && hasFLSPermissions()) {
            permissionsLevel = PermissionServices.PermissionLevel.FULL;
        }

        return permissionsLevel;
    }

    public Boolean hasFLSPermissions() {
        //For now, we only care about record level access for the admin settings
        return true;
    }

    public Boolean hasObjectPermissions(){
        return PermissionServices.hasObjectFullPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasRecordTypePermissions(){
        //there are no record types for admin settings
        return true;
    }
}