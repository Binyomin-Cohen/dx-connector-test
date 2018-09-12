public with sharing class PopulateAlmPrivateCustomSetting {
    
    @TestVisible
    private static String CALLBACK_URL = 'https://tools.bluewolf.com/oauth2';
    @TestVisible
    private static String CONSUMER_KEY = '3MVG9ytVT1SanXDnNFXJyqu1Q4VEAANzkDdF1NV8SvhNAgc5P6.zTMf4lHU6HVsyjarXUk9VbeDb.eLkPHxnK';
    @TestVisible
    private static String CONSUMER_SECRET = '8020018073598135482';
  
    public void populateCustomSetting() {
        ALM_Private__c customSetting = ALM_Private__c.getOrgDefaults();
        customSetting.Callback_URL__c = CALLBACK_URL;
        customSetting.Consumer_Key__c = CONSUMER_KEY;
        customSetting.Consumer_Secret__c = CONSUMER_SECRET;
    
        upsert customSetting;
    }
    
    public Boolean isCustomSettingPopulated() {
        ALM_Private__c currentAlmPrivateSetting = ALM_Private__c.getOrgDefaults();
        if (currentAlmPrivateSetting.Callback_URL__c == CALLBACK_URL && 
              currentAlmPrivateSetting.Consumer_Key__c == CONSUMER_KEY && 
                  currentAlmPrivateSetting.Consumer_Secret__c == CONSUMER_SECRET) {
            return true;
        }
        
        return false;
    }

    @future
    public static void clearAuthTokens() {
        Integer recordLimit = LimitServices.getRemainingDMLRecordsAvailable();

        List<Auth_User__c> authRecords = [
            SELECT Id, Refresh_Token__c, Access_Token__c
                FROM Auth_User__c 
                WHERE Is_Refresh_Token_Valid__c = true
                ORDER BY LastModifiedDate DESC
                LIMIT :recordLimit];

        for (Auth_User__c authUser : authRecords) {
            authUser.Refresh_Token__c = '';
            authUser.Access_Token__c = '';
        }

        try {
            if (!authRecords.isEmpty()) {
                update authRecords;
            }
        } catch(System.DmlException de) {
            ALMLogServices.error(de, ALMLogServices.Application.OAUTH);
        }
    }
}