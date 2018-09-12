public with sharing class BacklogManagementPermissions implements ApplicationPermissions {

    public static final Map<String, Schema.DescribeSObjectResult> OBJECTS_TO_DESCRIBE = new Map<String, Schema.DescribeSObjectResult> {
        SObjectServices.getFullyQualifiedName('Backlog__c') => Backlog__c.sObjectType.getDescribe()
    };

    public static Map<String, List<String>> OBJECT_TO_FIELDS = new Map<String, List<String>>{
        SObjectServices.getFullyQualifiedName('Backlog__c') => new List<String>{
            SObjectServices.getFullyQualifiedName('Priority__c')
        }
    };

    public PermissionServices.PermissionLevel hasPermission() {
        PermissionServices.PermissionLevel permissionsLevel = PermissionServices.PermissionLevel.NONE;

        if (hasObjectPermissions() && hasRecordTypePermissions() && hasFLSPermissions()) {
            permissionsLevel = PermissionServices.PermissionLevel.FULL;
        } else if (hasObjectReadPermissions() && hasRecordTypePermissions() && hasFLSReadPermissions()) {
            permissionsLevel = PermissionServices.PermissionLevel.READ_ONLY;
        }

        return permissionsLevel;
    }

    public Boolean hasFLSPermissions() {
        return PermissionServices.hasFLSFullPermissions(OBJECTS_TO_DESCRIBE, OBJECT_TO_FIELDS);
    }

    public Boolean hasFLSReadPermissions() {
        return PermissionServices.hasFLSReadPermissions(OBJECTS_TO_DESCRIBE, OBJECT_TO_FIELDS);
    }

    public Boolean hasObjectPermissions() {
        return PermissionServices.hasObjectFullPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasObjectReadPermissions() {
        return PermissionServices.hasObjectReadPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasRecordTypePermissions() {
        //record type permissions aren't necessary for backlog management
        return true;
    }
}