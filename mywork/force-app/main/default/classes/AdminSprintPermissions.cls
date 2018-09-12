public with sharing class AdminSprintPermissions  implements ApplicationPermissions {

    public static final Map<String, Schema.DescribeSObjectResult> OBJECTS_TO_DESCRIBE = new Map<String, Schema.DescribeSObjectResult> {
        SObjectServices.getFullyQualifiedName('ALM_Settings_List__c') => ALM_Settings_List__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Sprint__c') => Sprint__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Sprint_Item__c') => Sprint_Item__c.sObjectType.getDescribe()
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