@isTest
private class TestPopulateAlmPrivateCustomSetting {

    static testMethod void populateCustomSetting_Empty() {
        PopulateAlmPrivateCustomSetting cs = new PopulateAlmPrivateCustomSetting();
        
        Test.startTest();
            try {
                cs.populateCustomSetting();
            } catch (DMLException e) {
                System.assert(false, 'No DMLException should be thrown when the custom setting is empty.');
            }
        Test.stopTest();
        
        ALM_Private__c actual = ALM_Private__c.getOrgDefaults();
        
        System.assertEquals(PopulateAlmPrivateCustomSetting.CALLBACK_URL, actual.Callback_URL__c, 'Callback url should not be empty');
        System.assertEquals(PopulateAlmPrivateCustomSetting.CONSUMER_KEY, actual.Consumer_Key__c, 'Consumer key should not be empty');
        System.assertEquals(PopulateAlmPrivateCustomSetting.CONSUMER_SECRET, actual.Consumer_Secret__c, 'Consumer secret should not be empty');
    }
    
    static testMethod void populateCustomSetting_Non_Empty() {
        PopulateAlmPrivateCustomSetting cs = new PopulateAlmPrivateCustomSetting();
        cs.populateCustomSetting();
        
        Test.startTest();
            try {
                cs.populateCustomSetting();
                System.assert(true, 'The custom setting should have been upserted.');
            } catch (DMLException e) {
                System.assert(false, 'No DMLException should have been thrown trying to update the custom setting');
            }
        Test.stopTest();
    }
    
    static testMethod void isCustomSettingPopulated_Empty() {
        PopulateAlmPrivateCustomSetting cs = new PopulateAlmPrivateCustomSetting();
        
        Test.startTest();
            Boolean actual = cs.isCustomSettingPopulated();
        Test.stopTest();
        
        System.assertEquals(false, actual, 'Method should return false when the custom setting is empty.');
    }
    
    static testMethod void isCustomSettingPopulated_Non_Empty() {
        PopulateAlmPrivateCustomSetting cs = new PopulateAlmPrivateCustomSetting();
        try {
            cs.populateCustomSetting();
        } catch (DMLException e) {
            System.assert(false, 'No DMLException should be thrown when the custom setting is empty.');
        }
        
        Test.startTest();
            Boolean actual = cs.isCustomSettingPopulated();
        Test.stopTest();
        
        System.assertEquals(true, actual, 'Method should return true when the custom setting is non empty.');
    }

    static testMethod void clearAuthTokens() {
        Auth_User__c existingAuthUser = new Auth_User__c(Access_Token__c='some-value',
            Refresh_Token__c = 'some-other-value', Is_Refresh_Token_Valid__c = true);
        Auth_User__c existingAuthUser2 = new Auth_User__c(Access_Token__c='some-value1',
            Refresh_Token__c = 'some-other-value2', Is_Refresh_Token_Valid__c = true);
        insert new List<Auth_User__c> { existingAuthUser, existingAuthUser2 };

        Test.startTest();
            PopulateAlmPrivateCustomSetting.clearAuthTokens();
        Test.stopTest();

        List<Auth_User__c> authUsers = [SELECT Id, Refresh_Token__c, Access_Token__c FROM Auth_User__c];
        System.assertEquals(2, authUsers.size(), 'The number of auth users should be unchanged');
        for (Auth_User__c updatedAuthUser : authUsers) {
            System.assertEquals(true, String.isBlank(updatedAuthUser.Refresh_Token__c), 'The existing refresh token should be cleared');
            System.assertEquals(true, String.isBlank(updatedAuthUser.Access_Token__c), 'The existing access token should be cleared');
        }
    }
}