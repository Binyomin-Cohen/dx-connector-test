public with sharing class PermissionServices {
    public enum PermissionLevel {
        NONE,
        READ_ONLY,
        FULL
    }

    public static final List<String> ALM_ERROR_FIELDS = new List<String>{
         SObjectServices.getFullyQualifiedName('Build__c'),
         SObjectServices.getFullyQualifiedName('Changed__c'),
         SObjectServices.getFullyQualifiedName('Class__c'),
         SObjectServices.getFullyQualifiedName('Component_Name__c'),
         SObjectServices.getFullyQualifiedName('Component_Type__c'),
         SObjectServices.getFullyQualifiedName('Deleted__c'),
         SObjectServices.getFullyQualifiedName('Deployment_Attempt__c'),
         SObjectServices.getFullyQualifiedName('Description__c'),
         SObjectServices.getFullyQualifiedName('Duration__c'),
         SObjectServices.getFullyQualifiedName('Error_Cause__c'),
         SObjectServices.getFullyQualifiedName('Error_Location__c'),
         SObjectServices.getFullyQualifiedName('Error_Message__c'),
         SObjectServices.getFullyQualifiedName('Method__c'),
         SObjectServices.getFullyQualifiedName('Parent_Component__c'),
         'RecordTypeId',
         SObjectServices.getFullyQualifiedName('Stack_Trace__c'),
         SObjectServices.getFullyQualifiedName('Tool__c'),
         SObjectServices.getFullyQualifiedName('Type__c')
    };

    public static final List<String> ATTACHMENT_FIELDS = new List<String>{
        'Body',
        'Name',
        'ParentId'
    };

    public static final List<String> BACKLOG_COMPONENT_FIELDS = new List<String>{
        SObjectServices.getFullyQualifiedName('Deploy_Manually__c'),
        SObjectServices.getFullyQualifiedName('Notes__c'),
        SObjectServices.getFullyQualifiedName('Profile__c'),
        SObjectServices.getFullyQualifiedName('Profile_Data_1__c'),
        SObjectServices.getFullyQualifiedName('Profile_Data_2__c'),
        SObjectServices.getFullyQualifiedName('Profile_Permission__c'),
        SObjectServices.getFullyQualifiedName('Source_Instance__c'),
        SObjectServices.getFullyQualifiedName('Source_Sandbox__c')
    };

    public static final List<String> BUILD_FIELDS = new List<String>{
        SObjectServices.getFullyQualifiedName('Package_URL__c'),
        SObjectServices.getFullyQualifiedName('Status__c')
    };

    public static final List<String> DEPLOYMENT_ATTEMPT_FIELDS = new List<String>{
         SObjectServices.getFullyQualifiedName('End_Date__c'),
         SObjectServices.getFullyQualifiedName('Number_Components_Deployed__c'),
         SObjectServices.getFullyQualifiedName('Number_Components_Errors__c'),
         SObjectServices.getFullyQualifiedName('Number_Components_Total__c'),
         SObjectServices.getFullyQualifiedName('Number_Test_Errors__c'),
         SObjectServices.getFullyQualifiedName('Number_Tests_Completed__c'),
         SObjectServices.getFullyQualifiedName('Number_Tests_Total__c'),
         SObjectServices.getFullyQualifiedName('Start_Date__c'),
         SObjectServices.getFullyQualifiedName('State_Detail__c'),
         SObjectServices.getFullyQualifiedName('Status__c'),
         SObjectServices.getFullyQualifiedName('Total_Code_Coverage__c'),
         SObjectServices.getFullyQualifiedName('Total_Lines__c'),
         SObjectServices.getFullyQualifiedName('Total_Lines_Not_Covered__c'),
         SObjectServices.getFullyQualifiedName('UUID__c')
    };

    /**
    * Checks to see if permissions exist for an application. A page message will be added, if the
    * user doesn't have permission
    * @param appPermissions     The permissions instance for the current application
    * @return PermissionServices.PermissionLevel   The level of permissions that the user has for the application
    */
    public static PermissionServices.PermissionLevel checkPagePermissions(ApplicationPermissions appPermissions) {
        PermissionServices.PermissionLevel permissionsLevel = appPermissions.hasPermission();
        if (permissionsLevel == PermissionServices.PermissionLevel.NONE) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                System.Label.Permissions_Error
            ));
        }
        return permissionsLevel;
    }


    /**
    * Determines if the current user has full permission to the given objects
    * @param objectToDescribeMap    The map of object describe info to validate permissions against. Map of the form {"Object Name" => Schema.DescribeSObjectResult}
    */
    public static Boolean hasObjectFullPermissions(Map<String, Schema.DescribeSObjectResult> objectToDescribeMap) {
      for (String objectName : objectToDescribeMap.keySet()) {
            Schema.DescribeSObjectResult describe = objectToDescribeMap.get(objectName);

            if (!(describe.isAccessible() && describe.isCreateable() && describe.isUpdateable() && describe.isDeletable())) {
                return false;
            }
      }

      return true;
    }

    /**
    * Determines if the current user has read-only permission to the given objects
    * @param objectToDescribeMap    The map of object describe info to validate permissions against. Map of the form {"Object Name" => Schema.DescribeSObjectResult}
    */
    public static Boolean hasObjectReadPermissions(Map<String, Schema.DescribeSObjectResult> objectToDescribeMap) {
      for (String objectName : objectToDescribeMap.keySet()) {
            Schema.DescribeSObjectResult describe = objectToDescribeMap.get(objectName);

            if (!describe.isAccessible()) {
                return false;
            }
      }

      return true;
    }

    public static Boolean hasRecordTypePermissions() {
        Schema.DescribeSObjectResult describe = ALM_Error__c.SObjectType.getDescribe();
        List<Schema.RecordTypeInfo> infos = describe.getRecordTypeInfos();

        for (Schema.RecordTypeInfo info : infos) {
            if (!info.isAvailable()) {
                return false;
            }
        }

        return true;
    }

    /**
    * Determines if the current user has full FLS access to the given objects and fields
    * @param objectToDescribeMap    The map of object describe info to validate permissions against. Map of the form {"Object Name" => Schema.DescribeSObjectResult}
    * @param objectToFieldsMap      The map of fields to validate. Map of the form {"Object Name" => [fields]}
    */
    public static Boolean hasFLSFullPermissions(Map<String, Schema.DescribeSObjectResult> objectToDescribeMap, Map<String, List<String>> objectToFieldsMap) {
        return hasFLSPermissions(objectToDescribeMap, objectToFieldsMap, PermissionLevel.FULL);
    }

    /**
    * Determines if the current user has read-only FLS access to the given objects and fields
    * @param objectToDescribeMap    The map of object describe info to validate permissions against. Map of the form {"Object Name" => Schema.DescribeSObjectResult}
    * @param objectToFieldsMap      The map of fields to validate. Map of the form {"Object Name" => [fields]}
    */
    public static Boolean hasFLSReadPermissions(Map<String, Schema.DescribeSObjectResult> objectToDescribeMap, Map<String, List<String>> objectToFieldsMap) {
        return hasFLSPermissions(objectToDescribeMap, objectToFieldsMap, PermissionLevel.READ_ONLY);
    }

    /**
    * Determines if the current user has FLS access to the given objects and fields
    * @param objectToDescribeMap    The map of object describe info to validate permissions against. Map of the form {"Object Name" => Schema.DescribeSObjectResult}
    * @param objectToFieldsMap      The map of fields to validate. Map of the form {"Object Name" => [fields]}
    * @param permissionsLevel       The level of permissions required of the given objects and fields
    */
    public static Boolean hasFLSPermissions(Map<String, Schema.DescribeSObjectResult> objectToDescribeMap, Map<String, List<String>> objectToFieldsMap, PermissionLevel permissionsLevel) {
        for (String objectName : objectToFieldsMap.keySet()) {
            Schema.DescribeSObjectResult describe = objectToDescribeMap.get(objectName);
            Map<String,Schema.SObjectField> dfMap = describe.fields.getMap();

            List<String> fieldsToVerify = objectToFieldsMap.get(objectName);
            for (String fieldName : fieldsToVerify) {
                Schema.DescribeFieldResult dfr = dfMap.get(fieldName).getDescribe();

                if (permissionsLevel == PermissionLevel.FULL &&
                        !(dfr.isAccessible() &&
                            dfr.isCreateable() &&
                                (fieldName.equals('ParentId') ? true : dfr.isUpdateable()))) {
                    return false;
                } else if (permissionsLevel == PermissionLevel.READ_ONLY && !dfr.isAccessible()) {
                    return false;
                }
            }
        }

        return true;
    }
}