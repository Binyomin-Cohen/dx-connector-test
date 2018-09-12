@isTest
private class TestBacklogManagementHomeController {

    static String commonCustomBacklogName = 'z_test';
    static Custom_Backlog__c customBacklog;
    static Custom_Backlog__c customBacklog2;
    private static User readOnlyUser;

    private static void setup(){
        customBacklog = TestingUtils.createCustomBacklog(commonCustomBacklogName);
        customBacklog2 = TestingUtils.createCustomBacklog('a_test2');

        System.runAs(TestingUtils.ADMIN_USER) {
            readOnlyUser = TestingUtils.createUser([SELECT Id FROM Profile WHERE Name = 'Standard User'].Id);
            insert new PermissionSetAssignment(AssigneeId = readOnlyUser.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Backlog_Management_Read_Only'].Id);
        }

        insert new ALMSettings__c(Enable_Custom_Backlogs__c = true);
    }

    public static testMethod void getAllCustomBacklogs() {
        setup();

        Integer unprioritizedNumForB1 = 17;
        Integer prioritizedNumForB1 = 6;
        Integer unprioritizedNumForB2 = 13;
        Integer prioritizedNumForB2 = 8;

        List<Backlog__c> unprioritizedB1 = TestingUtils.buildBacklogItems(unprioritizedNumForB1);
        for(Backlog__c bItem: unprioritizedB1) {
            setPriorityAndBacklog(bItem, null, customBacklog.Id);
        }

        List<Backlog__c> prioritizedB1 = TestingUtils.buildBacklogItems(prioritizedNumForB1);
        for(Integer i= 0; i < prioritizedB1.size(); i++) {
            setPriorityAndBacklog(prioritizedB1[i], i, customBacklog.Id);
        }

        List<Backlog__c> unprioritizedB2 = TestingUtils.buildBacklogItems(unprioritizedNumForB2);
        for(Backlog__c bItem: unprioritizedB2) {
            setPriorityAndBacklog(bItem, null, customBacklog2.Id);
        }

        List<Backlog__c> prioritizedB2 = TestingUtils.buildBacklogItems(prioritizedNumForB2);
        for(Integer i= 0; i < prioritizedB2.size(); i++) {
            setPriorityAndBacklog(prioritizedB2[i], i, customBacklog2.Id);
        }


        List<Backlog__c> masterList = new List<Backlog__c>();
        masterList.addAll(unprioritizedB1);
        masterList.addAll(prioritizedB1);
        masterList.addAll(unprioritizedB2);
        masterList.addAll(prioritizedB2);
        insert masterList;

        Test.startTest();
            List<CustomBacklogModel> results = BacklogManagementHomeController.getAllCustomBacklogs();
        Test.stopTest();

        System.assertEquals(2, results.size(), 'We expect to get back all current custom backlogs.');
        System.assertEquals(customBacklog2.Id, results[0].customBacklogId, 'We expect to get the custom backlogs in alphabetical order.');
        System.assertEquals(customBacklog.Id, results[1].customBacklogId, 'We expect to get the custom backlogs in alphabetical order.');

        CustomBacklogModel b2 = results[0];
        CustomBacklogModel b1 = results[1];
        System.assertEquals(String.valueOf(unprioritizedNumForB2 + prioritizedNumForB2), b2.totalItems, 'total items should be correct');
        System.assertEquals(String.valueOf(unprioritizedNumForB2), b2.unprioritizedItems, 'unprioritized items should be correct');
        System.assertEquals(String.valueOf(unprioritizedNumForB1 + prioritizedNumForB1), b1.totalItems, 'total items should be correct');
        System.assertEquals(String.valueOf(unprioritizedNumForB1), b1.unprioritizedItems, 'unprioritized items should be correct');

    }

    public static testMethod void getAllCustomBacklogs_withSavedState() {
        setup();

        List<String> sortedCustomBacklogIds = new List<String> { customBacklog.Id, customBacklog2.Id };
        CustomBacklogServices.CustomBacklogSort sortState = new CustomBacklogServices.CustomBacklogSort(sortedCustomBacklogIds);
        State.store(sortState);

        Test.startTest();
            List<CustomBacklogModel> sortedCustomBacklogs = BacklogManagementHomeController.getAllCustomBacklogs();
        Test.stopTest();

        System.assertEquals(sortedCustomBacklogIds.size(), sortedCustomBacklogs.size(),
                'We expect the getAllCustomBacklogs to load all backlogs based on the state\'s storted order.');

        for (Integer k = 0; k < sortedCustomBacklogs.size(); k++) {
            System.assertEquals(sortedCustomBacklogIds[k], sortedCustomBacklogs[k].customBacklogId,
                    'The returned backlogs should be sorted in order.');
        }
    }

    public static void setPriorityAndBacklog(Backlog__c backlogItem, Integer priority, Id backlog) {
        backlogItem.custom_priority__c = priority;
        backlogItem.custom_backlog__c = backlog;
    }

    public static testMethod void testCreateCustomBacklog(){
        insert new ALMSettings__c(Enable_Custom_Backlogs__c = true);

        String newCustomBacklogName = 'new_custom_name';

        Test.startTest();
            BacklogManagementHomeController.UpsertCustomBacklogResponse result =
                    BacklogManagementHomeController.createCustomBacklog(newCustomBacklogName);
        Test.stopTest();

        List<Custom_Backlog__c> availCustomBacklogs = [Select Id, Name from Custom_Backlog__c];

        System.assertEquals(1, availCustomBacklogs.size(), 'We expect the creation of a new custom backlog.');
        System.assertEquals(true, result.isSuccess, 'We expect to get back successful creation of a new custom backlog.');
        System.assertEquals(true, result.isValid, 'We expect to get back valid custom backlog name flag');
        System.assert(String.isEmpty(result.errorMsg), 'We expect no error messages on successful creation of a new custom backlog.');
        System.assertEquals(availCustomBacklogs[0].Id, result.customBacklogId, 'We expect the custom backlog id to be populated.');
    }

    public static testMethod void testUpdateCustomBacklog(){

        setup();

        String newCustomBacklogName = 'new_custom_name';

        Test.startTest();
            BacklogManagementHomeController.UpsertCustomBacklogResponse result =
                    BacklogManagementHomeController.updateCustomBacklog(customBacklog2.Id, newCustomBacklogName);
        Test.stopTest();

        Map<Id, Custom_Backlog__c> availCustomBacklogMap = new Map<Id, Custom_Backlog__c>([Select Id, Name from Custom_Backlog__c]);

        System.assertEquals(2, availCustomBacklogMap.keySet().size(), 'We expect the same number of custom backlogs to exist.');
        System.assertEquals(true, result.isSuccess, 'We expect to get back successful creation of a new custom backlog.');
        System.assertEquals(true, result.isValid, 'We expect to get back valid custom backlog name flag');
        System.assert(String.isEmpty(result.errorMsg), 'We expect no error messages on successful creation of a new custom backlog.');
        System.assertEquals(customBacklog2.Id, result.customBacklogId, 'We expect the custom backlog id to be populated.');
        System.assertEquals(availCustomBacklogMap.get(result.customBacklogId).Name, newCustomBacklogName,
            'We expect the custom backlog name to be updated.');
    }

    public static testMethod void testUpdateCustomBacklog_invalidId(){

        setup();

        String newCustomBacklogName = 'new_custom_name';

        Test.startTest();
            BacklogManagementHomeController.UpsertCustomBacklogResponse result =
                    BacklogManagementHomeController.updateCustomBacklog('some_invalid_id', newCustomBacklogName);
        Test.stopTest();

        Map<Id, Custom_Backlog__c> availCustomBacklogMap = new Map<Id, Custom_Backlog__c>([Select Id, Name from Custom_Backlog__c]);

        System.assertEquals(2, availCustomBacklogMap.keySet().size(), 'We expect the same number of custom backlogs to exist.');
        System.assertEquals(false, result.isSuccess, 'We expect to get back failed creation of a new custom backlog.');
        System.assertEquals(true, result.isValid, 'We expect to get back valid custom backlog name flag');
        System.assert(String.isNotEmpty(result.errorMsg), 'We expect error messages on failed creation of a new custom backlog.');
        System.assert(String.isEmpty(result.customBacklogId), 'We expect the custom backlog id to not be populated.');
    }

    public static testMethod void setGlobalBacklogCounts() {
        final String INACTIVE_STATUS = 'Released';
        final String ACTIVE_STATUS = 'Dev ready';
        final Integer TOTAL_COUNT = 6;

        ALMSettings__c settings = new ALMSettings__c();
        settings.Inactive_Backlog_Statuses_1__c = INACTIVE_STATUS;
        System.runAs( TestingUtils.ADMIN_USER ) {
            insert settings;
        }
        List<Integer> priorityValues = new List<Integer>();
        for(Integer i = 0; i < TOTAL_COUNT / 2; i++ ) {
            priorityValues.add(i);
        }

        UnitTest.addData(TestingUtils.buildBacklogItems(TOTAL_COUNT))
            .tag('All Backlog Items');

        UnitTest.get('All Backlog Items')
            .divide(2)
                .part('Prioritized Backlog Items')
                .part('UnPrioritized Backlog Items');

        UnitTest.get('Prioritized Backlog Items')
            .property('Priority__c')
                .assignFrom(priorityValues);

        UnitTest.get('Prioritized Backlog Items')
            .divide(2)
                .part('Prioritized Active Status')
                .part('Prioritized InActive Status');

        UnitTest.get('UnPrioritized Backlog Items')
            .divide(2)
                .part('UnPrioritized Active Status')
                .part('UnPrioritized InActive Status');

        UnitTest.get('UnPrioritized Active Status')
            .property('Status__c')
                .assign(ACTIVE_STATUS);

        UnitTest.get('UnPrioritized InActive Status')
            .property('Status__c')
                .assign(INACTIVE_STATUS);

        UnitTest.get('Prioritized Active Status')
            .property('Status__c')
                .assign(ACTIVE_STATUS);

        UnitTest.get('Prioritized InActive Status')
            .property('Status__c')
                .assign(INACTIVE_STATUS);

        UnitTest.get(Backlog__c.SObjectType).insertAll();
        Test.startTest();
            CustomBacklogModel testModel = new CustomBacklogModel(new Custom_Backlog__c());
            BacklogManagementHomeController.setGlobalBacklogCounts(testModel);
        Test.stopTest();

        System.assertEquals(String.valueOf(UnitTest.getIds('UnPrioritized Active Status').size()), testModel.unprioritizedItems,
            'The unprioritized count on the global backlog should be set correctly');
        System.assertEquals(String.valueOf(UnitTest.getIds('Prioritized Active Status').size() + UnitTest.getIds('UnPrioritized Active Status').size()), testModel.totalItems,
            'The total count on the global backlog should be set correctly');
    }

    public static testMethod void testCreateCustomBacklog_duplicateExist() {

        setup();

        Test.startTest();
            BacklogManagementHomeController.UpsertCustomBacklogResponse result =
                    BacklogManagementHomeController.createCustomBacklog(commonCustomBacklogName);
        Test.stopTest();

        List<Custom_Backlog__c> availCustomBacklogs = [Select Id, Name from Custom_Backlog__c];

        System.assertEquals(2, availCustomBacklogs.size(), 'We do not expect net new custom backlogs to be created.');
        System.assertEquals(false, result.isSuccess, 'We expect to get back failed creation of a new custom backlog.');
        System.assertEquals(false, result.isValid, 'We expect to get back invalid custom backlog name flag');
        System.assert(String.isNotEmpty(result.errorMsg), 'We expect error messages on failed creation of a new custom backlog.');
        System.assert(String.isEmpty(result.customBacklogId), 'We do not expect the custom backlog id to be populated on failed creation.');
    }

    @isTest
    private static void createCustomBacklog_permissions_readOnly() {
        System.runAs(TestingUtils.ADMIN_USER) {
            readOnlyUser = TestingUtils.createUser([SELECT Id FROM Profile WHERE Name = 'Standard User'].Id);
            insert new PermissionSetAssignment(AssigneeId = readOnlyUser.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Backlog_Management_Read_Only'].Id);
        }

        Test.startTest();
            BacklogManagementHomeController.UpsertCustomBacklogResponse result = null;
            System.runAs(readOnlyUser) {
                result = BacklogManagementHomeController.createCustomBacklog(commonCustomBacklogName);
            }
        Test.stopTest();

        List<Custom_Backlog__c> availableCustomBacklogs = [Select Id, Name from Custom_Backlog__c];

        System.assertEquals(0, availableCustomBacklogs.size(), 'We do not expect a new custom backlog to be created.');
        System.assertEquals(false, result.isSuccess, 'We expect to get back failed creation of a new custom backlog.');
        System.assertEquals(System.Label.Permissions_Error, result.errorMsg, 'We expect error messages on failed creation of a new custom backlog.');
    }

    public static testMethod void testUpdateCustomBacklog_duplicateExist() {

        setup();

        Test.startTest();
            BacklogManagementHomeController.UpsertCustomBacklogResponse result =
                    BacklogManagementHomeController.updateCustomBacklog(customBacklog2.Id, commonCustomBacklogName);
        Test.stopTest();

        List<Custom_Backlog__c> availCustomBacklogs = [Select Id, Name from Custom_Backlog__c];

        System.assertEquals(2, availCustomBacklogs.size(), 'We do not expect net new custom backlogs to be created.');
        System.assertEquals(false, result.isSuccess, 'We expect to get back failed creation of a new custom backlog.');
        System.assertEquals(false, result.isValid, 'We expect to get back invalid custom backlog name flag');
        System.assert(String.isNotEmpty(result.errorMsg), 'We expect error messages on failed creation of a new custom backlog.');
        System.assert(String.isEmpty(result.customBacklogId), 'We do not expect the custom backlog id to be populated on failed creation.');
    }

    @isTest
    private static void updateCustomBacklog_permissions_readOnly() {
        String oldCustomBacklogName = 'Old Custom Backlog Name';
        customBacklog = TestingUtils.createCustomBacklog(oldCustomBacklogName);

        System.runAs(TestingUtils.ADMIN_USER) {
            readOnlyUser = TestingUtils.createUser([SELECT Id FROM Profile WHERE Name = 'Standard User'].Id);
            insert new PermissionSetAssignment(AssigneeId = readOnlyUser.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Backlog_Management_Read_Only'].Id);
        }

        Test.startTest();
            BacklogManagementHomeController.UpsertCustomBacklogResponse result = null;
            System.runAs(readOnlyUser) {
                result = BacklogManagementHomeController.updateCustomBacklog(customBacklog.Id, 'New Custom Backlog Name');
            }
        Test.stopTest();

        List<Custom_Backlog__c> availableCustomBacklogs = [Select Id, Name from Custom_Backlog__c];

        System.assertEquals(1, availableCustomBacklogs.size(), 'We do not expect new custom backlogs to be created.');
        System.assertEquals(false, result.isSuccess, 'We expect to get back failed creation of a new custom backlog.');
        System.assertEquals(System.Label.Permissions_Error, result.errorMsg, 'We expect error messages on failed creation of a new custom backlog.');
        System.assertEquals(oldCustomBacklogName, availableCustomBacklogs[0].Name, 'We do not expect the custom backlog name to have changed.');
    }

    @isTest
    private static void updateUserPreferences() {
        setup();

        Id backlogId = TestingUtils.createFakeSObjectId(Custom_Backlog__c.SObjectType);

        Test.startTest();

            BacklogManagementHomeController.updateUserPreferences(backlogId);

        Test.stopTest();

        User_Preferences__c userPreferences = User_Preferences__c.getInstance(UserInfo.getUserId());
        System.assertEquals(backlogId, userPreferences.Default_Custom_Backlog_ID__c, 'The default custom backlog ID should be updated.');
    }

    @isTest
    private static void updateUserPreferences_permissions_readOnly() {
        setup();

        Test.startTest();

            System.runAs(readOnlyUser) {
                BacklogManagementHomeController.updateUserPreferences(TestingUtils.createFakeSObjectId(Custom_Backlog__c.SObjectType));
            }

        Test.stopTest();

        User_Preferences__c userPreferences = User_Preferences__c.getInstance(UserInfo.getUserId());
        System.assertEquals(null, userPreferences.Default_Custom_Backlog_ID__c, 'The default custom backlog ID should not be updated.');
    }

    public static testMethod void updateUserSpecificSortState() {
        setup();

        Test.startTest();
            BacklogManagementHomeController.updateUserSpecificSortState( customBacklog.Id + ',' + customBacklog2.Id );
        Test.stopTest();

        CustomBacklogServices.CustomBacklogSort customBacklogSort =
                new CustomBacklogServices.CustomBacklogSort();

        try {
            State.retrieve(customBacklogSort);
        } catch (State.StateException se) {
            System.assert(false, 'No exception should have been caught');
        }

        List<String> sortedCustomBacklogs = customBacklogSort.getIds();

        System.assertEquals(2, sortedCustomBacklogs.size(),
                'There should be two custom backlogs returned.');
        System.assertEquals(customBacklog.Id, sortedCustomBacklogs[0],
                'The custom backlog id in the first position should match.');
        System.assertEquals(customBacklog2.Id, sortedCustomBacklogs[1],
                'The custom backlog id in the second position should match.');
    }

    @isTest
    private static void updateUserSpecificSortState_permissions_readOnly() {
        setup();

        BacklogManagementHomeController.updateUserSpecificSortState(customBacklog2.Id);

        Test.startTest();

            System.runAs(readOnlyUser) {
                BacklogManagementHomeController.updateUserSpecificSortState( customBacklog.Id + ',' + customBacklog2.Id );
            }
        Test.stopTest();

        CustomBacklogServices.CustomBacklogSort customBacklogSort =
                new CustomBacklogServices.CustomBacklogSort();

        try {
            State.retrieve(customBacklogSort);
        } catch (State.StateException se) {
            System.assert(false, 'No exception should have been caught');
        }

        List<String> sortedCustomBacklogs = customBacklogSort.getIds();

        System.assertEquals(1, sortedCustomBacklogs.size(), 'There should be one custom backlog returned.');
        System.assertEquals(customBacklog2.Id, sortedCustomBacklogs[0], 'The custom backlog ID should match.');
    }
}