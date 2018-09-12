@isTest
private class TestComponentTrigger {

    static testMethod void populateModifiedUsersTriggerOnComponentInsert() {
        List<String> usernames = new List<String>{'Target User', 'Target User2'};
        Component__c component = createTestComponentWithFieldModifiedData(usernames);

        Test.startTest();
            insert component;
        Test.stopTest();

        Component__c insertedComponent = [
            SELECT Id, Last_Modified_Users__c
            FROM Component__c
            WHERE Id = :component.Id
        ];

        assertComponentLastModifiedUserFieldContainsOnlySpecifiedUsers(insertedComponent, usernames);
        assertALMSettingsUsersContainsOnlySpecifiedUsers(usernames);
    }

    static testMethod void populateModifiedUsersTriggerOnComponentUpdate() {
        // create a component, then insert it.
        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c component = TestingUtils.buildComponent('Test trigger', 'Trigger', instance.Id);
        insert component;

        // modify inserted component's FieldModifiedData, then update.
        List<String> usernames = new List<String>{'Target User', 'Target User2'};

        FieldModifiedData lastModifiedData0 = new FieldModifiedData(instance.Name, null, usernames[0], null, 'somebody');
        FieldModifiedData lastModifiedData1 = new FieldModifiedData(instance.Name, null, usernames[1], null, 'somebody');

        component.Field_Modified_Data__c = JSON.serialize(new List<FieldModifiedData>{
            lastModifiedData0, lastModifiedData1});

        Test.startTest();
            update component;
        Test.stopTest();

        // Query for the updated component, and assert that Last_Modified_Users__c has been set correctly.
        Component__c updatedComponent = [
            SELECT Id, Last_Modified_Users__c
            FROM Component__c
            WHERE Id = :component.Id
        ];

        assertComponentLastModifiedUserFieldContainsOnlySpecifiedUsers(updatedComponent, usernames);
        assertALMSettingsUsersContainsOnlySpecifiedUsers(usernames);
    }

    static testMethod void doNotPopulateModifiedUsersWhenFieldModifiedDataUnchanged() {
        Component__c component = createTestComponentWithFieldModifiedData(new List<String>{'Target User', 'Target User2'});

        insert component;

        // change Last_Modified_Users__c, and insert.
        // This should not cause Last_Modified_Users__c to be reset by the trigger on update.
        String MANUALLY_SET_USERS = 'Steve;Bob';
        component.Last_Modified_Users__c = MANUALLY_SET_USERS;

        // Delete the ALM Settings Users so that we can later assert that they haven't been recreated by the trigger
        List<ALM_Settings_List__c> returnedSettings = ALMSettingsServices.getAvailableComponentUsersSettings();
        delete returnedSettings;

        Test.startTest();
            update component;
        Test.stopTest();

        Component__c updatedComponent = [
            SELECT Id, Last_Modified_Users__c
            FROM Component__c
            WHERE Id = :component.Id
        ];

        System.assertEquals(MANUALLY_SET_USERS, updatedComponent.Last_Modified_Users__c,
                'updatedComponent.Last_Modified_Users__c should not have been changed by component update');

        returnedSettings = ALMSettingsServices.getAvailableComponentUsersSettings();
        System.assertEquals(0, returnedSettings.size(), 'User Settings should not have been recreated by the trigger');
    }

    static Component__c createTestComponentWithFieldModifiedData(List<String> usernames) {
        Instances__c instance = TestingUtils.createInstance('dev');
        Component__c component = TestingUtils.buildComponent('Test trigger', 'Trigger', instance.Id);

        List<FieldModifiedData> fieldModifiedDataList = new List<FieldModifiedData>();
        for (String username : usernames) {
            fieldModifiedDataList.add(new FieldModifiedData(instance.Name, null, username, null, 'somebody'));
        }

        component.Field_Modified_Data__c = JSON.serialize(fieldModifiedDataList);
        return component;
    }

    static void assertComponentLastModifiedUserFieldContainsOnlySpecifiedUsers(Component__c component, List<String> usernames) {
        Set<String> lastModifiedUsers = new Set<String>(component.Last_Modified_Users__c.split(';'));

        System.assertEquals(usernames.size(), lastModifiedUsers.size(), 'Last_Modified_Users__c should contain correct number of usernames');

        for (String username : usernames) {
            System.assert(lastModifiedUsers.contains(username), 'Last_Modified_Users__c should contain ' + username);
        }
    }

    static void assertALMSettingsUsersContainsOnlySpecifiedUsers(List<String> usernames) {
        Set<String> uniqueUsernames = new Set<String>(usernames);
        List<ALM_Settings_List__c> returnedSettings = ALMSettingsServices.getAvailableComponentUsersSettings();

        System.assertEquals(uniqueUsernames.size(), returnedSettings.size(), 'New users settings should be created');

        for (ALM_Settings_List__c setting : returnedSettings) {
            System.assert(uniqueUsernames.contains(setting.Value__c), 'Last_Modified_Users__c should contain ' + setting);
        }
    }
}