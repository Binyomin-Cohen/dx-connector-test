@isTest
private class TestBacklogUserMgmtContExt {

    static Backlog__c story;
    static BacklogUserMgmtContExt controller;
    static ApexPages.StandardController sc;

    static void setup() {
        setup(null);
    }

    static void setup(User setupUser) {
        Persona__c persona = new Persona__c(Name='Build Manager');
        insert persona;

        story = new Backlog__c(Persona__c=persona.Id);
        insert story;

        sc = new ApexPages.StandardController( story );

        setupUser = setupUser != null ? setupUser : new User(Id = UserInfo.getUserId());
        System.runAs(setupUser) {
            controller = new BacklogUserMgmtContExt(sc);
        }
        controller.loadBacklogUsers();
    }

    static testMethod void getALMUsers() {
        ALM_User__c matchingUser1 = TestingUtils.createALMUser('Jerry Garcia');
        ALM_User__c matchingUser2 = TestingUtils.createALMUser('Jerry Mouse');

        Test.startTest();
            List<ALM_User__c> matchingResults = BacklogUserMgmtContExt.getALMUsers();
        Test.stopTest();

        System.assertEquals(2, matchingResults.size(), 'All results should be returned');
        System.assertEquals(matchingUser1.Id, matchingResults[0].Id, 'All results should be returned in alphabetical order');
        System.assertEquals(matchingUser2.Id, matchingResults[1].Id, 'All results should be returned in alphabetical order');
    }

    static testMethod void getUserRoles() {
        ALM_User_Role__c matchingRole1 = TestingUtils.createUserRole('Fake Role A');
        ALM_User_Role__c matchingRole2 = TestingUtils.createUserRole('Fake Role B');

        Test.startTest();
            List<ALM_User_Role__c> results = BacklogUserMgmtContExt.getUserRoles();
        Test.stopTest();

        System.assertEquals(2, results.size(), 'All roles should be returned.');
        System.assertEquals(matchingRole1.Id, results[0].Id, 'All roles should be returned ordered by Name.');
        System.assertEquals(matchingRole2.Id, results[1].Id, 'All roles should be returned ordered by Name.');
    }

    static testMethod void save_validateRole() {
        setup();

        ALM_User__c user = TestingUtils.createALMUser('Bill Smith');

        String roleName = 'Developer';

        controller.selectedAlmUserId = user.Id;
        controller.addUser();

        Test.startTest();

            controller.save();

        Test.stopTest();

        List<Backlog_User__c> backlogUsers = [
            SELECT Id, Backlog__c, ALM_User__c, Role__c FROM Backlog_User__c
        ];

        System.assertEquals(0, backlogUsers.size(), 'The Backlog User should not be saved when there are validation errors');
        System.assert(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'An error should be added to the page');
        System.assertEquals(System.Label.Backlog_User_Mgmt_Role_Required, ApexPages.getMessages()[0].getDetail(), 'The error should be about missing roles.');
    }

    static testMethod void save_InsertSuccess() {
        setup();

        String roleName = 'Developer';
        ALM_User_Role__c newRole = TestingUtils.createUserRole(roleName);

        ALM_User__c user = TestingUtils.createALMUser('Bill Smith');

        controller.selectedAlmUserId = user.Id;
        controller.addUser();
        controller.backlogUsers[0].role = newRole.Id;

        Test.startTest();

            controller.save();

        Test.stopTest();

        List<Backlog_User__c> backlogUsers = [
            SELECT Id, Backlog__c, ALM_User__c, Role__c FROM Backlog_User__c
        ];

        System.assertEquals(1, backlogUsers.size(), 'The Backlog User should be inserted on save');
        System.assertEquals(user.Id, backlogUsers[0].ALM_User__c, 'The ALM User lookup should be populated on save');
        System.assertEquals(story.Id, backlogUsers[0].Backlog__c, 'The Backlog lookup should be populated on save');
        System.assertEquals(newRole.Id, backlogUsers[0].Role__c, 'The role should be populated on save');
    }

    @isTest
    private static void save_insertFailure_permissions_readOnly() {
        User readOnlyUser = null;
        System.runAs(TestingUtils.ADMIN_USER) {
            readOnlyUser = TestingUtils.createUser([SELECT Id FROM Profile WHERE Name = 'Standard User'].Id);
            insert new PermissionSetAssignment(AssigneeId = readOnlyUser.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Backlog_Management_Read_Only'].Id);
        }

        setup(readOnlyUser);

        String roleName = 'Developer';
        ALM_User_Role__c newRole = TestingUtils.createUserRole(roleName);

        ALM_User__c user = TestingUtils.createALMUser('Bill Smith');

        controller.selectedAlmUserId = user.Id;
        controller.backlogUsers.add(UserAssignment.create(Id.valueOf(sc.getId()), ALMUserServices.getALMUser(controller.selectedAlmUserId)));
        controller.backlogUsers[0].role = newRole.Id;

        Test.startTest();

            controller.save();

        Test.stopTest();

        List<Backlog_User__c> backlogUsers = [
            SELECT Id, Backlog__c, ALM_User__c, Role__c FROM Backlog_User__c
        ];

        System.assertEquals(0, backlogUsers.size(), 'The Backlog User should be inserted on save');
    }

    static testMethod void save_UpdateSuccess() {
        setup();

        String roleName = 'Developer';
        ALM_User_Role__c otherRole = TestingUtils.createUserRole('Other');
        ALM_User_Role__c newRole = TestingUtils.createUserRole(roleName);

        ALM_User__c user = TestingUtils.createALMUser('Bill Smith');

        Backlog_User__c backlogUser = new Backlog_User__c();
        backlogUser.ALM_User__c = user.Id;
        backlogUser.Backlog__c = story.Id;
        backlogUser.Role__c = otherRole.Id;

        insert backlogUser;


        controller = new BacklogUserMgmtContExt( new ApexPages.StandardController( story ) );
        controller.loadBacklogUsers();

        Test.startTest();

	        controller.backlogUsers[0].role = newRole.Id;
            controller.save();

        Test.stopTest();

        List<Backlog_User__c> backlogUsers = [
            SELECT Id, Backlog__c, ALM_User__c, Role__c FROM Backlog_User__c
        ];

        System.assertEquals(1, backlogUsers.size(), 'The Backlog User should be updated on save');
        System.assertEquals(newRole.Id, backlogUsers[0].Role__c, 'The role should be updated on save');
    }

    static testMethod void save_DeleteSuccess() {
        setup();

        ALM_User_Role__c role1 = TestingUtils.createUserRole('Developer');

        ALM_User__c user1 = TestingUtils.createALMUser('Bill Smith');
        ALM_User__c user2 = TestingUtils.createALMUser('Sally Jones');


        Backlog_User__c backlogUser1 = new Backlog_User__c();
        backlogUser1.ALM_User__c = user1.Id;
        backlogUser1.Backlog__c = story.Id;
        backlogUser1.Role__c = role1.Id;

        Backlog_User__c backlogUser2 = new Backlog_User__c();
        backlogUser2.ALM_User__c = user2.Id;
        backlogUser2.Backlog__c = story.Id;
        backlogUser2.Role__c = role1.Id;

        insert new List<Backlog_User__c>{ backlogUser1, backlogUser2 };


        controller = new BacklogUserMgmtContExt( new ApexPages.StandardController( story ) );
        controller.loadBacklogUsers();

        Test.startTest();

	        controller.selectedAlmUserId = user1.Id;
	        controller.deleteUser();
            controller.save();

        Test.stopTest();

        List<Backlog_User__c> backlogUsers = [
            SELECT Id, Backlog__c, ALM_User__c, Role__c FROM Backlog_User__c
        ];

        System.assertEquals(1, backlogUsers.size(), 'The Backlog User should have been deleted on save.');
        System.assertEquals(user2.Id, backlogUsers[0].ALM_User__c, 'The correct user should have been deleted.');
    }

    @isTest
    private static void save_deleteFailure_permissions_readOnly() {
        User readOnlyUser = null;
        System.runAs(TestingUtils.ADMIN_USER) {
            readOnlyUser = TestingUtils.createUser([SELECT Id FROM Profile WHERE Name = 'Standard User'].Id);
            insert new PermissionSetAssignment(AssigneeId = readOnlyUser.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Backlog_Management_Read_Only'].Id);
        }

        setup(readOnlyUser);

        ALM_User_Role__c role1 = TestingUtils.createUserRole('Developer');

        ALM_User__c user1 = TestingUtils.createALMUser('Bill Smith');
        ALM_User__c user2 = TestingUtils.createALMUser('Sally Jones');


        Backlog_User__c backlogUser1 = new Backlog_User__c();
        backlogUser1.ALM_User__c = user1.Id;
        backlogUser1.Backlog__c = story.Id;
        backlogUser1.Role__c = role1.Id;

        Backlog_User__c backlogUser2 = new Backlog_User__c();
        backlogUser2.ALM_User__c = user2.Id;
        backlogUser2.Backlog__c = story.Id;
        backlogUser2.Role__c = role1.Id;

        insert new List<Backlog_User__c>{ backlogUser1, backlogUser2 };

        Test.startTest();

            controller.selectedAlmUserId = user1.Id;
            controller.deleteUser();
            controller.save();

        Test.stopTest();

        List<Backlog_User__c> backlogUsers = [
            SELECT Id, Backlog__c, ALM_User__c, Role__c FROM Backlog_User__c
        ];

        System.assertEquals(2, backlogUsers.size(), 'The backlog user should not have been deleted on save.');

        List<Apexpages.Message> msgs = ApexPages.getMessages();
        System.assertEquals(1, msgs.size(), 'An error message should have been added to the page.');
System.debug(msgs);
    }
    
    static testMethod void addUser() {
        setup();
        
        ALM_User__c user = TestingUtils.createALMUser('John Doe');

        String roleName = 'Developer';

        controller.selectedAlmUserId = user.Id;

        Test.startTest();

            controller.addUser();

        Test.stopTest();
        
        List<Apexpages.Message> msgs = ApexPages.getMessages();
        System.assertEquals(0, msgs.size(), 'No error should have been created');
        
        System.assertEquals(1, controller.backlogUsers.size(), 'One UserAssignment record should have been created');
    }
    
    @isTest
    private static void addUser_permissions_readOnly() {
        User readOnlyUser = null;
        System.runAs(TestingUtils.ADMIN_USER) {
            readOnlyUser = TestingUtils.createUser([SELECT Id FROM Profile WHERE Name = 'Standard User'].Id);
            insert new PermissionSetAssignment(AssigneeId = readOnlyUser.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Backlog_Management_Read_Only'].Id);
        }

        setup(readOnlyUser);
        
        ALM_User__c user = TestingUtils.createALMUser('John Doe');

        String roleName = 'Developer';

        controller.selectedAlmUserId = user.Id;

        Test.startTest();

            controller.addUser();

        Test.stopTest();
        
        List<Apexpages.Message> msgs = ApexPages.getMessages();
        System.assertEquals(1, msgs.size(), 'One error should have been created.');
System.debug(msgs);
        
        System.assertEquals(0, controller.backlogUsers.size(), 'Zero UserAssignment records should have been created.');
    }
    
    static testMethod void addUser_ALM_Exception() {
        setup();
        
        ALM_User__c user = TestingUtils.createALMUser('John Doe');

        String roleName = 'Developer';

        controller.selectedAlmUserId = null;

        Test.startTest();

            controller.addUser();

        Test.stopTest();
        
        List<Apexpages.Message> msgs = ApexPages.getMessages();
        System.assertEquals(1, msgs.size(), 'An error message should have been added to the page.');
    }
    
    static testMethod void hasErrors() {
        setup();
        
        ALM_User__c user = TestingUtils.createALMUser('John Doe');

        String roleName = 'Developer';

        controller.selectedAlmUserId = null;

        Test.startTest();

            controller.addUser();

        Test.stopTest();
        
        System.assertEquals(true, controller.hasErrors, 'An error message should have been added to the page.');
    }

}