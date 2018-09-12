@isTest
private class TestAdminConsoleController {

    static testMethod void saveRoles() {
        ALM_User_Role__c newRole = new ALM_User_Role__c(Name='Developer');

        Test.startTest();
            AdminConsoleController.saveRoles(new List<ALM_User_Role__c>{newRole}, new List<String>());
        Test.stopTest();

        List<ALM_User_Role__c> roles = [SELECT Id, Name FROM ALM_User_Role__c];

        System.assertEquals(1, roles.size(), '1 role should have been created.');
        System.assertEquals(newRole.Name, roles[0].Name, 'The name should be set to the requested role.');
    }

    static testMethod void saveRoles_validateNoExistingUsers() {
        ALM_User_Role__c role = new ALM_User_Role__c(Name='Developer');
        insert role;
        ALM_User__c user = new ALM_User__c(First_Name__c = 'Gary', Last_Name__c = 'Green');
        insert user;
        Backlog__c backlogItem = TestingUtils.createBacklogItem();

        Backlog_User__c backlogUser = new Backlog_User__c(
            Backlog__c = backlogItem.Id, ALM_User__c = user.Id, Role__c = role.Id
        );

        insert backlogUser;

        Test.startTest();
            try {
                AdminConsoleController.saveRoles(new List<ALM_User_Role__c>(), new List<String>{(String)role.Id});
                System.assert(false, 'Roles with assigned users should not be able to be deleted');
            } catch(ALMException ae) {

            }
        Test.stopTest();
        List<ALM_User_Role__c> roles = [SELECT Id FROM ALM_User_Role__c WHERE Id = :role.Id];
        System.assertEquals(1, roles.size(), 'Roles with assigned users should not be deleted');
    }

    static testMethod void saveRoles_duplicates_sameCase_withinBatch() {
        String testRoleName = 'Test Role';

        ALM_User_Role__c testRole0 = new ALM_User_Role__c(Name=testRoleName);
        ALM_User_Role__c testRole1 = new ALM_User_Role__c(Name=testRoleName);

        Test.startTest();
            AdminConsoleController.saveRoles(new List<ALM_User_Role__c>{ testRole0, testRole1 }, new List<String>());
        Test.stopTest();

        List<ALM_User_Role__c> roles = [SELECT Name FROM ALM_User_Role__c];
        System.assertEquals(1, roles.size(), 'Only one of the duplicate roles should exist.');
        System.assertEquals(testRoleName, roles[0].Name, 'The retrieved role\'s name should be correct.');
    }

    static testMethod void saveRoles_duplicates_sameCase_acrossBatches() {
        String testRoleName = 'Test Role';

        ALM_User_Role__c testRole0 = new ALM_User_Role__c(Name=testRoleName);
        ALM_User_Role__c testRole1 = new ALM_User_Role__c(Name=testRoleName);

        Test.startTest();
            AdminConsoleController.saveRoles(new List<ALM_User_Role__c>{ testRole0 }, new List<String>());
            AdminConsoleController.saveRoles(new List<ALM_User_Role__c>{ testRole1 }, new List<String>());
        Test.stopTest();

        List<ALM_User_Role__c> roles = [SELECT Name FROM ALM_User_Role__c];
        System.assertEquals(1, roles.size(), 'Only one of the duplicate roles should exist.');
        System.assertEquals(testRoleName, roles[0].Name, 'The retrieved role\'s name should be correct.');
    }

    static testMethod void saveRoles_duplicates_differentCase_withinBatch() {
        String testRoleName0 = 'Test Role';
        String testRoleName1 = 'TEST ROLE';
        String testRoleName2 = 'test role';

        ALM_User_Role__c testRole0 = new ALM_User_Role__c(Name=testRoleName0);
        ALM_User_Role__c testRole1 = new ALM_User_Role__c(Name=testRoleName1);
        ALM_User_Role__c testRole2 = new ALM_User_Role__c(Name=testRoleName2);

        Test.startTest();
            AdminConsoleController.saveRoles(new List<ALM_User_Role__c>{ testRole2, testRole1, testRole0 }, new List<String>());
        Test.stopTest();

        List<ALM_User_Role__c> roles = [SELECT Name FROM ALM_User_Role__c];
        System.assertEquals(1, roles.size(), 'Only one of the duplicate roles should exist.');
        System.assertEquals(testRoleName0.toUpperCase(), roles[0].Name.toUpperCase(), 'The retrieved role\'s name should be correct (case-insensitive).');
    }

    static testMethod void saveRoles_duplicates_differentCase_acrossBatches() {
        String testRoleName0 = 'Test Role';
        String testRoleName1 = 'TEST ROLE';
        String testRoleName2 = 'test role';

        ALM_User_Role__c testRole0 = new ALM_User_Role__c(Name=testRoleName0);
        ALM_User_Role__c testRole1 = new ALM_User_Role__c(Name=testRoleName1);
        ALM_User_Role__c testRole2 = new ALM_User_Role__c(Name=testRoleName2);

        Test.startTest();
            AdminConsoleController.saveRoles(new List<ALM_User_Role__c>{ testRole0 }, new List<String>());
            AdminConsoleController.saveRoles(new List<ALM_User_Role__c>{ testRole1 }, new List<String>());
            AdminConsoleController.saveRoles(new List<ALM_User_Role__c>{ testRole2 }, new List<String>());
        Test.stopTest();

        List<ALM_User_Role__c> roles = [SELECT Name FROM ALM_User_Role__c];
        System.assertEquals(1, roles.size(), 'Only one of the duplicate roles should exist.');
        System.assertEquals(testRoleName0.toUpperCase(), roles[0].Name.toUpperCase(), 'The retrieved role\'s name should be correct (case-insensitive).');
    }
}