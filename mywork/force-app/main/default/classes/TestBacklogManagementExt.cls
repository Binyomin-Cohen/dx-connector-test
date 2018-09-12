@isTest
private class TestBacklogManagementExt {

    static Custom_Backlog__c customBacklog;
    static String priorityFieldWithoutNamespace = 'Priority__c';

    static void setupViewingCustomBacklog(Boolean enabledOnCustomSetting, Boolean setupViewingCustomBacklog){
        ALMSettings__c settings = new ALMSettings__c(Enable_Custom_Backlogs__c=enabledOnCustomSetting);
        insert settings;
        if (setupViewingCustomBacklog){
            customBacklog = TestingUtils.createCustomBacklog('test backlog');

            PageReference pf = Page.BacklogManagement;
            pf.getParameters().put(BacklogManagementExt.CUSTOM_BACKLOG_ID_PARAM, customBacklog.Id);
            Test.setCurrentPageReference(pf);
        }

    }

    static testMethod void loadDefaultColumns() {

        Test.startTest();

            BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        Test.stopTest();

        Integer expectedColumnSize = BacklogItemServices.DEFAULT_COLUMNS.size();

        System.assertEquals(expectedColumnSize, backlogMgmtController.columns.size(), 'The page should be initialized to have the default columns');
    }

    static testMethod void loadCustomColumns() {
        ALM_Settings_List__c settingsList0 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn1', Value__c=SObjectServices.getFullyQualifiedName('Epic__c'), Type__c='BacklogPrioritizationColumn', Order__c=1);
        ALM_Settings_List__c settingsList1 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn2', Value__c=SObjectServices.getFullyQualifiedName('Closed_Date__c'), Type__c='BacklogPrioritizationColumn', Order__c=2);
        ALM_Settings_List__c settingsList2 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn3', Value__c=SObjectServices.getFullyQualifiedName('User_Goal__c'), Type__c='BacklogPrioritizationColumn', Order__c=3);
        insert new List<ALM_Settings_List__c> {settingsList0, settingsList1, settingsList2};

        Test.startTest();
            BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        Test.stopTest();

        Double totalColumnWidthModifier = 0.0;
        for (Column currentColumn : backlogMgmtController.columns) {
            Double width = BacklogManagementExt.COLUMN_WIDTH_MODIFIER_MAP.get(currentColumn.type.name());
            totalColumnWidthModifier += width != null ? width : BacklogManagementExt.DEFAULT_COLUMN_WIDTH_MODIFIER;
        }
        Double normalizedWidth = BacklogManagementExt.COLUMN_PERCENTAGE_WIDTH / totalColumnWidthModifier;
        Integer expectedColumnSize = BacklogItemServices.DEFAULT_COLUMNS.size() + 3;

        System.assertEquals(expectedColumnSize, backlogMgmtController.columns.size(), 'The page should be initialized to have the default columns plus one.');

        Double width = BacklogManagementExt.COLUMN_WIDTH_MODIFIER_MAP.get(Schema.DisplayType.Boolean.name());
        System.assertEquals(math.round(width * normalizedWidth), math.round(backlogMgmtController.columns[0].width), 'Epic__c column width should be set correctly.');
        width = BacklogManagementExt.COLUMN_WIDTH_MODIFIER_MAP.get(Schema.DisplayType.DateTime.name());
        System.assertEquals(math.round(width * normalizedWidth), math.round(backlogMgmtController.columns[1].width), 'Closed_Date__c column width should be set correctly.');
        width = BacklogManagementExt.COLUMN_WIDTH_MODIFIER_MAP.get(Schema.DisplayType.TextArea.name());
        System.assertEquals(math.round(width * normalizedWidth), math.round(backlogMgmtController.columns[2].width), 'User_Goal__c column width should be set correctly.');
        System.assertEquals(math.round(BacklogManagementExt.DEFAULT_COLUMN_WIDTH_MODIFIER * normalizedWidth), math.round(backlogMgmtController.columns[3].width), 'Name column width should be set as if it were a reference.');
        System.assertEquals(math.round(BacklogManagementExt.DEFAULT_COLUMN_WIDTH_MODIFIER * normalizedWidth), math.round(backlogMgmtController.columns[4].width), 'Status__c column width should be correctly defaulted.');
    }

    static testMethod void populateColumns_viewingCustomBacklog() {

        setupViewingCustomBacklog(true, true);

        ALM_Settings_List__c settingsList0 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn1', Value__c=SObjectServices.getFullyQualifiedName('Epic__c'), Type__c='BacklogPrioritizationColumn', Order__c=1);
        ALM_Settings_List__c settingsList1 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn2', Value__c=SObjectServices.getFullyQualifiedName('Closed_Date__c'), Type__c='BacklogPrioritizationColumn', Order__c=2);
        ALM_Settings_List__c settingsList2 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn3', Value__c=SObjectServices.getFullyQualifiedName('Custom_Priority__c'), Type__c='BacklogPrioritizationColumn', Order__c=3);
        insert new List<ALM_Settings_List__c> {settingsList0, settingsList1, settingsList2};

        Test.startTest();
            BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        Test.stopTest();


        Integer expectedColumnSizeWhenEnabled = BacklogItemServices.DEFAULT_COLUMNS.size() + 3;

        System.assertEquals(expectedColumnSizeWhenEnabled - 1, backlogMgmtController.columns.size(), 'The page should be initialized to have the default columns plus one.');

        Set<String> allColumnsOnPage = new Set<String>();
        for (Column c : backlogMgmtController.columns){
            allColumnsOnPage.add(c.apiName);
        }
        System.assert(!allColumnsOnPage.contains(SObjectServices.getFullyQualifiedName('Custom_Priority__c')), 'The custom priority field should be added when NOT viewing a custom backlog.');
    }

    static testMethod void populateColumns_viewingMasterBacklog() {

        setupViewingCustomBacklog(true, false);

        ALM_Settings_List__c settingsList0 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn1', Value__c=SObjectServices.getFullyQualifiedName('Epic__c'), Type__c='BacklogPrioritizationColumn', Order__c=1);
        ALM_Settings_List__c settingsList1 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn2', Value__c=SObjectServices.getFullyQualifiedName('Closed_Date__c'), Type__c='BacklogPrioritizationColumn', Order__c=2);
        ALM_Settings_List__c settingsList2 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn3', Value__c=SObjectServices.getFullyQualifiedName('Custom_Priority__c'), Type__c='BacklogPrioritizationColumn', Order__c=3);
        insert new List<ALM_Settings_List__c> {settingsList0, settingsList1, settingsList2};

        Test.startTest();
            BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        Test.stopTest();


        Integer expectedColumnSizeWhenEnabled = BacklogItemServices.DEFAULT_COLUMNS.size() + 3;

        System.assertEquals(expectedColumnSizeWhenEnabled, backlogMgmtController.columns.size(), 'The page should be initialized to have the default columns plus one.');

        Set<String> allColumnsOnPage = new Set<String>();
        for (Column c : backlogMgmtController.columns){
            allColumnsOnPage.add(c.apiName);
        }
        System.assert(allColumnsOnPage.contains(SObjectServices.getFullyQualifiedName('Custom_Priority__c')), 'The custom priority field should be added when NOT viewing a custom backlog.');
    }

    static testMethod void populateColumns_viewingMasterBacklog_notEnabled() {

        setupViewingCustomBacklog(false, false);

        ALM_Settings_List__c settingsList0 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn1', Value__c=SObjectServices.getFullyQualifiedName('Epic__c'), Type__c='BacklogPrioritizationColumn', Order__c=1);
        ALM_Settings_List__c settingsList1 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn2', Value__c=SObjectServices.getFullyQualifiedName('Closed_Date__c'), Type__c='BacklogPrioritizationColumn', Order__c=2);
        ALM_Settings_List__c settingsList2 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn3', Value__c=SObjectServices.getFullyQualifiedName('Custom_Priority__c'), Type__c='BacklogPrioritizationColumn', Order__c=3);
        insert new List<ALM_Settings_List__c> {settingsList0, settingsList1, settingsList2};

        Test.startTest();
            BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        Test.stopTest();


        Integer expectedColumnSizeWhenEnabled = BacklogItemServices.DEFAULT_COLUMNS.size() + 3;

        System.assertEquals(expectedColumnSizeWhenEnabled - 1, backlogMgmtController.columns.size(), 'The page should be initialized to have the default columns plus one.');

        Set<String> allColumnsOnPage = new Set<String>();
        for (Column c : backlogMgmtController.columns){
            allColumnsOnPage.add(c.apiName);
        }
        System.assert(!allColumnsOnPage.contains(SObjectServices.getFullyQualifiedName('Custom_Priority__c')), 'The custom priority field should be added when NOT viewing a custom backlog AND custom setting not enabled.');
    }

    static testMethod void backlogItemRow_isInSprint() {

        ALM_Settings_List__c settingsList0 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn1', Value__c=SObjectServices.getFullyQualifiedName('Current_Sprint__c'), Type__c='BacklogPrioritizationColumn', Order__c=1);
        insert new List<ALM_Settings_List__c> {settingsList0};

        Sprint__c sprint = new Sprint__c(Name = 'Test Sprint 1');
        insert sprint;

        Backlog__c notInSprint = TestingUtils.buildBacklogItem();
        notInSprint.Priority__c = 1;
        Backlog__c inSprint = TestingUtils.buildBacklogItem();
        inSprint.Priority__c = 2;
        insert new List<Backlog__c>{notInSprint, inSprint};

        List<Sprint_Item__c> sprintItems = TestingUtils.createSprintItems(sprint.Id, new List<Backlog__c>{inSprint});

        Test.startTest();

             BacklogManagementExt bklgMgmtExt = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
             bklgMgmtExt.loadBacklogItems();

        Test.stopTest();

        System.assertEquals(2, bklgMgmtExt.backlogItems.size(), 'All backlog items should be returned');
        System.assertEquals(null, bklgMgmtExt.backlogItems[0].record.Current_Sprint__c, 'Backlog items not in a sprint should be marked as such');
        System.assertNotEquals(null, bklgMgmtExt.backlogItems[1].record.Current_Sprint__c, 'Backlog items in a sprint should be marked as such');
        System.assertEquals(sprint.Name, bklgMgmtExt.backlogItems[1].record.Current_Sprint__r.Name, 'Current sprint should be set to the sprint');
    }

    static testMethod void backlogItemRow_isInSprint_latestSprint() {

        ALM_Settings_List__c settingsList0 = new ALM_Settings_List__c(Name='BacklogPrioritizationColumn1', Value__c=SObjectServices.getFullyQualifiedName('Current_Sprint__c'), Type__c='BacklogPrioritizationColumn', Order__c=1);
        insert new List<ALM_Settings_List__c> {settingsList0};

        Sprint__c sprint1 = new Sprint__c(Name = 'Test Sprint 1');
        Sprint__c sprint2 = new Sprint__c(Name = 'Test Sprint 1', Start_Date__c=Date.today());
        Sprint__c sprint3 = new Sprint__c(Name = 'Test Sprint 1', Start_Date__c=Date.today().addDays(14));
        insert new List<Sprint__c>{sprint1, sprint2, sprint3};

        Backlog__c backlogItem = TestingUtils.createBacklogItem(1);

        TestingUtils.createSprintItems(sprint1.Id, new List<Backlog__c>{backlogItem});
        TestingUtils.createSprintItems(sprint2.Id, new List<Backlog__c>{backlogItem});
        TestingUtils.createSprintItems(sprint3.Id, new List<Backlog__c>{backlogItem});

        Test.startTest();

            BacklogManagementExt bklgMgmtExt = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
            bklgMgmtExt.loadBacklogItems();

        Test.stopTest();

        System.assertNotEquals(null, bklgMgmtExt.backlogItems[0].record.Current_Sprint__c, 'Backlog items in a sprint should be marked as such');
        System.assertEquals(sprint3.Name, bklgMgmtExt.backlogItems[0].record.Current_Sprint__r.Name,
            'Current sprint should be set to the latest sprint the backog item is in.');
    }

    static testMethod void backlogItemsInitialization_allUnprioritized() {

        TestingUtils.createBacklogItem();
        TestingUtils.createBacklogItem();

        Test.startTest();

             BacklogManagementExt bklgMgmtExt = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
             bklgMgmtExt.loadBacklogItems();

        Test.stopTest();

        System.assertEquals(2, bklgMgmtExt.backlogItems.size(), 'When no items have a priority they should be treated as prioritized');
        System.assertEquals(0, bklgMgmtExt.unprioritizedBacklogItems.size(), 'When no items have a priority they should be treated as prioritized');
    }

    static testMethod void renumberBacklogItems() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> backlogItems = new List<Backlog__c>{
            TestingUtils.buildBacklogItem(3),
            TestingUtils.buildBacklogItem(5),
            TestingUtils.buildBacklogItem(1),
            TestingUtils.buildBacklogItem(10)
        };
        insert backlogItems;

        Test.startTest();

             BacklogManagementExt bklgMgmtExt = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
             bklgMgmtExt.loadBacklogItems();

        Test.stopTest();

        System.assertEquals(0, bklgMgmtExt.unprioritizedBacklogItems.size(), 'only items without a priority should be treated as prioritized');
        System.assertEquals(backlogItems.size(), bklgMgmtExt.backlogItems.size(), 'When no items have a priority they should be treated as prioritized');
        System.assertEquals(1, bklgMgmtExt.backlogItems[0].record.Priority__c, 'Backlog items should be updated to have a sequential priority');
        System.assertEquals(2, bklgMgmtExt.backlogItems[1].record.Priority__c, 'Backlog items should be updated to have a sequential priority');
        System.assertEquals(3, bklgMgmtExt.backlogItems[2].record.Priority__c, 'Backlog items should be updated to have a sequential priority');
        System.assertEquals(4, bklgMgmtExt.backlogItems[3].record.Priority__c, 'Backlog items should be updated to have a sequential priority');

        Map<Id, Backlog__c> updatedItems = new Map<Id, Backlog__c>([SELECT Id, Priority__c FROM Backlog__c WHERE Id IN :backlogItems]);
        System.assertEquals(1, updatedItems.get(backlogItems[2].Id).Priority__c, 'Backlog items should maintain their ordering.');
        System.assertEquals(2, updatedItems.get(backlogItems[0].Id).Priority__c, 'Backlog items should maintain their ordering');
        System.assertEquals(3, updatedItems.get(backlogItems[1].Id).Priority__c, 'Backlog items should maintain their ordering');
        System.assertEquals(4, updatedItems.get(backlogItems[3].Id).Priority__c, 'Backlog items should maintain their ordering');
    }

    static testMethod void renumberBacklogItems_customBacklog() {

        ALMSettings__c settings = new ALMSettings__c(Enable_Custom_Backlogs__c=true);
        insert settings;

        customBacklog = TestingUtils.createCustomBacklog('test');
        List<Backlog__c> backlogItems = new List<Backlog__c>{
            TestingUtils.buildBacklogItem(3),
            TestingUtils.buildBacklogItem(5),
            TestingUtils.buildBacklogItem(1),
            TestingUtils.buildBacklogItem(10)
        };
        for (Backlog__c bklg : backlogItems){
            bklg.Custom_Backlog__c = customBacklog.Id;
        }
        insert backlogItems;

        Map<Id, Backlog__c> originalItems = new Map<Id, Backlog__c>([SELECT Id, Custom_Priority__c, Priority__c FROM Backlog__c WHERE Id IN :backlogItems]);

        Test.startTest();

             BacklogManagementExt bklgMgmtExt = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
             bklgMgmtExt.customBacklogId = customBacklog.Id;
             bklgMgmtExt.loadBacklogItems();

        Test.stopTest();

        System.assertEquals(0, bklgMgmtExt.unprioritizedBacklogItems.size(), 'only items without a priority should be treated as prioritized');
        System.assertEquals(backlogItems.size(), bklgMgmtExt.backlogItems.size(), 'When no items have a priority they should be treated as prioritized');
        System.assertEquals(originalItems.get(bklgMgmtExt.backlogItems[0].record.Id).Priority__c, bklgMgmtExt.backlogItems[0].record.Priority__c, 'Backlog items should NOT be updated to have a sequential priority');
        System.assertEquals(originalItems.get(bklgMgmtExt.backlogItems[1].record.Id).Priority__c, bklgMgmtExt.backlogItems[1].record.Priority__c, 'Backlog items should NOT be updated to have a sequential priority');
        System.assertEquals(originalItems.get(bklgMgmtExt.backlogItems[2].record.Id).Priority__c, bklgMgmtExt.backlogItems[2].record.Priority__c, 'Backlog items should NOT be updated to have a sequential priority');
        System.assertEquals(originalItems.get(bklgMgmtExt.backlogItems[3].record.Id).Priority__c, bklgMgmtExt.backlogItems[3].record.Priority__c, 'Backlog items should NOT be updated to have a sequential priority');
        System.assertEquals(1, bklgMgmtExt.backlogItems[0].record.Custom_Priority__c, 'Backlog items should be updated to have a sequential custom priority');
        System.assertEquals(2, bklgMgmtExt.backlogItems[1].record.Custom_Priority__c, 'Backlog items should be updated to have a sequential custom priority');
        System.assertEquals(3, bklgMgmtExt.backlogItems[2].record.Custom_Priority__c, 'Backlog items should be updated to have a sequential custom priority');
        System.assertEquals(4, bklgMgmtExt.backlogItems[3].record.Custom_Priority__c, 'Backlog items should be updated to have a sequential custom priority');

        Map<Id, Backlog__c> updatedItems = new Map<Id, Backlog__c>([SELECT Id, Custom_Priority__c, Priority__c FROM Backlog__c WHERE Id IN :backlogItems]);

        System.assertEquals(originalItems.get(bklgMgmtExt.backlogItems[2].record.Id).Priority__c, updatedItems.get(backlogItems[2].Id).Priority__c, 'Backlog items should maintain their original priority.');
        System.assertEquals(originalItems.get(bklgMgmtExt.backlogItems[0].record.Id).Priority__c, updatedItems.get(backlogItems[0].Id).Priority__c, 'Backlog items should maintain their original priority');
        System.assertEquals(originalItems.get(bklgMgmtExt.backlogItems[1].record.Id).Priority__c, updatedItems.get(backlogItems[1].Id).Priority__c, 'Backlog items should maintain their original priority');
        System.assertEquals(originalItems.get(bklgMgmtExt.backlogItems[3].record.Id).Priority__c, updatedItems.get(backlogItems[3].Id).Priority__c, 'Backlog items should maintain their original priority');
        System.assertEquals(1, updatedItems.get(backlogItems[0].Id).Custom_Priority__c, 'Backlog items should maintain their ordering.');
        System.assertEquals(2, updatedItems.get(backlogItems[1].Id).Custom_Priority__c, 'Backlog items should maintain their ordering');
        System.assertEquals(3, updatedItems.get(backlogItems[2].Id).Custom_Priority__c, 'Backlog items should maintain their ordering');
        System.assertEquals(4, updatedItems.get(backlogItems[3].Id).Custom_Priority__c, 'Backlog items should maintain their ordering');
    }

    static testMethod void backlogItemsInitialization_unprioritiedItems() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        Backlog__c unprioritizedItem = TestingUtils.createBacklogItem();
        Backlog__c prioritizedItem = TestingUtils.buildBacklogItem(1);
        insert prioritizedItem;

        Test.startTest();

            BacklogManagementExt bklgMgmtExt = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
            bklgMgmtExt.loadBacklogItems();

        Test.stopTest();

        System.assertEquals(1, bklgMgmtExt.backlogItems.size(), 'prioritized items should load in the backlog items section');
        System.assertEquals(prioritizedItem.Id, bklgMgmtExt.backlogItems[0].record.Id, 'prioritized items should load in the backlog items section');
        System.assertEquals(1, bklgMgmtExt.unprioritizedBacklogItems.size(), 'Unprioritized items should load in the unprioritized items section');
        System.assertEquals(unprioritizedItem.Id, bklgMgmtExt.unprioritizedBacklogItems[0].record.Id, 'Unprioritized items should load in the unprioritized items section');
    }

    static testMethod void getBacklogItems_customBacklog_allUnprioritized(){
        ALMSettings__c settings = new ALMSettings__c(Enable_Custom_Backlogs__c=true);
        insert settings;

        customBacklog = TestingUtils.createCustomBacklog('test');
        List<Backlog__c> backlogItems = new List<Backlog__c>{
            TestingUtils.buildBacklogItem(3),
            TestingUtils.buildBacklogItem(5),
            TestingUtils.buildBacklogItem(1),
            TestingUtils.buildBacklogItem(10)
        };
        List<Backlog__c> expectedBacklogItems = new List<Backlog__c>();
        for (Integer i = 1; i < backlogItems.size(); i++){
            backlogItems[i].Custom_Backlog__c = customBacklog.Id;
            expectedBacklogItems.add(backlogItems[i]);
        }
        insert backlogItems;

        BacklogManagementExt bklgMgmtExt = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        bklgMgmtExt.customBacklogId = customBacklog.Id;

        Test.startTest();

            bklgMgmtExt.loadBacklogItems();

        Test.stopTest();

        System.assertEquals(0, bklgMgmtExt.unprioritizedBacklogItems.size(), 'only items without a priority should be treated as prioritized');
        System.assertEquals(expectedBacklogItems.size(), bklgMgmtExt.backlogItems.size(), 'only items without a priority should be treated as prioritized');
        Set<Id> expectedBacklogItemIds = Pluck.ids(expectedBacklogItems);
        for(BacklogItemRow bklgItemRow : bklgMgmtExt.backlogItems){
            System.assert(expectedBacklogItemIds.contains(bklgItemRow.record.Id),
                'We expect to get back a wrapper for each unprioritized backlog associated with the custom backlog');
        }
    }

    static testMethod void updateStatuses() {
        Backlog__c backlogItem1 = new Backlog__c(Status__c = 'old Status');
        Backlog__c backlogItem2 = new Backlog__c(Status__c = 'old Status2');

        List<Backlog__c> backlogItems = new List<Backlog__c>{ backlogItem1, backlogItem2};
        insert backlogItems;

        Test.startTest();

            String NEW_STATUS = 'new status';

            BacklogManagementExt.BacklogItem wrappedItem1 = new BacklogManagementExt.BacklogItem();
            wrappedItem1.id = backlogItem1.Id;
            wrappedItem1.status = backlogItem1.Status__c;

            BacklogManagementExt.BacklogItem wrappedItem2 = new BacklogManagementExt.BacklogItem();
            wrappedItem2.id = backlogItem2.Id;
            wrappedItem2.status = backlogItem2.Status__c;

            BacklogManagementExt.UpdateResponse response = BacklogManagementExt.updateStatuses(
                new List<BacklogManagementExt.BacklogItem>{ wrappedItem1, wrappedItem2},
                NEW_STATUS
            );

        Test.stopTest();

        System.assertEquals(true, response.isSuccess, 'The response should be successful');

        Backlog__c updateBacklogItem1 = [SELECT Id, Status__c FROM Backlog__c WHERE Id = :backlogItem1.Id];
        Backlog__c updateBacklogItem2 = [SELECT Id, Status__c FROM Backlog__c WHERE Id = :backlogItem2.Id];

        System.assertEquals(NEW_STATUS, updateBacklogItem1.Status__c, 'Status should be updated to the new value');
        System.assertEquals(NEW_STATUS, updateBacklogItem2.Status__c, 'Status should be updated to the new value');
    }

    @isTest
    private static void updateStatuses_permissions_readOnly() {
        String oldStatus = 'Old Status';
        String newStatus = 'New Status';

        User readOnlyUser = null;
        System.runAs(TestingUtils.ADMIN_USER) {
            readOnlyUser = TestingUtils.createUser([SELECT Id FROM Profile WHERE Name = 'Standard User'].Id);
            insert new PermissionSetAssignment(AssigneeId = readOnlyUser.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Backlog_Management_Read_Only'].Id);
        }

        Backlog__c backlogItem1 = new Backlog__c(Status__c = oldStatus);
        Backlog__c backlogItem2 = new Backlog__c(Status__c = oldStatus);

        List<Backlog__c> backlogItems = new List<Backlog__c>{ backlogItem1, backlogItem2};
        insert backlogItems;

        Test.startTest();

            BacklogManagementExt.BacklogItem wrappedItem1 = new BacklogManagementExt.BacklogItem();
            wrappedItem1.id = backlogItem1.Id;
            wrappedItem1.status = backlogItem1.Status__c;

            BacklogManagementExt.BacklogItem wrappedItem2 = new BacklogManagementExt.BacklogItem();
            wrappedItem2.id = backlogItem2.Id;
            wrappedItem2.status = backlogItem2.Status__c;

            BacklogManagementExt.UpdateResponse response = null;
            System.runAs(readOnlyUser) {
                response = BacklogManagementExt.updateStatuses(
                    new List<BacklogManagementExt.BacklogItem>{ wrappedItem1, wrappedItem2 },
                    newStatus
                );
            }

        Test.stopTest();

        System.assertEquals(false, response.isSuccess, 'The response should not be successful.');

        Backlog__c updateBacklogItem1 = [SELECT Id, Status__c FROM Backlog__c WHERE Id = :backlogItem1.Id];
        Backlog__c updateBacklogItem2 = [SELECT Id, Status__c FROM Backlog__c WHERE Id = :backlogItem2.Id];

        System.assertEquals(oldStatus, updateBacklogItem1.Status__c, 'Status should not be updated to the new value.');
        System.assertEquals(oldStatus, updateBacklogItem2.Status__c, 'Status should not be updated to the new value.');
    }

    static testMethod void updatePriorities_noConflicts() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        Backlog__c backlogItem1 = new Backlog__c(Priority__c = 1);
        Backlog__c backlogItem2 = new Backlog__c(Priority__c = 2);

        List<Backlog__c> backlogItems = new List<Backlog__c>{ backlogItem1, backlogItem2};
        insert backlogItems;

        Test.startTest();

            BacklogManagementExt.BacklogItem wrappedItem1 = new BacklogManagementExt.BacklogItem();
            wrappedItem1.id = backlogItem1.Id;
            wrappedItem1.priority = 100;
            wrappedItem1.oldPriority = String.valueOf(backlogItem1.Priority__c);

            BacklogManagementExt.BacklogItem wrappedItem2 = new BacklogManagementExt.BacklogItem();
            wrappedItem2.id = backlogItem2.Id;
            wrappedItem2.priority = 200;
            wrappedItem2.oldPriority = String.valueOf(backlogItem2.Priority__c);

            BacklogManagementExt.UpdateResponse response = BacklogManagementExt.updatePriorities(
                new List<BacklogManagementExt.BacklogItem>{ wrappedItem1, wrappedItem2}, false
            );

        Test.stopTest();

        System.assertEquals(true, response.isSuccess, 'The response should be successful');

        Backlog__c updateBacklogItem1 = [SELECT Id, Priority__c FROM Backlog__c WHERE Id = :backlogItem1.Id];
        Backlog__c updateBacklogItem2 = [SELECT Id, Priority__c FROM Backlog__c WHERE Id = :backlogItem2.Id];

        System.assertEquals(wrappedItem1.priority, updateBacklogItem1.Priority__c, 'Priority should be updated to the new value');
        System.assertEquals(wrappedItem2.priority, updateBacklogItem2.Priority__c, 'Priority should be updated to the new value');
    }

    @isTest
    private static void updatePriorities_noConflicts_permissions_readOnly() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        User readOnlyUser = null;
        System.runAs(TestingUtils.ADMIN_USER) {
            readOnlyUser = TestingUtils.createUser([SELECT Id FROM Profile WHERE Name = 'Standard User'].Id);
            insert new PermissionSetAssignment(AssigneeId = readOnlyUser.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Backlog_Management_Read_Only'].Id);
        }

        Integer backlogItem1Priority = 1;
        Integer backlogItem2Priority = 2;

        Backlog__c backlogItem1 = new Backlog__c(Priority__c = backlogItem1Priority);
        Backlog__c backlogItem2 = new Backlog__c(Priority__c = backlogItem2Priority);

        List<Backlog__c> backlogItems = new List<Backlog__c>{ backlogItem1, backlogItem2};
        insert backlogItems;

        Test.startTest();

            BacklogManagementExt.BacklogItem wrappedItem1 = new BacklogManagementExt.BacklogItem();
            wrappedItem1.id = backlogItem1.Id;
            wrappedItem1.priority = 100;
            wrappedItem1.oldPriority = String.valueOf(backlogItem1.Priority__c);

            BacklogManagementExt.BacklogItem wrappedItem2 = new BacklogManagementExt.BacklogItem();
            wrappedItem2.id = backlogItem2.Id;
            wrappedItem2.priority = 200;
            wrappedItem2.oldPriority = String.valueOf(backlogItem2.Priority__c);

            BacklogManagementExt.UpdateResponse response = null;
            System.runAs(readOnlyUser) {
                response = BacklogManagementExt.updatePriorities(
                    new List<BacklogManagementExt.BacklogItem>{ wrappedItem1, wrappedItem2 }, false
                );
            }

        Test.stopTest();

        System.assertEquals(false, response.isSuccess, 'The response should not be successful.');

        Backlog__c updateBacklogItem1 = [SELECT Id, Priority__c FROM Backlog__c WHERE Id = :backlogItem1.Id];
        Backlog__c updateBacklogItem2 = [SELECT Id, Priority__c FROM Backlog__c WHERE Id = :backlogItem2.Id];

        System.assertEquals(backlogItem1Priority, updateBacklogItem1.Priority__c, 'Priority should not be updated to the new value.');
        System.assertEquals(backlogItem2Priority, updateBacklogItem2.Priority__c, 'Priority should not be updated to the new value.');
    }

    static testMethod void updatePriorities_customBacklog_noConflicts() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        Backlog__c backlogItem1 = new Backlog__c(Priority__c = 1, Custom_Priority__c=9);
        Backlog__c backlogItem2 = new Backlog__c(Priority__c = 2, Custom_Priority__c=10);

        List<Backlog__c> backlogItems = new List<Backlog__c>{ backlogItem1, backlogItem2};
        insert backlogItems;

        Test.startTest();

            BacklogManagementExt.BacklogItem wrappedItem1 = new BacklogManagementExt.BacklogItem();
            wrappedItem1.id = backlogItem1.Id;
            wrappedItem1.priority = 100;
            wrappedItem1.oldPriority = String.valueOf(backlogItem1.Custom_Priority__c);

            BacklogManagementExt.BacklogItem wrappedItem2 = new BacklogManagementExt.BacklogItem();
            wrappedItem2.id = backlogItem2.Id;
            wrappedItem2.priority = 200;
            wrappedItem2.oldPriority = String.valueOf(backlogItem2.Custom_Priority__c);

            BacklogManagementExt.UpdateResponse response = BacklogManagementExt.updatePriorities(
                new List<BacklogManagementExt.BacklogItem>{ wrappedItem1, wrappedItem2}, true
            );

        Test.stopTest();

        System.assertEquals(true, response.isSuccess, 'The response should be successful');

        Backlog__c updateBacklogItem1 = [SELECT Id, Custom_Priority__c, Priority__c FROM Backlog__c WHERE Id = :backlogItem1.Id];
        Backlog__c updateBacklogItem2 = [SELECT Id, Custom_Priority__c, Priority__c FROM Backlog__c WHERE Id = :backlogItem2.Id];

        System.assertEquals(1, updateBacklogItem1.Priority__c, 'Priority should NOT be updated to the new value');
        System.assertEquals(2, updateBacklogItem2.Priority__c, 'Priority should NOT be updated to the new value');
        System.assertEquals(wrappedItem1.priority, updateBacklogItem1.Custom_Priority__c, 'Custom Priority should be updated to the new value');
        System.assertEquals(wrappedItem2.priority, updateBacklogItem2.Custom_Priority__c, 'Custom Priority should be updated to the new value');
    }

    static testMethod void updatePriorities_withConflict() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        Backlog__c backlogItem1 = new Backlog__c(Priority__c = 1);

        insert backlogItem1;

        BacklogManagementExt.BacklogItem wrappedItemWinner = new BacklogManagementExt.BacklogItem();
        wrappedItemWinner.id = backlogItem1.Id;
        wrappedItemWinner.priority = 100;
        wrappedItemWinner.oldPriority = String.valueOf(backlogItem1.Priority__c);

        BacklogManagementExt.BacklogItem wrappedItemLoser = new BacklogManagementExt.BacklogItem();
        wrappedItemLoser.id = backlogItem1.Id;
        wrappedItemLoser.priority = 200;
        wrappedItemLoser.oldPriority = String.valueOf(backlogItem1.Priority__c);

        BacklogManagementExt.updatePriorities(
            new List<BacklogManagementExt.BacklogItem>{ wrappedItemWinner}, false
        );

        Test.startTest();

        BacklogManagementExt.UpdateResponse response = BacklogManagementExt.updatePriorities(
                new List<BacklogManagementExt.BacklogItem>{ wrappedItemLoser }, false
            );

        Test.stopTest();

        System.assertEquals(false, response.isSuccess, 'The response should be fail when there is a conflict');
        System.assertEquals(BacklogManagementExt.CONFLICT_RESPONSE_CODE, response.errorCode, 'The response should be a conflict response');
        System.assert( response.errorMsg.contains( UserInfo.getName() ), 'The error message should contain the updating users name');
        System.assertEquals(1, response.recordIds.size(), 'The record Ids should be populated with all records being updated');
        System.assertEquals(wrappedItemLoser.id, response.recordIds[0], 'The record Ids should be populated with all records being updated');

        Backlog__c updatedBacklogItem = [SELECT Id, Priority__c FROM Backlog__c WHERE Id = :backlogItem1.Id];

        System.assertEquals(wrappedItemWinner.priority, updatedBacklogItem.Priority__c, 'Priority should be not be updated');
    }

    static testMethod void getFieldTypes() {
        String fieldName = 'CreatedDate';
        insert ALMSettingsServices.buildPrioritizationColumnSetting(fieldName, 1);

        Test.startTest();
            BacklogManagementExt.FieldTypeResult fieldTypeResult = BacklogManagementExt.getFieldTypes();
        Test.stopTest();

        System.assertEquals(true, fieldTypeResult.typeMap.containsKey(fieldName), 'Each configured field name should be mapped to its type');
        System.assertEquals('datetime', fieldTypeResult.typeMap.get(fieldName).toLowerCase(), 'Each configured field name should be mapped to it\'s type');

    }

    static testMethod void getPushTopicColumns(){

        Test.startTest();
            Set<String> pushTopicColumns = BacklogManagementExt.getPushTopicColumns(false);
        Test.stopTest();

        System.assert(pushTopicColumns.contains(SObjectServices.getFullyQualifiedName(priorityFieldWithoutNamespace)), 'The priority backlog field should be added to the query');
    }

    static testMethod void getPushTopicColumns_viewingCustomBacklog(){

        Test.startTest();
            Set<String> pushTopicColumns = BacklogManagementExt.getPushTopicColumns(true);
        Test.stopTest();

        System.assert(!pushTopicColumns.contains(SObjectServices.getFullyQualifiedName(priorityFieldWithoutNamespace)), 'The priority backlog field should NOT be added to the query when viewing custom backlog');
    }

    static testMethod void getPushTopic_noExistingTopics() {
        BacklogManagementExt.DEFAULT_PUSH_TOPIC_NAME = 'bm' + Datetime.now().getTime();

        Test.startTest();
            String pushTopicName = BacklogManagementExt.getPushTopic(false);
        Test.stopTest();

        List<PushTopic> topics = [SELECT Id, Name, Query, IsActive FROM PushTopic WHERE Name = :BacklogManagementExt.DEFAULT_PUSH_TOPIC_NAME];

        System.assertEquals(1, topics.size(), 'One push topic should be created when none exist');
        System.assertEquals(2, topics[0].Query.countMatches(priorityFieldWithoutNamespace), 'The priority backlog field should be added to the query when viewing the custom backlog');
    }

    static testMethod void getPushTopic_noExistingTopics_viewingCustomBacklog() {
        BacklogManagementExt.DEFAULT_PUSH_TOPIC_NAME = 'bm' + Datetime.now().getTime();
        BacklogManagementExt.CUSTOM_PUSH_TOPIC_NAME = 'bm' + Datetime.now().getTime();

        Test.startTest();
            String pushTopicName = BacklogManagementExt.getPushTopic(true);
        Test.stopTest();

        List<PushTopic> topics = [SELECT Id, Query, Name, IsActive FROM PushTopic WHERE Name = :pushTopicName];

        System.assertEquals(1, topics.size(), 'One push topic should be created when none exist');
        System.assertEquals(1, topics[0].Query.countMatches(priorityFieldWithoutNamespace), 'The priority backlog field should NOT be added to the query when viewing custom backlogs');
    }

    static testMethod void getPushTopic_existingTopics() {
        BacklogManagementExt.DEFAULT_PUSH_TOPIC_NAME = 'bm' + Datetime.now().getTime();
        PushTopic pushTopic = new PushTopic();
        pushTopic.Name = BacklogManagementExt.DEFAULT_PUSH_TOPIC_NAME;
        pushTopic.Query =  'SELECT Id, Name FROM ' + SObjectServices.getFullyQualifiedName('Backlog__c');
        pushTopic.ApiVersion = 34.0;
        insert pushTopic;

        Test.startTest();
            String pushTopicName = BacklogManagementExt.getPushTopic(false);
        Test.stopTest();

        List<PushTopic> topics = [SELECT Id, Name, IsActive, Query FROM PushTopic WHERE Name = :pushTopicName];

        System.assertEquals(1, topics.size(), 'Only one push topic should ever exist for backlog management updates');
        System.assertEquals(2, topics[0].Query.countMatches(priorityFieldWithoutNamespace), 'The priority backlog field should be added to the query when viewing the custom backlog');
    }

    static testMethod void getPushTopic_updatedTopicQuery() {
        BacklogManagementExt.DEFAULT_PUSH_TOPIC_NAME = 'bm' + Datetime.now().getTime();

        PushTopic pushTopic = new PushTopic();
        pushTopic.Name = BacklogManagementExt.DEFAULT_PUSH_TOPIC_NAME;
        pushTopic.Query =  'SELECT Id, Name FROM ' + SObjectServices.getFullyQualifiedName('Backlog__c');
        pushTopic.ApiVersion = 34.0;
        insert pushTopic;

        String expectedFieldName = 'CreatedDate';

        insert ALMSettingsServices.buildPrioritizationColumnSetting(expectedFieldName, 1);

        Test.startTest();
            String pushTopicName = BacklogManagementExt.getPushTopic(false);
        Test.stopTest();

        List<PushTopic> topics = [SELECT Id, Query FROM PushTopic WHERE Name = :pushTopicName];

        System.assertEquals(1, topics.size(), 'Only one push topic should ever exist for backlog management updates');

        System.assertEquals(true, topics[0].Query.contains(expectedFieldName), 'The new backlog field should be added to the query');
        System.assertEquals(2, topics[0].Query.countMatches(priorityFieldWithoutNamespace), 'The priority backlog field should be added to the query when viewing the custom backlog');
    }

    static testMethod void getPushTopic_updatedTopicQuery_viewingCustomBacklog() {
        BacklogManagementExt.DEFAULT_PUSH_TOPIC_NAME = 'bm' + Datetime.now().getTime();
        BacklogManagementExt.CUSTOM_PUSH_TOPIC_NAME = 'bm' + Datetime.now().getTime();

        PushTopic pushTopic = new PushTopic();
        pushTopic.Name = BacklogManagementExt.CUSTOM_PUSH_TOPIC_NAME;
        pushTopic.Query =  'SELECT Id, Name FROM ' + SObjectServices.getFullyQualifiedName('Backlog__c');
        pushTopic.ApiVersion = 34.0;
        insert pushTopic;

        String expectedFieldName = 'CreatedDate';

        insert ALMSettingsServices.buildPrioritizationColumnSetting(expectedFieldName, 1);

        Test.startTest();
            String pushTopicName = BacklogManagementExt.getPushTopic(true);
        Test.stopTest();

        List<PushTopic> topics = [SELECT Id, Query FROM PushTopic WHERE Name = :pushTopicName];

        System.assertEquals(1, topics.size(), 'Only one push topic should ever exist for backlog management updates');

        System.assertEquals(true, topics[0].Query.contains(expectedFieldName), 'The new backlog field should be added to the query');
        System.assertEquals(1, topics[0].Query.countMatches(priorityFieldWithoutNamespace), 'The priority backlog field should NOT be added to the query when viewing custom backlogs');
    }

    static testMethod void loadAdditionalItems_noItems() {
        Backlog__c backlogItem = TestingUtils.createBacklogItem(1);

        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        backlogMgmtController.loadBacklogItems();

        Test.startTest();

            backlogMgmtController.loadAdditionalItems();

        Test.stopTest();

        System.assertEquals(0, backlogMgmtController.additionalBacklogItems.size(), 'No backlog items should be loaded when there are fewer records than fit in the first page.');
    }

    static testMethod void loadAdditionalItems_noItems_recordsLoadedNotSet() {
        Backlog__c backlogItem = TestingUtils.createBacklogItem(1);

        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        backlogMgmtController.loadBacklogItems();
        backlogMgmtController.recordsLoaded = null;

        Test.startTest();

            try {
                backlogMgmtController.loadAdditionalItems();
            } catch (Exception e){
                System.assert(false, 'We expect to call loadAdditionalItems without failing if recordsLoaded has not been set yet.');
            }

        Test.stopTest();

        System.assertEquals(0, backlogMgmtController.additionalBacklogItems.size(), 'No backlog items should be loaded when there are fewer records than fit in the first page.');
    }

    static testMethod void loadAdditionalItems() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> pageOneItems = new List<Backlog__c>();
        List<Backlog__c> pageTwoItems = new List<Backlog__c>();
        for (Integer i = 1; i <= BacklogManagementExt.DEFAULT_PAGE_SIZE; i++) {
            pageOneItems.add( TestingUtils.buildBacklogItem(i) );
        }

        final Integer ITEMS_TO_LOAD = 3;
        for (Integer i = BacklogManagementExt.DEFAULT_PAGE_SIZE + 1; i <= BacklogManagementExt.DEFAULT_PAGE_SIZE + ITEMS_TO_LOAD; i++) {
            pageTwoItems.add( TestingUtils.buildBacklogItem(i) );
        }

        insert pageOneItems;
        insert pageTwoItems;

        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        backlogMgmtController.loadBacklogItems();
        Test.startTest();

            backlogMgmtController.loadAdditionalItems();

        Test.stopTest();

        System.assertEquals(ITEMS_TO_LOAD, backlogMgmtController.additionalBacklogItems.size(), 'Only items that do not fit in the first page should be loaded.');

        Map<Id, Backlog__c> additionalItemsMap = new Map<Id, Backlog__c>(pageTwoItems);

        for (BacklogItemRow row : backlogMgmtController.additionalBacklogItems) {
            System.assertEquals(true, additionalItemsMap.containsKey(row.record.Id), 'Only items that do not fit in the first page should be loaded.');
        }
    }

    static testMethod void loadAdditionalItems_renumberAdditionalItems() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        List<Backlog__c> pageOneItems = new List<Backlog__c>();
        List<Backlog__c> pageTwoItems = new List<Backlog__c>();
        for (Integer i = 1; i <= BacklogManagementExt.DEFAULT_PAGE_SIZE; i++) {
            pageOneItems.add( TestingUtils.buildBacklogItem(1) );
        }

        final Integer ITEMS_TO_LOAD = 3;
        for (Integer i = 0; i < ITEMS_TO_LOAD; i++) {
            pageTwoItems.add( TestingUtils.buildBacklogItem(2) );
        }

        insert pageOneItems;
        insert pageTwoItems;

        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        backlogMgmtController.loadBacklogItems();
        Test.startTest();

            backlogMgmtController.loadAdditionalItems();

        Test.stopTest();

        System.assertEquals(ITEMS_TO_LOAD, backlogMgmtController.additionalBacklogItems.size(), 'Only items that do not fit in the first page should be loaded.');

        Map<Id, Backlog__c> additionalItemsMap = new Map<Id, Backlog__c>(pageTwoItems);

        for (BacklogItemRow row : backlogMgmtController.additionalBacklogItems) {
            System.assertEquals(true, additionalItemsMap.containsKey(row.record.Id), 'Only items that do not fit in the first page should be loaded.');
        }
    }

    static testMethod void loadAllRemainingItems() {
        BacklogItemServices.RUN_TRIGGER_AUTO_PRIORITIZE = false;

        BacklogManagementExt.DEFAULT_PAGE_SIZE = 1;
        BacklogManagementExt.MAX_RECORD_COUNT = 2;
        final Integer REMAINING_ITEMS_COUNT = 2;

        List<Backlog__c> pageOneItems = new List<Backlog__c>();
        List<Backlog__c> remainingItems = new List<Backlog__c>();
        for (Integer i = 1; i <= BacklogManagementExt.MAX_RECORD_COUNT; i++) {
            pageOneItems.add( TestingUtils.buildBacklogItem(1) );
        }

        for (Integer i = 0; i < REMAINING_ITEMS_COUNT; i++) {
            remainingItems.add( TestingUtils.buildBacklogItem(999) );
        }

        insert pageOneItems;
        insert remainingItems;

        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        backlogMgmtController.loadBacklogItems();
        backlogMgmtController.loadAdditionalItems();

        Test.startTest();

            backlogMgmtController.loadAllRemainingItems();

        Test.stopTest();

        System.assertEquals(REMAINING_ITEMS_COUNT, backlogMgmtController.additionalBacklogItems.size(), 'Only items that have not been loaded should be loaded.');

        Map<Id, Backlog__c> additionalItemsMap = new Map<Id, Backlog__c>(remainingItems);

        for (BacklogItemRow row : backlogMgmtController.additionalBacklogItems) {
            System.assertEquals(true, additionalItemsMap.containsKey(row.record.Id), 'Only items that have not been loaded should be loaded.');
        }
    }

    static testMethod void totalPrioritizedItemsDisplay_under_limit() {
        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        Test.startTest();

            backlogMgmtController.totalPrioritizedItems = 3;

        Test.stopTest();

        System.assertEquals('3', backlogMgmtController.totalPrioritizedItemsDisplay, 'The display should be correctly calculated');
    }

    static testMethod void totalPrioritizedItemsDisplay_just_under_limit() {
        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        Integer queryRowsMinusOne = Limits.getLimitQueryRows() - 1;
        Test.startTest();

            backlogMgmtController.totalPrioritizedItems = queryRowsMinusOne;

        Test.stopTest();

        System.assertEquals(queryRowsMinusOne.format(), backlogMgmtController.totalPrioritizedItemsDisplay, 'The display should be correctly calculated');
    }

    static testMethod void totalPrioritizedItemsDisplay_at_limit() {
        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        Integer queryRowsLimit = Limits.getLimitQueryRows();
        Test.startTest();

            backlogMgmtController.totalPrioritizedItems = queryRowsLimit;

        Test.stopTest();

        System.assertEquals(queryRowsLimit.format() + '+', backlogMgmtController.totalPrioritizedItemsDisplay, 'The display should be correctly calculated');
    }

    static testMethod void totalPrioritizedItemsDisplay_over_limit() {
        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        Integer queryRowsLimitPlusOne = Limits.getLimitQueryRows() + 1;
        Test.startTest();

            backlogMgmtController.totalPrioritizedItems = queryRowsLimitPlusOne;

        Test.stopTest();

        System.assertEquals(Limits.getLimitQueryRows().format() + '+', backlogMgmtController.totalPrioritizedItemsDisplay, 'The display should be correctly calculated');
    }

    static testMethod void loadSpecificItems() {
        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        backlogMgmtController.loadBacklogItems();
        backlogMgmtController.loadAdditionalItems();

        List<Backlog__c> items = new List<Backlog__c>{TestingUtils.buildBacklogItem(1), TestingUtils.buildBacklogItem(2), TestingUtils.buildBacklogItem(3)};
        insert items;

        Test.startTest();

            backlogMgmtController.totalPrioritizedItems = 3;
            backlogMgmtController.recordsToLoad = items[0].Id + ',' + items[1].Id;
            backlogMgmtController.loadSpecificItems();

        Test.stopTest();

        System.assertEquals(2, backlogMgmtController.additionalBacklogItems.size(), 'Only items specified should be loaded.');
        System.assertEquals(items[0].Id, backlogMgmtController.additionalBacklogItems[0].record.Id, 'Specified items should be loaded in order.');
        System.assertEquals(items[1].Id, backlogMgmtController.additionalBacklogItems[1].record.Id, 'Specified items should be loaded in order.');
    }

    static testMethod void loadSpecificItems_invalidIds() {
        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        backlogMgmtController.loadBacklogItems();
        backlogMgmtController.loadAdditionalItems();

        List<Backlog__c> items = new List<Backlog__c>{TestingUtils.buildBacklogItem(1), TestingUtils.buildBacklogItem(2), TestingUtils.buildBacklogItem(3)};
        insert items;

        Test.startTest();

            backlogMgmtController.totalPrioritizedItems = 3;
            backlogMgmtController.recordsToLoad = 'zzz';
            backlogMgmtController.loadSpecificItems();

        Test.stopTest();

        System.assertEquals(0, backlogMgmtController.additionalBacklogItems.size(), 'No items should be loaded when there is an invalid search string.');
    }

    static testMethod void loadSpecificItems_recordAlreadyloaded() {
        Backlog__c alreadyLoadedItem = TestingUtils.createBacklogItem(3);

        BacklogManagementExt backlogMgmtController =
            new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        backlogMgmtController.loadBacklogItems();
        backlogMgmtController.loadAdditionalItems();

        List<Backlog__c> items = new List<Backlog__c>{TestingUtils.buildBacklogItem(1), TestingUtils.buildBacklogItem(2)};
        insert items;

        Test.startTest();

            backlogMgmtController.totalPrioritizedItems = 3;
            backlogMgmtController.recordsToLoad = alreadyLoadedItem.Id + ',' + items[0].Id;
            backlogMgmtController.loadSpecificItems();

        Test.stopTest();

        System.assertEquals(1, backlogMgmtController.additionalBacklogItems.size(), 'Items that have been loaded should not be loaded again.');
        System.assertEquals(items[0].Id, backlogMgmtController.additionalBacklogItems[0].record.Id, 'Items that have been loaded should not be loaded again.');
    }

    static testMethod void getReferenceResults_noQuery() {

        Test.startTest();
            try {
                Set<String> matchingBacklogNames = BacklogManagementExt.getReferenceResults('User_Story__c', '');
                System.assert(false, 'An error should have been thrown requiring a minumum length.');
            } catch (ALMException e){
                System.assert(true, 'We expect to get back an error.');
            }

        Test.stopTest();

    }

    static testMethod void getReferenceResults_withQuery() {
        final Integer NUM_OF_PROJECTS = 20;

        List<Project__c> projects = TestingUtils.createProjects(NUM_OF_PROJECTS);

        Test.startTest();

            Set<String> matchingBacklogNames = BacklogManagementExt.getReferenceResults('Project__c', 'ect_1');

        Test.stopTest();

        System.assertEquals(11, matchingBacklogNames.size(), 'Project names should have been found.');
    }

    static testMethod void getReferenceResults_withSpecificQuery() {
        final Integer NUM_OF_PROJECTS = 10;

        List<Project__c> projects = TestingUtils.createProjects(NUM_OF_PROJECTS);

        Test.startTest();

            Set<String> matchingBacklogNames = BacklogManagementExt.getReferenceResults('Project__c', 'PROJECT_2');

        Test.stopTest();

        System.assertEquals(1, matchingBacklogNames.size(), 'Project names should have been found.');
    }

    static testMethod void getReferenceResults_withNoMatches() {
        final Integer NUM_OF_PROJECTS = 10;

        List<Project__c> projects = TestingUtils.createProjects(NUM_OF_PROJECTS);

        Test.startTest();

            Set<String> matchingBacklogNames = BacklogManagementExt.getReferenceResults('Project__c', 'QWERTY');

        Test.stopTest();

        System.assertEquals(0, matchingBacklogNames.size(), 'No project names should have been found.');
    }

    static testMethod void getReferenceResults_withContainsQuery() {
        final Integer NUM_OF_PROJECTS = 10;

        List<Project__c> projects = TestingUtils.createProjects(NUM_OF_PROJECTS);

        Test.startTest();

            Set<String> matchingBacklogNames = BacklogManagementExt.getReferenceResults('Project__c', 'ject');

        Test.stopTest();

        System.assertEquals(NUM_OF_PROJECTS, matchingBacklogNames.size(), 'Project names should have been found.');
    }

    static testMethod void viewingCustomBacklog_noParameter(){

        ALMSettings__c settings = new ALMSettings__c(Enable_Custom_Backlogs__c=true);
        insert settings;

        Test.startTest();
            BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        Test.stopTest();

        System.assertEquals(false, backlogMgmtController.viewingCustomBacklog,
            'When no Backlog ID parameter is passed into the controller, we expect viewingCustomBacklog to be false.');

    }

    static testMethod void viewingCustomBacklog_withParameter(){

        setupViewingCustomBacklog(true, true);

        Test.startTest();
            BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        Test.stopTest();

        System.assertEquals(true, backlogMgmtController.viewingCustomBacklog,
            'When no Backlog ID parameter is passed into the controller, we expect viewingCustomBacklog to be true.');

    }

    static testMethod void viewingCustomBacklog_withParameter_notEnabled(){

        setupViewingCustomBacklog(false, false);

        Test.startTest();
            BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        Test.stopTest();

        System.assertEquals(false, backlogMgmtController.viewingCustomBacklog,
            'When no Backlog ID parameter is passed into the controller AND custom setting is false, we expect viewingCustomBacklog to be false.');

    }

    static testMethod void backlogPageRedirect_noRedirect() {
        ALMSettings__c settings = new ALMSettings__c(Enable_Custom_Backlogs__c=false);
        insert settings;

        BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        Test.startTest();
            PageReference actual = backlogMgmtController.backlogPageRedirect();
        Test.stopTest();

        PageReference expected = null;
        System.assertEquals(expected, actual, 'When custom backlog feature is disabled, there should be no redirect');
    }

    static testMethod void backlogPageRedirect_redirect() {
        ALMSettings__c settings = new ALMSettings__c(Enable_Custom_Backlogs__c=true);
        insert settings;

        BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        Test.startTest();
            PageReference actual = backlogMgmtController.backlogPageRedirect();
        Test.stopTest();

        System.assertEquals(true, actual.getUrl().endsWith('BacklogManagementHome'),
          'When custom backlog feature is enabled and a default custom backlog is set, a redirect should occur');
    }

    static testMethod void customBacklogId_backlogParameterSet() {
        setupViewingCustomBacklog(true, true);

        Test.startTest();
            BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        Test.stopTest();

        System.assertEquals(customBacklog.Id, backlogMgmtController.customBacklogId,
          'customBacklogId property should be set with the backlogid parameter value in the url');
    }

    static testMethod void customBacklogId_noBacklogParameterSet() {
        ALMSettings__c settings = new ALMSettings__c(Enable_Custom_Backlogs__c=true);
        insert settings;

        String expectedId = TestingUtils.createFakeSObjectId(Custom_Backlog__c.SObjectType);
        User_Preferences__c preference = new User_Preferences__c();
        preference.SetupOwnerId = UserInfo.getUserId();
        preference.Default_Custom_Backlog_Id__c = expectedId;

        insert preference;

        Test.startTest();
            BacklogManagementExt backlogMgmtController =
                new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        Test.stopTest();

        System.assertEquals(expectedId, backlogMgmtController.customBacklogId,
          'customBacklogId property should be set with the Default_Custom_Backlog_Id__c value in the custom setting');
    }

    private static void createBacklogAutoPrioritizationConfiguration(String expectedAutoPrioritizationBehavior, Id backlogId) {
        String configurationName = 'Universal';
        Id configurationBacklogId = BacklogItemServices.UNIVERSAL_BACKLOG_ID;

        if (backlogId != null) {
            configurationName = 'Custom_' + backlogId;
            configurationBacklogId = backlogId;
        }

        Backlog_Auto_Prioritization__c backlogAutoPrioritizationConfiguration = new Backlog_Auto_Prioritization__c(
            Name = configurationName,
            Backlog_ID__c = configurationBacklogId,
            Prioritization_Behavior__c = expectedAutoPrioritizationBehavior
        );
        insert backlogAutoPrioritizationConfiguration;
    }

    private static testMethod void getBacklogAutoPrioritizationBehavior_universal_customBacklogsDefault() {
        String expectedAutoPrioritizationBehavior = 'TOP';

        createBacklogAutoPrioritizationConfiguration(expectedAutoPrioritizationBehavior, null);

        BacklogManagementExt controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        Test.startTest();

            controller.getBacklogAutoPrioritizationBehavior();

        Test.stopTest();

        System.assertEquals(
            expectedAutoPrioritizationBehavior,
            controller.autoPrioritizationBehavior,
            'The proper auto-prioritization behavior should be set.'
        );
    }

    private static testMethod void getBacklogAutoPrioritizationBehavior_universal_customBacklogsOff() {
        String expectedAutoPrioritizationBehavior = 'TOP';

        insert new ALMSettings__c(Enable_Custom_Backlogs__c = false);
        createBacklogAutoPrioritizationConfiguration(expectedAutoPrioritizationBehavior, null);

        BacklogManagementExt controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));

        Test.startTest();

            controller.getBacklogAutoPrioritizationBehavior();

        Test.stopTest();

        System.assertEquals(
            expectedAutoPrioritizationBehavior,
            controller.autoPrioritizationBehavior,
            'The proper auto-prioritization behavior should be set.'
        );
    }

    private static testMethod void getBacklogAutoPrioritizationBehavior_universal_customBacklogsOn() {
        String expectedAutoPrioritizationBehavior = 'TOP';

        insert new ALMSettings__c(Enable_Custom_Backlogs__c = true);
        createBacklogAutoPrioritizationConfiguration(expectedAutoPrioritizationBehavior, null);

        BacklogManagementExt controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        controller.customBacklogId = BacklogManagementHomeController.MASTER_BACKLOG_IDENTIFIER;

        Test.startTest();

            controller.getBacklogAutoPrioritizationBehavior();

        Test.stopTest();

        System.assertEquals(
            expectedAutoPrioritizationBehavior,
            controller.autoPrioritizationBehavior,
            'The proper auto-prioritization behavior should be set.'
        );
    }

    private static testMethod void getBacklogAutoPrioritizationBehavior_custom() {
        String expectedAutoPrioritizationBehavior = 'TOP';

        insert new ALMSettings__c(Enable_Custom_Backlogs__c = true);
        Custom_Backlog__c backlog = TestingUtils.createCustomBacklog('Test Custom Backlog');
        createBacklogAutoPrioritizationConfiguration(expectedAutoPrioritizationBehavior, backlog.Id);

        BacklogManagementExt controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        controller.customBacklogId = backlog.Id;

        Test.startTest();

            controller.getBacklogAutoPrioritizationBehavior();

        Test.stopTest();

        System.assertEquals(
            expectedAutoPrioritizationBehavior,
            controller.autoPrioritizationBehavior,
            'The proper auto-prioritization behavior should be set.'
        );
    }

    private static void assertSetBacklogAutoPrioritizationConfiguration(String expectedAutoPrioritizationBehavior, Id backlogId) {
        String configurationName = 'Universal';
        Id configurationBacklogId = BacklogItemServices.UNIVERSAL_BACKLOG_ID;

        if (backlogId != null) {
            configurationName = 'Custom_' + backlogId;
            configurationBacklogId = backlogId;
        }

        Backlog_Auto_Prioritization__c actualBacklogAutoPrioritizationConfiguration = [
            SELECT Prioritization_Behavior__c
            FROM Backlog_Auto_Prioritization__c
            WHERE Name = :configurationName AND Backlog_ID__c = :configurationBacklogId
        ];

        System.assertEquals(
            expectedAutoPrioritizationBehavior,
            actualBacklogAutoPrioritizationConfiguration.Prioritization_Behavior__c,
            'The proper auto-prioritization behavior should be set.'
        );
    }

    private static testMethod void setBacklogAutoPrioritizationBehavior_universal_customBacklogsDefault() {
        String expectedAutoPrioritizationBehavior = 'TOP';

        BacklogManagementExt controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        controller.autoPrioritizationBehavior = expectedAutoPrioritizationBehavior;

        Test.startTest();

            controller.setBacklogAutoPrioritizationBehavior();

        Test.stopTest();

        assertSetBacklogAutoPrioritizationConfiguration(expectedAutoPrioritizationBehavior, null);
    }

    @isTest
    private static void setBacklogAutoPrioritizationBehavior_universal_customBacklogsDefault_permissions_readOnly() {
        User readOnlyUser = null;
        System.runAs(TestingUtils.ADMIN_USER) {
            readOnlyUser = TestingUtils.createUser([SELECT Id FROM Profile WHERE Name = 'Standard User'].Id);
            insert new PermissionSetAssignment(AssigneeId = readOnlyUser.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Backlog_Management_Read_Only'].Id);
        }

        String autoPrioritizationBehavior = 'TOP';

        BacklogManagementExt controller;
        System.runAs(readOnlyUser) {
            controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        }
        controller.autoPrioritizationBehavior = autoPrioritizationBehavior;

        Test.startTest();

            controller.setBacklogAutoPrioritizationBehavior();

        Test.stopTest();

        List<Backlog_Auto_Prioritization__c> actualBacklogAutoPrioritizationConfigurations = [
            SELECT Prioritization_Behavior__c
            FROM Backlog_Auto_Prioritization__c
            WHERE Name = 'Universal' AND Backlog_ID__c = :BacklogItemServices.UNIVERSAL_BACKLOG_ID
        ];

        System.assert(actualBacklogAutoPrioritizationConfigurations.isEmpty(), 'No auto-prioritization behavior should be set.');
    }

    private static testMethod void setBacklogAutoPrioritizationBehavior_universal_customBacklogsOff() {
        String expectedAutoPrioritizationBehavior = 'TOP';

        insert new ALMSettings__c(Enable_Custom_Backlogs__c = false);

        BacklogManagementExt controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        controller.autoPrioritizationBehavior = expectedAutoPrioritizationBehavior;

        Test.startTest();

            controller.setBacklogAutoPrioritizationBehavior();

        Test.stopTest();

        assertSetBacklogAutoPrioritizationConfiguration(expectedAutoPrioritizationBehavior, null);
    }

    private static testMethod void setBacklogAutoPrioritizationBehavior_universal_customBacklogsOn() {
        String expectedAutoPrioritizationBehavior = 'TOP';

        insert new ALMSettings__c(Enable_Custom_Backlogs__c = true);

        BacklogManagementExt controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        controller.customBacklogId = BacklogManagementHomeController.MASTER_BACKLOG_IDENTIFIER;
        controller.autoPrioritizationBehavior = expectedAutoPrioritizationBehavior;

        Test.startTest();

            controller.setBacklogAutoPrioritizationBehavior();

        Test.stopTest();

        assertSetBacklogAutoPrioritizationConfiguration(expectedAutoPrioritizationBehavior, null);
    }

    private static testMethod void setBacklogAutoPrioritizationBehavior_custom() {
        String expectedAutoPrioritizationBehavior = 'TOP';

        insert new ALMSettings__c(Enable_Custom_Backlogs__c = true);

        Custom_Backlog__c backlog = TestingUtils.createCustomBacklog('Test Custom Backlog');

        BacklogManagementExt controller = new BacklogManagementExt(new ApexPages.StandardSetController(new List<Backlog__c>()));
        controller.customBacklogId = backlog.Id;
        controller.autoPrioritizationBehavior = expectedAutoPrioritizationBehavior;

        Test.startTest();

            controller.setBacklogAutoPrioritizationBehavior();

        Test.stopTest();

        assertSetBacklogAutoPrioritizationConfiguration(expectedAutoPrioritizationBehavior, backlog.Id);
    }
}