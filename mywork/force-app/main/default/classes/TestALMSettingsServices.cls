@isTest
private class TestALMSettingsServices {

    static testMethod void getAvailableComponentUsersSettings() {
        List<ALM_Settings_List__c> settings = new List<ALM_Settings_List__c>();
        settings.add(ALMSettingsServices.buildAvailableComponentUsersSetting('Steve', 2));
        settings.add(ALMSettingsServices.buildAvailableComponentUsersSetting('Janis', 1));
        settings.add(ALMSettingsServices.buildAvailableComponentUsersSetting('Bob', 0));

        System.runAs(TestingUtils.ADMIN_USER) {
            insert settings;
        }

        Test.startTest();

            List<ALM_Settings_List__c> returnedSettings = ALMSettingsServices.getAvailableComponentUsersSettings();

        Test.stopTest();

        System.assertEquals(settings[2].Value__c, returnedSettings[0].Value__c,
             'Available users settings should be returned in order');
        System.assertEquals(settings[1].Value__c, returnedSettings[1].Value__c,
             'Available users settings should be returned in order');
        System.assertEquals(settings[0].Value__c, returnedSettings[2].Value__c,
             'Available users settings should be returned in order');
    }

    static testMethod void bulkInsertNewUserSettings() {
        String NEW_USER = 'Steve';
        List<ALM_Settings_List__c> existingUsers = new List<ALM_Settings_List__c>();
        existingUsers.add(ALMSettingsServices.buildAvailableComponentUsersSetting('Bob', 0));
        existingUsers.add(ALMSettingsServices.buildAvailableComponentUsersSetting('Janis', 1));

        System.runAs(TestingUtils.ADMIN_USER) {
            insert existingUsers;
        }

        Set<String> usersToAdd = new Set<String>{NEW_USER, 'Janis'};

        Test.startTest();

            ALMSettingsServices.bulkInsertNewComponentUserSettings(usersToAdd);

        Test.stopTest();

        List<ALM_Settings_List__c> returnedSettings = ALMSettingsServices.getAvailableComponentUsersSettings();

        System.assertEquals(3, returnedSettings.size(), 'New users should be created without duplication');

        System.assertEquals(existingUsers[0].Value__c, returnedSettings[0].Value__c,
                'Existing Users should still be returned');
        System.assertEquals(existingUsers[1].Value__c, returnedSettings[1].Value__c,
                'Existing Users should still be returned');
        System.assertEquals(NEW_USER, returnedSettings[2].Value__c,
                'The new user should be created as a setting');
    }
}