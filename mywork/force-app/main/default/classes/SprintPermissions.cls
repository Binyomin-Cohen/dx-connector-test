public with sharing class SprintPermissions implements ApplicationPermissions {
    public static final Map<String, Schema.DescribeSObjectResult> OBJECTS_TO_DESCRIBE = new Map<String, Schema.DescribeSObjectResult> {
        SObjectServices.getFullyQualifiedName('Sprint__c') => Sprint__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Sprint_Item__c') => Sprint_Item__c.sObjectType.getDescribe(),
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
        return true;
    }

    public Boolean hasObjectPermissions(){
        return PermissionServices.hasObjectFullPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasRecordTypePermissions(){
        return true;
    }
}