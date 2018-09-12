public with sharing class GitCommitPermissions implements ApplicationPermissions {
    public static final Map<String, Schema.DescribeSObjectResult> OBJECTS_TO_DESCRIBE = new Map<String, Schema.DescribeSObjectResult> {
        SObjectServices.getFullyQualifiedName('SSH_Keypair__c') => SSH_Keypair__c.sObjectType.getDescribe(),
        SObjectServices.getFullyQualifiedName('VC_Repository__c') => VC_Repository__c.sObjectType.getDescribe()
    };

    public static final List<String> SSH_KEYPAIR_FIELDS = new List<String>{
        SObjectServices.getFullyQualifiedName('Passphrase__c'),
        SObjectServices.getFullyQualifiedName('Private_Key__c'),
        SObjectServices.getFullyQualifiedName('Public_Key__c')
    };

    public static final List<String> VC_Repository_FIELDS = new List<String>{
        SObjectServices.getFullyQualifiedName('Repository_URL__c')
    };

    public static Map<String, List<String>> OBJECT_TO_FIELDS = new Map<String, List<String>>{
        SObjectServices.getFullyQualifiedName('SSH_Keypair__c') => SSH_KEYPAIR_FIELDS,
        SObjectServices.getFullyQualifiedName('VC_Repository__c') => VC_Repository_FIELDS
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
        return true;
    }
}