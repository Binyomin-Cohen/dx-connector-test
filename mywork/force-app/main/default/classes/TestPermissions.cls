/**
 * Test class for all permissions classes AdminSettingsPermissions, etc.
 *
 */
@isTest
private class TestPermissions {

    private static User nonAdminUser;

    private static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        nonAdminUser = TestingUtils.buildUser(p.Id);

       System.runAs(TestingUtils.ADMIN_USER) {
           if (!TestingUtils.isUserAssignedToPermissionSet(TestingUtils.ADMIN_USER.Id, TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET.Id)) {
               insert new PermissionSetAssignment(AssigneeId=TestingUtils.ADMIN_USER.Id, PermissionSetId=TestingUtils.ALM_ADMIN_ACCESS_PERMISSION_SET.Id);
        }
       }
    }

    static testMethod void adminConsoleSettingsPage_hasPermission_admin() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            AdminSettingsPermissions adminPermissions = new AdminSettingsPermissions();
            Test.startTest();
                Boolean result = adminPermissions.hasPermission() == PermissionServices.PermissionLevel.FULL;
            Test.stopTest();

            System.assert(result, 'Admins should have access to the admin console settings page');
        }
    }

    static testMethod void adminConsoleSettingsPage_hasPermission_nonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            AdminSettingsPermissions adminPermissions = new AdminSettingsPermissions();
            Test.startTest();
                Boolean result = adminPermissions.hasPermission() == PermissionServices.PermissionLevel.FULL;
            Test.stopTest();

            System.assertEquals(false, result, 'Non Admins should not have access to the admin console settings page');
        }
    }

    static testMethod void adminConsoleSettingsPage_displaysError_nonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
                AdminAlmSettingsController controller = new AdminAlmSettingsController();
            Test.stopTest();

            System.assertEquals(true, TestingUtils.pageMessageContains(System.Label.Permissions_Error), 'Non Admins should see an error message when accessing the admin console settings page');
        }
    }

    static testMethod void adminConsoleSettingsPage_admin_hasAccess() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
                AdminAlmSettingsController controller = new AdminAlmSettingsController();
            Test.stopTest();

            System.assertEquals(0, ApexPages.getMessages().size(), 'Admins should not see an error message when accessing the admin console settings page');
        }
    }

    static testMethod void adminConsoleInstanceManagement_displaysError_nonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
                AdminInstanceManagementController controller = new AdminInstanceManagementController();
            Test.stopTest();

            System.assertNotEquals(0, controller.pageMessages.size(), 'Non Admins should see an error message when accessing the admin console instance management page');
            Boolean found = false;
            for(PageMessage pageMessage : controller.pageMessages) {
                if (System.Label.Permissions_Error == pageMessage.message) {
                    found = true;
                    break;
                }
            }
            System.assertEquals(true, found, 'Non Admins should see an error message when accessing the admin console instance management page');
        }
    }

    static testMethod void adminConsoleInstanceManagement_admin_hasAccess() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
                AdminInstanceManagementController controller = new AdminInstanceManagementController();
            Test.stopTest();

            Boolean found = false;
            for(PageMessage pageMessage : controller.pageMessages) {
                if (System.Label.Permissions_Error == pageMessage.message) {
                    found = true;
                    break;
                }
            }
            System.assertEquals(false, found, 'Admins should not see an error message when accessing the admin console instance management page');
        }
    }

    static testMethod void adminConsoleRolesPage_displaysError_nonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
                AdminConsoleController controller = new AdminConsoleController();
            Test.stopTest();

            System.assertEquals(true, TestingUtils.pageMessageContains(System.Label.Permissions_Error), 'Non Admins should see an error message when accessing the Roles admin page');
        }
    }

    static testMethod void adminConsoleRolesPage_admin_hasAccess() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
                AdminConsoleController controller = new AdminConsoleController();
            Test.stopTest();

            System.assertEquals(0, ApexPages.getMessages().size(), 'Admins should not see an error message when accessing the Roles admin page');
        }
    }

    static testMethod void adminConsoleBacklogInactiveStatusPage_displaysError_nonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
                AdminBacklogStatusController controller = new AdminBacklogStatusController();
            Test.stopTest();

            System.assertEquals(true, TestingUtils.pageMessageContains(System.Label.Permissions_Error), 'Non Admins should see an error message when accessing the Backlog Inactive Statuses admin page');
        }
    }

    static testMethod void adminConsoleBacklogInactiveStatusPage_admin_hasAccess() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
                AdminBacklogStatusController controller = new AdminBacklogStatusController();
            Test.stopTest();

            System.assertEquals(0, ApexPages.getMessages().size(), 'Admins should not see an error message when accessing the Backlog Inactive Statuses admin page');
        }
    }

    static testMethod void adminBacklogPrioritizationColumnsPage_displaysError_nonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
                AdminBacklogPrioritizationColsCont controller = new AdminBacklogPrioritizationColsCont();
            Test.stopTest();

            System.assertEquals(true, TestingUtils.pageMessageContains(System.Label.Permissions_Error), 'Non Admins should see an error message when accessing the Backlog Prioritization Columns admin page');
        }
    }

    static testMethod void adminBacklogPrioritizationColumnsPage_admin_hasAccess() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
                AdminBacklogPrioritizationColsCont controller = new AdminBacklogPrioritizationColsCont();
            Test.stopTest();

            System.assertEquals(0, ApexPages.getMessages().size(), 'Admins should not see an error message when accessing the Backlog Prioritization Columns admin page');
        }
    }

    static testMethod void adminSprintLanesPage_displaysError_nonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
                AdminSprintLanesController controller = new AdminSprintLanesController();
            Test.stopTest();

            System.assertEquals(true, TestingUtils.pageMessageContains(System.Label.Permissions_Error), 'Non Admins should see an error message when accessing the Sprint Lanes admin page');
        }
    }

    static testMethod void adminSprintLanesPage_admin_hasAccess() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
                AdminSprintLanesController controller = new AdminSprintLanesController();
            Test.stopTest();

            System.assertEquals(0, ApexPages.getMessages().size(), 'Admins should not see an error message when accessing the Sprint Lanes admin page');
        }
    }

    static testMethod void backlogUserManagementPage_displaysError_nonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Backlog__c backlogItem = TestingUtils.createBacklogItem();

            Test.startTest();
                BacklogUserMgmtContExt controller = new BacklogUserMgmtContExt(new ApexPages.StandardController(backlogItem));
            Test.stopTest();

            System.assertEquals(true, TestingUtils.pageMessageContains(System.Label.Permissions_Error), 'Non Admins should see an error message when accessing the Backlog User Management page');
        }
    }

    static testMethod void backlogUserManagementPage_admin_hasAccess() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Backlog__c backlogItem = TestingUtils.createBacklogItem();

            Test.startTest();
                BacklogUserMgmtContExt controller = new BacklogUserMgmtContExt(new ApexPages.StandardController(backlogItem));
            Test.stopTest();

            System.assertEquals(0, ApexPages.getMessages().size(), 'Admins should not see an error message when accessing the Backlog User Management page');
        }
    }

    static testMethod void backlogManagementPage_displaysError_nonAdmin() {
        setup();

        System.runAs(nonAdminUser) {
            Test.startTest();
                BacklogManagementExt controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
            Test.stopTest();

            System.assertEquals(true, TestingUtils.pageMessageContains(System.Label.Permissions_Error), 'Non Admins should see an error message when accessing the Backlog Management page');
        }
    }

    static testMethod void backlogManagementPage_admin_hasAccess() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
                BacklogManagementExt controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
            Test.stopTest();

            System.assertEquals(0, ApexPages.getMessages().size(), 'Admins should not see an error message when accessing the Backlog Management page');
        }
    }

    static testMethod void sprintHome_displaysError_nonAdmin() {
        setup();
        insert new Custom_Backlog__c(Universal__c = true);

        System.runAs(nonAdminUser) {
            Test.startTest();
                SprintHomeController controller = new SprintHomeController();
            Test.stopTest();

            System.assertEquals(true, TestingUtils.pageMessageContains(System.Label.Permissions_Error), 'Non Admins should see an error message when accessing the Sprint Home page');
        }
    }

    static testMethod void sprintHome_admin_hasAccess() {
        setup();
        insert new Custom_Backlog__c(Universal__c = true);

        System.runAs(TestingUtils.ADMIN_USER) {

            Test.startTest();
                SprintHomeController controller = new SprintHomeController();
            Test.stopTest();

            System.assertEquals(0, ApexPages.getMessages().size(), 'Admins should not see an error message when accessing the Sprint Home page');
        }
    }

    static testMethod void sprintDetailPage_displaysError_nonAdmin() {
        setup();

        Sprint__c sprint = new Sprint__c(Name='Test Sprint');
        insert sprint;

        System.runAs(nonAdminUser) {
            Test.startTest();
                SprintDetailControllerExt controller = new SprintDetailControllerExt(new ApexPages.StandardController(sprint));
            Test.stopTest();

            System.assertEquals(true, TestingUtils.pageMessageContains(System.Label.Permissions_Error), 'Non Admins should see an error message when accessing the Sprint Detail page');
        }
    }

    static testMethod void sprintDetailPage_admin_hasAccess() {
        setup();

        Sprint__c sprint = new Sprint__c(Name='Test Sprint');
        insert sprint;

        System.runAs(TestingUtils.ADMIN_USER) {
            Test.startTest();
                SprintDetailControllerExt controller = new SprintDetailControllerExt(new ApexPages.StandardController(sprint));
            Test.stopTest();

            System.assertEquals(0, ApexPages.getMessages().size(), 'Admins should not see an error message when accessing the Sprint Detail page');
        }
    }

    static testMethod void customBacklogPage_hasPermission_Admin() {
        setup();

        ALMSettings__c settings = new ALMSettings__c(Enable_Custom_Backlogs__c=true);
        insert settings;

        System.runAs(TestingUtils.ADMIN_USER) {
            CustomBacklogPermissions cbPermissions = new CustomBacklogPermissions();

            Test.startTest();
                Boolean result = cbPermissions.hasPermission() == PermissionServices.PermissionLevel.FULL;
            Test.stopTest();

            System.assert(result, 'Admins should have access to Custom Backlogs');
        }
    }

    static testMethod void customBacklogPage_hasPermission_Admin_withoutCustomSetting() {
        setup();

        System.runAs(TestingUtils.ADMIN_USER) {
            CustomBacklogPermissions cbPermissions = new CustomBacklogPermissions();

            Test.startTest();
                Boolean result = cbPermissions.hasPermission() == PermissionServices.PermissionLevel.FULL;
            Test.stopTest();

            System.assertEquals(false, result, 'Admins should have access to Custom Backlogs without custom setting enabled');
        }
    }

    static testMethod void customBacklogPage_hasPermission_NonAdmin() {
        setup();

        ALMSettings__c settings = new ALMSettings__c(Enable_Custom_Backlogs__c=true);
        insert settings;

        System.runAs(nonAdminUser) {
            CustomBacklogPermissions cbPermissions = new CustomBacklogPermissions();

            Test.startTest();
                Boolean result = cbPermissions.hasPermission() == PermissionServices.PermissionLevel.FULL;
            Test.stopTest();

            System.assertEquals(false, result, 'Non Admins should not have access to Custom Backlogs');
        }
    }
}