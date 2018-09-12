@isTest
private class TestSlingshotPermissions {
    private static User nonAdminUser;
    private static SlingshotPermissions ssPermissions;

    private static void setup() {
        ssPermissions = new SlingshotPermissions();
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        nonAdminUser = TestingUtils.buildUser(p.Id);

       if (!TestingUtils.isUserAssignedToPermissionSet(TestingUtils.ADMIN_USER.Id, TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET.Id)) {
           insert new PermissionSetAssignment(AssigneeId=TestingUtils.ADMIN_USER.Id, PermissionSetId=TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET.Id);
       }
    }

    static testMethod void hasPermission_Admin() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
                Boolean result = ssPermissions.hasPermission() == PermissionServices.PermissionLevel.FULL;
            Test.stopTest();

            System.assert(result, 'Admins should have access to Slingshot');
        }
    }

    static testMethod void hasPermission_NonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
                Boolean result = ssPermissions.hasPermission() == PermissionServices.PermissionLevel.FULL;
            Test.stopTest();

            System.assertEquals(false, result, 'Non Admins should not have access to Slingshot');
        }
    }
}