public with sharing class JenkinsJobPermissions implements ApplicationPermissions {
    public static final Map<String, Schema.DescribeSObjectResult> OBJECTS_TO_DESCRIBE = new Map<String, Schema.DescribeSObjectResult> {
        SObjectServices.getFullyQualifiedName('Jenkins_Job__c') => Jenkins_Job__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Jenkins_Build__c') => Jenkins_Build__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('CI_Instance__c') => Jenkins_Build__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Release__c') => Jenkins_Build__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Build_Rule__c') => Build_Rule__c.sObjectType.getDescribe()
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

    public Boolean hasObjectPermissions() {
        return PermissionServices.hasObjectFullPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasRecordTypePermissions() {
        return true;
    }
}
