@isTest
private class TestPopulateALMSettings {
    @isTest
    static void populateCustomSettingEnableMultipleBacklogs_noRecordExists() {
        Test.startTest();
            PopulateALMSettings.populateCustomSettingEnableMultipleBacklogs();
        Test.stopTest();
        ALMSettings__c actualSetting = ALMSettings__c.getOrgDefaults();
        System.assertNotEquals(null, actualSetting, 'A settings record should be returned');
        System.assert(actualSetting.Enable_Custom_Backlogs__c, 'Multiple backlogs should be enabled');
        System.assertNotEquals(null, actualSetting.Id, 'The setting should be a newly created record');
    }

    @isTest
    static void populateCustomSettingEnableMultipleBacklogs_recordExistsFalse() {
        ALMSettings__c existingSetting = ALMSettings__c.getOrgDefaults();
        insert existingSetting;

        Test.startTest();
            PopulateALMSettings.populateCustomSettingEnableMultipleBacklogs();
        Test.stopTest();
        ALMSettings__c actualSetting = ALMSettings__c.getOrgDefaults();
        System.assertNotEquals(null, actualSetting, 'A settings record should be returned');
        System.assert(actualSetting.Enable_Custom_Backlogs__c, 'Multiple backlogs should be enabled');
        System.assertEquals(existingSetting.Id, actualSetting.Id, 'The setting should be the existing record');
    }

    @isTest
    static void populateCustomSettingEnableMultipleBacklogs_recordExistsTrue() {
        ALMSettings__c existingSetting = ALMSettings__c.getOrgDefaults();
        existingSetting.Enable_Custom_Backlogs__c = true;
        insert existingSetting;
        Integer dmlStatmentsCalledBefore = Limits.getDMLStatements();

        Test.startTest();
            PopulateALMSettings.populateCustomSettingEnableMultipleBacklogs();
        Test.stopTest();

        Integer dmlStatmentsCalledAfter = Limits.getDMLStatements();
        ALMSettings__c actualSetting = ALMSettings__c.getOrgDefaults();
        System.assertNotEquals(null, actualSetting, 'A settings record should be returned');
        System.assert(actualSetting.Enable_Custom_Backlogs__c, 'Multiple backlogs should be enabled');
        System.assertEquals(existingSetting.Id, actualSetting.Id, 'The setting should be the existing record');
        System.assertEquals(dmlStatmentsCalledBefore, dmlStatmentsCalledAfter, 'No dml should have occurred');
    }
}