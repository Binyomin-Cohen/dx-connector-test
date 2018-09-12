@isTest
private class TestPermissionServices {
    private static User nonAdminUser;


    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        nonAdminUser = TestingUtils.buildUser(p.Id);

       if (!TestingUtils.isUserAssignedToPermissionSet(TestingUtils.ADMIN_USER.Id, TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET.Id)) {
           insert new PermissionSetAssignment(AssigneeId=TestingUtils.ADMIN_USER.Id, PermissionSetId=TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET.Id);
       }
    }

    static testMethod void hasObjectFullPermissions_Admin() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
              Boolean result = PermissionServices.hasObjectFullPermissions(SlingshotPermissions.OBJECTS_TO_DESCRIBE);
            Test.stopTest();

            System.assert(result, 'Admins should have access to Slingshot objects');
        }
    }

    static testMethod void hasObjectFullPermissions_NonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
              Boolean result = PermissionServices.hasObjectFullPermissions(SlingshotPermissions.OBJECTS_TO_DESCRIBE);
            Test.stopTest();

            System.assertEquals(false, result, 'Non Admins should not have access to Slingshot objects');
        }
    }

    static testMethod void hasRecordTypePermissions_NonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
              Boolean result = PermissionServices.hasRecordTypePermissions();
            Test.stopTest();

            System.assertEquals(false, result, 'Non Admins should not have access to Slingshot record types');
        }
    }

    static testMethod void hasFieldLevelSecurity_Admin() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
                Boolean result = PermissionServices.hasFLSFullPermissions(SlingshotPermissions.OBJECTS_TO_DESCRIBE, SlingshotPermissions.OBJECT_TO_FIELDS);
            Test.stopTest();

            System.assertEquals(true, result, 'Admins should have access to fields needed by Slingshot');
        }
    }

    static testMethod void hasFieldLevelSecurity_NonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
                Boolean result = PermissionServices.hasFLSFullPermissions(SlingshotPermissions.OBJECTS_TO_DESCRIBE, SlingshotPermissions.OBJECT_TO_FIELDS);
            Test.stopTest();

            System.assertEquals(false, result, 'Non admins should not have access to fields needed by Slingshot');
        }
    }
}