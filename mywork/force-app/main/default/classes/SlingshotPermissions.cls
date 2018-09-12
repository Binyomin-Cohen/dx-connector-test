public with sharing class SlingshotPermissions implements ApplicationPermissions {

    public static final Map<String, Schema.DescribeSObjectResult> OBJECTS_TO_DESCRIBE = new Map<String, Schema.DescribeSObjectResult> {
        SObjectServices.getFullyQualifiedName('ALM_Error__c') => ALM_Error__c.sObjectType.getDescribe(),
        'Attachment' => Attachment.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Build__c') => Build__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('Deployment_Attempt__c') => Deployment_Attempt__c.sObjectType.getDescribe()
    };

    public static Map<String, List<String>> OBJECT_TO_FIELDS = new Map<String, List<String>>{
        SObjectServices.getFullyQualifiedName('ALM_Error__c') => PermissionServices.ALM_ERROR_FIELDS,
        'Attachment' => PermissionServices.ATTACHMENT_FIELDS,
        SObjectServices.getFullyQualifiedName('Build__c') => PermissionServices.BUILD_FIELDS,
        SObjectServices.getFullyQualifiedName('Deployment_Attempt__c') => PermissionServices.DEPLOYMENT_ATTEMPT_FIELDS
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

    public Boolean hasObjectPermissions(){
        return PermissionServices.hasObjectFullPermissions(OBJECTS_TO_DESCRIBE);
    }

    public Boolean hasRecordTypePermissions(){
        return PermissionServices.hasRecordTypePermissions();
    }
}