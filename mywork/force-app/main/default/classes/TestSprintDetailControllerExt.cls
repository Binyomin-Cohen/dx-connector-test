@isTest
private class TestSprintDetailControllerExt {
    static Sprint__c sprint;

    static SprintDetailControllerExt controller;

    static void setup() {
        sprint = new Sprint__c(Name='Test Sprint');
        insert sprint;

        List<Backlog__c> backlogs = new List<Backlog__c>();

        backlogs.add(createBacklog(1, 0));
        backlogs.add(createBacklog(2, 5));
        backlogs.add(createBacklog(3, 10));

        insert backlogs;

        List<Sprint_Item__c> sprintItems = TestingUtils.createSprintItems(sprint.Id, backlogs);

        ApexPages.StandardController sc = new ApexPages.StandardController(sprint);
        controller = new SprintDetailControllerExt(sc);
    }

    static testMethod void calculateDevEffortAndBusinessValue() {
        setup();

        Test.startTest();
            Integer actualDevEffort = controller.calculateDevEffort();
            Integer acutalBusinessValue = controller.calculateBuisnessValue();
        Test.stopTest();

        Integer EXPECTED_DEV_EFFORT = 6;
        Integer EXPECTED_BUSINESS_VALUE = 15;

        System.assertEquals(EXPECTED_DEV_EFFORT, actualDevEffort, 'The Dev Effort should match the sum of all the backlog dev efforts');
        System.assertEquals(EXPECTED_BUSINESS_VALUE, acutalBusinessValue, 'The Business Value should match the sum of all the backlog business values');
    }

    static testMethod void calculateDevEffortAndBusinessValue_withNulls() {
        sprint = new Sprint__c(Name='Test Sprint');
        insert sprint;

        Integer EXPECTED_DEV_EFFORT = 1;
        Integer EXPECTED_BUSINESS_VALUE = 2;

        List<Backlog__c> backlogs = new List<Backlog__c>();

        backlogs.add(createBacklog(EXPECTED_DEV_EFFORT,
                                   EXPECTED_BUSINESS_VALUE));

        backlogs.add(createBacklog(null, null));

        insert backlogs;

        List<Sprint_Item__c> sprintItems = TestingUtils.createSprintItems(sprint.Id, backlogs);

        ApexPages.StandardController sc = new ApexPages.StandardController(sprint);
        controller = new SprintDetailControllerExt(sc);

        Test.startTest();
            Integer actualDevEffort = controller.calculateDevEffort();
            Integer acutalBusinessValue = controller.calculateBuisnessValue();
        Test.stopTest();


        System.assertEquals(EXPECTED_DEV_EFFORT, actualDevEffort, 'The Dev Effort should match the sum of all the backlog dev efforts');
        System.assertEquals(EXPECTED_BUSINESS_VALUE, acutalBusinessValue, 'The Business Value should match the sum of all the backlog business values');
    }

    static testMethod void updateSprint() {
        setup();

        String expectedStatus = 'In-Progress';
        controller.model.status = expectedStatus;

        Test.startTest();
            controller.updateSprint();
        Test.stopTest();

        Sprint__c  s = [Select Id, Status__c From Sprint__c where Id =: sprint.Id];
        System.assertEquals(expectedStatus, s.Status__c, 'The sprint status should have been updated.');
    }

    static testMethod void updateSprint_datesResetAfterValidation() {

        sprint = new Sprint__c(Name='Test Sprint');

        sprint.Start_Date__c = Date.today();
        sprint.End_Date__c = Date.today().addDays(7);
        insert sprint;

        controller = new SprintDetailControllerExt( new ApexPages.StandardController(sprint) );

        Test.startTest();
            controller.sprintStartDate = String.valueOf(sprint.End_Date__c.addDays(1));
            controller.updateSprint();
        Test.stopTest();

        System.assertEquals(String.valueOf(sprint.Start_Date__c), controller.sprintStartDate, 'The sprint date should be reset when trying to save an invalid value.');
    }

    static testMethod void updateSprintItemStatus() {
        insert new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('New', 0),
            ALMSettingsServices.buildSprintLaneSetting('Open', 1),
            ALMSettingsServices.buildSprintLaneSetting('In-Progress', 2),
            ALMSettingsServices.buildSprintLaneSetting('Dev Complete', 3),
            ALMSettingsServices.buildSprintLaneSetting('Released', 4)
        };

        sprint = new Sprint__c(Name='Test Sprint');
        insert sprint;

        String status = 'In-Progress';
        Backlog__c bklg = TestingUtils.buildBacklogItem();
        bklg.Status__c = 'New';
        insert bklg;

        Sprint_Item__c sprintItem = TestingUtils.createSprintItems(sprint.Id, new List<Backlog__c>{bklg})[0];

        Test.startTest();

            SprintDetailControllerExt.updateSprintItemStatus(sprintItem.Id, status);

        Test.stopTest();

        bklg = [SELECT Id, Status__c FROM Backlog__c WHERE Id = :bklg.Id];
        sprintItem = [SELECT Id, Status__c FROM Sprint_Item__c WHERE Id = :sprintItem.Id];

        System.assertEquals(status, sprintItem.Status__c, 'The sprint item status should have been updated.');
    }

    static testMethod void updateSprintItemStatus_notStarted() {
        sprint = new Sprint__c(Name='Test Sprint');
        insert sprint;

        String initialStatus = 'In-Progress';
        Backlog__c bklg = TestingUtils.buildBacklogItem();
        bklg.Status__c = initialStatus;
        insert bklg;

        Sprint_Item__c sprintItem = TestingUtils.createSprintItems(sprint.Id, new List<Backlog__c>{bklg}, initialStatus)[0];

        Test.startTest();

            SprintDetailControllerExt.updateSprintItemStatus(sprintItem.Id, SprintModel.NOT_STARTED_STATUS);

        Test.stopTest();

        bklg = [SELECT Id, Status__c FROM Backlog__c WHERE Id = :bklg.Id];
        sprintItem = [SELECT Id, Status__c FROM Sprint_Item__c WHERE Id = :sprintItem.Id];

        System.assertEquals(SprintModel.NOT_STARTED_STATUS, sprintItem.Status__c, 'The sprint item status should have been updated.');

    }

    static testMethod void initSprintLanes() {
        setup();

        System.assertEquals(1, controller.sprintLanes.size(), 'The page should have the Not Started column.');
        System.assertEquals(SprintModel.NOT_STARTED_STATUS, controller.sprintLanes[0].status, 'The page should have the Not Started column.');
    }

    static testMethod void initSprintLanes_multipleColumns() {
        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('A', 0),
            ALMSettingsServices.buildSprintLaneSetting('B', 1),
            ALMSettingsServices.buildSprintLaneSetting('C', 2)
        };

        insert settings;

        setup();

        System.assertEquals(settings.size() + 1, controller.sprintLanes.size(), 'The page should have all configured columns plus Not Started.');
        System.assertEquals(SprintModel.NOT_STARTED_STATUS, controller.sprintLanes[0].status, 'The page should have the Not Started column first.');
        System.assertEquals(settings[0].Value__c, controller.sprintLanes[1].status, 'The page should have all configured columns in order.');
        System.assertEquals(settings[1].Value__c, controller.sprintLanes[2].status, 'The page should have all configured columns in order.');
        System.assertEquals(settings[2].Value__c, controller.sprintLanes[3].status, 'The page should have all configured columns in order.');
    }

    static testMethod void initSprintLanes_sprintItemsInFirstColumn() {
        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('A', 0),
            ALMSettingsServices.buildSprintLaneSetting('B', 1),
            ALMSettingsServices.buildSprintLaneSetting('C', 2)
        };

        insert settings;

        List<Backlog__c> bklgs = new List<Backlog__c> {
            TestingUtils.buildBacklogItem(settings[0].Value__c),
            TestingUtils.buildBacklogItem(settings[1].Value__c),
            TestingUtils.buildBacklogItem(settings[2].Value__c)
        };
        insert bklgs;

        sprint = new Sprint__c();
        insert sprint;

        List<Sprint_Item__c> sprintItems = TestingUtils.createSprintItems(sprint.Id, bklgs);

        Test.startTest();

            ApexPages.StandardController sc = new ApexPages.StandardController(sprint);
            controller = new SprintDetailControllerExt(sc);

        Test.stopTest();

        System.assertEquals(bklgs.size(), controller.sprintLanes[0].totalItems, 'All sprint items should be loaded in the Not Started column.');
        for (Integer i = 1; i < controller.sprintLanes.size(); ++i) {
            System.assertEquals(0, controller.sprintLanes[i].totalItems, 'No sprint items should be loaded in other columns.');
        }
    }

    static testMethod void initSprintLanes_sprintItemsInColumns() {
        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c> {
            ALMSettingsServices.buildSprintLaneSetting('A', 0),
            ALMSettingsServices.buildSprintLaneSetting('B', 1),
            ALMSettingsServices.buildSprintLaneSetting('C', 2)
        };

        insert settings;

        List<Backlog__c> bklgs = new List<Backlog__c> {
            TestingUtils.buildBacklogItem(settings[0].Value__c),
            TestingUtils.buildBacklogItem(settings[1].Value__c),
            TestingUtils.buildBacklogItem(settings[2].Value__c)
        };
        insert bklgs;

        sprint = new Sprint__c();
        insert sprint;

        List<Sprint_Item__c> sprintItems = TestingUtils.buildSprintItems(sprint.Id, bklgs);
        for (Integer i = 0; i < sprintItems.size(); ++i) {
            sprintItems[i].Status__c = settings[i].Value__c;
        }
        insert sprintItems;

        Test.startTest();

            ApexPages.StandardController sc = new ApexPages.StandardController(sprint);
            controller = new SprintDetailControllerExt(sc);

        Test.stopTest();

        System.assertEquals(0, controller.sprintLanes[0].totalItems, 'No sprint items should be loaded in the Not Started column.');
        for (Integer i = 1; i < controller.sprintLanes.size(); ++i) {
            System.assertEquals(1, controller.sprintLanes[i].totalItems, 'Sprint items should load in the column matching their staus');
        }
    }

    static testMethod void updateBacklogs() {
        Release__c release = new Release__c(Name='Test Release');
        insert release;

        setup();

        controller.releaseId = release.Id;

        Test.startTest();
            controller.updateBacklogs();
        Test.stopTest();

        for (Sprint_Item__c si : [Select Backlog__r.Release__c From Sprint_Item__c Where Sprint__c = :sprint.Id]) {
            System.assertEquals(release.Id, si.Backlog__r.Release__c, 'Each backlog should have a release associated to it.');
        }
    }

    static testMethod void getReleases() {
        String[] expected = new String[]{'r1', 'r2'};
        Release__c r1 = new Release__c(Name = expected[0]);
        Release__c r2 = new Release__c(Name = expected[1]);
        insert new Release__c[]{r1, r2};

        Test.startTest();
            List<Release__c> releases = SprintDetailControllerExt.getReleases('');
            System.assertEquals(expected.size(), releases.size(), 'All matching release names should be returned.');

            releases = SprintDetailControllerExt.getReleases('r');
            System.assertEquals(expected.size(), releases.size(), 'All matching release names should be returned.');
            System.assertEquals(expected[0], releases[0].Name, 'All matching release names should be returned.');
            System.assertEquals(expected[1], releases[1].Name, 'All matching release names should be returned.');

            releases = SprintDetailControllerExt.getReleases('r1');
            System.assertEquals(1, releases.size(), 'All matching release names should be returned.');
            System.assertEquals(expected[0], releases[0].Name, 'All matching release names should be returned.');
        Test.stopTest();
    }

    private static Backlog__c createBacklog(Integer devEffort, Integer businessValue) {
        return new Backlog__c(Dev_Effort__c = (Decimal) devEffort, Business_Value__c = (Decimal) businessValue);
    }

    static testMethod void sprintUserInitialization_noBacklogUsers() {
        ALM_User__c user = TestingUtils.createALMUser('John Smith');
        ALM_User_Role__c role = TestingUtils.createUserRole('Developer');
        sprint = new Sprint__c(Name = 'Test Sprint 1');
        insert sprint;
        Sprint_User__c sprintUser = new Sprint_User__c(ALM_User__c = user.Id, Sprint__c = sprint.Id, Role__c = role.Id);
        insert sprintUser;
        Test.startTest();
            SprintDetailControllerExt ext = new SprintDetailControllerExt(new ApexPages.StandardController(sprint));
        Test.stopTest();
        System.assertEquals(1, ext.sprintUsers.size(), 'All sprint users should be populated.');
        System.assertEquals(''+user.Id, ext.sprintUsers[0].almUserId, 'All sprint users should be populated.');
        System.assertEquals(''+role.Id, ext.sprintUsers[0].role, 'The user role should be populated.');
    }

    static testMethod void sprintUserInitialization_backlogUsers() {
        ALM_User__c user = TestingUtils.createALMUser('John Smith');
        ALM_User_Role__c role = TestingUtils.createUserRole('Developer');
        sprint = new Sprint__c(Name = 'Test Sprint 1');
        insert sprint;
        Sprint_User__c sprintUser = new Sprint_User__c(ALM_User__c = user.Id, Sprint__c = sprint.Id, Role__c = role.Id);
        insert sprintUser;
        Backlog__c bklg1 = TestingUtils.createBacklogItem();
        Backlog__c bklg2 = TestingUtils.createBacklogItem();
        Backlog_User__c bklgUser = new Backlog_User__c(ALM_User__c = user.Id, Backlog__c = bklg1.Id, Role__c = role.Id);
        insert bklgUser;
        List<Sprint_Item__c> sprintItems = TestingUtils.createSprintItems(sprint.Id, new List<Backlog__c>{bklg1, bklg2});
        Sprint_Item__c sprintItem1 = sprintItems[0];
        Sprint_Item__c sprintItem2 = sprintItems[1];
        Test.startTest();
            SprintDetailControllerExt ext = new SprintDetailControllerExt(new ApexPages.StandardController(sprint));
        Test.stopTest();
        System.assertEquals(1, ext.usersBySprintItem.size(), 'All sprint items with users should be populated.');
        List<UserAssignment> sprintItem1Users = ext.usersBySprintItem.get(''+sprintItem1.Id);
        System.assertEquals(1, sprintItem1Users.size(), 'All backlog users should be populated.');
        System.assertEquals(''+user.Id, sprintItem1Users[0].almUserId, 'All sprint users should be populated.');
        System.assertEquals(''+role.Id, sprintItem1Users[0].role, 'The user role should be populated.');
    }

    static testMethod void assignUser_sprintItemUser() {
        ALM_User__c user = TestingUtils.createALMUser('John Smith');
        ALM_User_Role__c role = TestingUtils.createUserRole('Developer');
        sprint = new Sprint__c(Name = 'Test Sprint 1');
        insert sprint;

        Backlog__c item = TestingUtils.createBacklogItem();
        List<Sprint_Item__c> sprintItems = TestingUtils.createSprintItems(sprint.Id, new List<Backlog__c>{item});
        Sprint_Item__c sprintItem = sprintItems[0];

        Test.startTest();

            String itemUserId = SprintDetailControllerExt.assignUser(sprintItem.Id, user.Id, role.Id);

        Test.stopTest();

        Backlog_User__c backlogUser = [
            SELECT Id, Backlog__c, ALM_User__c, Role__c
             FROM Backlog_User__c
              WHERE Id =:itemUserId
        ];

        System.assertEquals(item.Id, backlogUser.Backlog__c, 'The backlog item should be set when creating a user for a sprint item');
        System.assertEquals(user.Id, backlogUser.ALM_User__c, 'The alm user should be set when creating a user for a sprint item');
        System.assertEquals(role.Id, backlogUser.Role__c, 'The user role should be set when creating a user for a sprint item');
    }

    static testMethod void assignUser_duplicateSprintItemUser() {
        ALM_User__c user = TestingUtils.createALMUser('John Smith');
        ALM_User_Role__c role = TestingUtils.createUserRole('Developer');
        sprint = new Sprint__c(Name = 'Test Sprint 1');
        insert sprint;

        Backlog__c item = TestingUtils.createBacklogItem();
        List<Sprint_Item__c> sprintItems = TestingUtils.createSprintItems(sprint.Id, new List<Backlog__c>{item});
        Sprint_Item__c sprintItem = sprintItems[0];

        SprintDetailControllerExt.assignUser(sprintItem.Id, user.Id, role.Id);
        Test.startTest();

            try {
                SprintDetailControllerExt.assignUser(sprintItem.Id, user.Id, role.Id);
                System.assert(false, 'Duplicates user assignments should not be created.');
            } catch(Exception ex) {

                System.assert(ex instanceof ALMException, 'An ALMException should be thrown when trying to create a duplicate assignment');
            }

        Test.stopTest();

        List<Backlog_User__c> backlogUsers = [ SELECT Id FROM Backlog_User__c];
        System.assertEquals(1, backlogUsers.size(), 'Duplicate user creation requests should be ignored');
    }

    static testMethod void assignUser_invalidSprintItem() {

        Backlog__c item = TestingUtils.createBacklogItem();

        Test.startTest();

            try {
		        SprintDetailControllerExt.assignUser(item.Id, null, null);
                System.assert(false, 'User assignments should not be created for invalid sprint items.');
            } catch(Exception ex) {

                System.assert(ex instanceof ALMException, 'An ALMException should be thrown when trying to create a assignment for an invalid sprint item');
            }

        Test.stopTest();

        List<Backlog_User__c> backlogUsers = [ SELECT Id FROM Backlog_User__c];
        System.assertEquals(0, backlogUsers.size(), 'No user assignments should be created for invalid sprint items');
    }

    static testMethod void deleteSprintItemUser() {
        ALM_User__c user = TestingUtils.createALMUser('John Smith');
        ALM_User__c userToDelete = TestingUtils.createALMUser('Delete Me');
        ALM_User_Role__c role = TestingUtils.createUserRole('Developer');
        sprint = new Sprint__c(Name = 'Test Sprint 1');
        insert sprint;
        Sprint_User__c sprintUser1 = new Sprint_User__c(ALM_User__c = user.Id, Sprint__c = sprint.Id, Role__c = role.Id);
        Sprint_User__c sprintUser2 = new Sprint_User__c(ALM_User__c = userToDelete.Id, Sprint__c = sprint.Id, Role__c = role.Id);
        insert  new List<Sprint_User__c>{sprintUser1, sprintUser2};

        Backlog__c bklg1 = TestingUtils.createBacklogItem();
        Backlog_User__c bklgUser = new Backlog_User__c(ALM_User__c = user.Id, Backlog__c = bklg1.Id, Role__c = role.Id);
        Backlog_User__c bklgUserToDelete = new Backlog_User__c(ALM_User__c = userToDelete.Id, Backlog__c = bklg1.Id, Role__c = role.Id);
        insert new List<Backlog_User__c>{bklgUser, bklgUserToDelete};

        List<Sprint_Item__c> sprintItems = TestingUtils.createSprintItems(sprint.Id, new List<Backlog__c>{bklg1});
        Sprint_Item__c sprintItem1 = sprintItems[0];
        Test.startTest();

        List<UserAssignment> users =
            SprintDetailControllerExt.deleteSprintItemUser(sprint.Id, bklgUserToDelete.Id, sprintItem1.Id);

        Test.stopTest();

        System.assertEquals(1, users.size(), 'Remaining backlog users should be returned');
        System.assertEquals(users[0].record.Id, bklgUser.Id, 'Remaining backlog users should be returned');
    }

    static testMethod void sprintUserInitialization_excludeBacklogUsersWithoutSprintUsers() {
        ALM_User__c user = TestingUtils.createALMUser('John Smith');
        ALM_User_Role__c role = TestingUtils.createUserRole('Developer');
        sprint = new Sprint__c(Name = 'Test Sprint 1');
        insert sprint;
        Backlog__c bklg = TestingUtils.createBacklogItem();
        Backlog_User__c bklgUser = new Backlog_User__c(ALM_User__c = user.Id, Backlog__c = bklg.Id, Role__c = role.Id);
        insert bklgUser;
        List<Sprint_Item__c> sprintItems = TestingUtils.createSprintItems(sprint.Id, new List<Backlog__c>{bklg});
        Sprint_Item__c sprintItem = sprintItems[0];
        Test.startTest();
            SprintDetailControllerExt ext = new SprintDetailControllerExt(new ApexPages.StandardController(sprint));
        Test.stopTest();
        System.assert(!ext.sprintLanes[0].sprintItems[0].hasUsers,
                'Backlog users without sprint users should not be displayed.');
    }
}