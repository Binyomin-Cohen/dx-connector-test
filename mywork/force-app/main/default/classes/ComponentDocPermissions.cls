/**
*  Responsible for controlling access to the component documentation page
*/
public with sharing class ComponentDocPermissions  implements ApplicationPermissions {
    public static final Map<String, Schema.DescribeSObjectResult> OBJECTS_TO_DESCRIBE = new Map<String, Schema.DescribeSObjectResult> {
        SObjectServices.getFullyQualifiedName('Backlog_Component__c') => Backlog_Component__c.sObjectType.getDescribe()
    };

    public static Map<String, List<String>> OBJECT_TO_FIELDS = new Map<String, List<String>>{
        SObjectServices.getFullyQualifiedName('Backlog_Component__c') => PermissionServices.BACKLOG_COMPONENT_FIELDS
    };

    public PermissionServices.PermissionLevel hasPermission() {
        PermissionServices.PermissionLevel permissionsLevel = PermissionServices.PermissionLevel.NONE;

        if (hasObjectPermissions() && hasRecordTypePermissions() && hasFLSPermissions()) {
            permissionsLevel = PermissionServices.PermissionLevel.FULL;
        }

        return permissionsLevel;
    }

    public Boolean hasFLSPermissions() {
        return PermissionServices.hasFLSFullPermissions(OBJECTS_TO_DESCRIBE, OBJECT_TO_FIELDS);
    }

    public Boolean hasObjectPermissions() {
        return PermissionServices.hasObjectFullPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasRecordTypePermissions() {
        return true;
    }
}