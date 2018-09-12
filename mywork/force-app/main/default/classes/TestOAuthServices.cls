@isTest
private class TestOAuthServices {

    static Instances__c instance;
    static OAuthRequest.TokenResponse tokenResponse;

    static final String EXTERNAL_USER_ID = '005d00000014TvdAAE';
    static final String ORG_ID = '005d00000014TvdAAE';

    private static void setup() {
        instance = new Instances__c(Name='dev');
        insert instance;

        tokenResponse = new OAuthRequest.TokenResponse();
        tokenResponse.access_token = 'an access token';
        tokenResponse.refresh_token = 'refresh_token';
        tokenResponse.instance_url = 'instance_url';
        tokenResponse.id = 'https://login.salesforce.com/id/' + ORG_ID + '/' + EXTERNAL_USER_ID;
    }

    static testMethod void upsertAuthUser_insert() {
        setup();

        Test.startTest();

            OAuthServices.upsertAuthUser(tokenResponse, instance.Id, false);

        Test.stopTest();

        List<Auth_User__c> authUsers = [
            SELECT  Id, Org_ID__c, User__c, Refresh_Token__c, Instance__c, Instance_User__c, Access_Token__c
              FROM Auth_User__c
        ];

        System.assertEquals(1, authUsers.size(), 'An auth user should have created');
        System.assertEquals(ORG_ID, authUsers[0].Org_ID__c, 'The org id should be set from the token response');
        System.assertEquals(EXTERNAL_USER_ID, authUsers[0].Instance_User__c, 'The instance user id should be set from the token response');
        System.assertEquals(UserInfo.getUserId(), authUsers[0].User__c, 'The user id should be set to the running user');
        System.assertEquals(tokenResponse.access_token, authUsers[0].Access_Token__c, 'The access token should be set from the token response');
        System.assertEquals(tokenResponse.refresh_token, authUsers[0].Refresh_Token__c, 'The refresh toekn should be set from the token response');
        System.assertEquals(instance.Id, authUsers[0].Instance__c, 'The instance should be set');
    }

    static testMethod void upsertAuthUser_update() {
        setup();

        Auth_User__c authUser = new Auth_User__c();
        authUser.User__c = UserInfo.getUserId();
        authUser.Instance__c = instance.Id;
        authUser.Instance_User__c = EXTERNAL_USER_ID;

        insert authUser;

        Test.startTest();

            OAuthServices.upsertAuthUser(tokenResponse, instance.Id, false);

        Test.stopTest();

        List<Auth_User__c> authUsers = [
            SELECT  Id, Org_ID__c, User__c, Refresh_Token__c, Instance__c, Instance_User__c, Access_Token__c
              FROM Auth_User__c
        ];

        System.assertEquals(1, authUsers.size(), 'The auth user should have been updated');
        System.assertEquals(ORG_ID, authUsers[0].Org_ID__c, 'The org id should be updated from the token response');
        System.assertEquals(EXTERNAL_USER_ID, authUsers[0].Instance_User__c, 'The instance user id should be updated from the token response');
        System.assertEquals(UserInfo.getUserId(), authUsers[0].User__c, 'The user id should be updated to the running user');
        System.assertEquals(tokenResponse.access_token, authUsers[0].Access_Token__c, 'The access token should be updated from the token response');
        System.assertEquals(tokenResponse.refresh_token, authUsers[0].Refresh_Token__c, 'The refresh toekn should be updated from the token response');
        System.assertEquals(instance.Id, authUsers[0].Instance__c, 'The instance should be set');
    }

    static testMethod void upsertAuthUser_switchUser() {
        setup();

        Test.startTest();
            OAuthServices.upsertAuthUser(tokenResponse, instance.Id, true);
            System.runAs(TestingUtils.ADMIN_USER) {
                OAuthServices.upsertAuthUser(tokenResponse, instance.Id, true);
            }
        Test.stopTest();

        List<Auth_User__c> authUsers = [
            SELECT  Id, Org_ID__c, User__c, Refresh_Token__c, Instance__c, Instance_User__c, Access_Token__c
              FROM Auth_User__c
        ];

        System.assertEquals(1, authUsers.size(), 'The auth user should have been updated.');
        System.assertEquals(ORG_ID, authUsers[0].Org_ID__c, 'The org ID should be updated from the token response.');
        System.assertEquals(EXTERNAL_USER_ID, authUsers[0].Instance_User__c, 'The instance user ID should be updated from the token response.');
        System.assertEquals(TestingUtils.ADMIN_USER.Id, authUsers[0].User__c, 'The user ID should be updated to the running user.');
        System.assertEquals(tokenResponse.access_token, authUsers[0].Access_Token__c, 'The access token should be updated from the token response.');
        System.assertEquals(tokenResponse.refresh_token, authUsers[0].Refresh_Token__c, 'The refresh toekn should be updated from the token response.');
        System.assertEquals(instance.Id, authUsers[0].Instance__c, 'The instance should be set.');
    }

    static testMethod void upsertAuthUser_notForToolsDoesNotUpdateForTools() {
        String testRefreshToken = 'Test Refresh Token';

        setup();

        Auth_User__c existingAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id, true);
        existingAuthUser.Instance_User__c = EXTERNAL_USER_ID;
        existingAuthUser.Refresh_Token__c = testRefreshToken;
        update existingAuthUser;

        System.assertEquals(1, [SELECT Count() FROM Auth_User__c], 'One auth user should exist.');

        Test.startTest();

            OAuthServices.upsertAuthUser(tokenResponse, instance.Id, false);

        Test.stopTest();

        Auth_User__c refreshedExistingAuthUser = [SELECT Refresh_Token__c FROM Auth_User__c WHERE Id = :existingAuthUser.Id];

        System.assertEquals(testRefreshToken, refreshedExistingAuthUser.Refresh_Token__c, 'The existing auth user should not be updated.');
        System.assertEquals(2, [SELECT Count() FROM Auth_User__c], 'A new auth user should be added.');
    }

    static testMethod void getAuthUsersForTools() {
        setup();

        Instances__c instance2 = new Instances__c(Name='dev2');
        insert instance2;

        Auth_User__c toolAuthUser1 = TestingUtils.createAuthUser(UserInfo.getUserId(), instance.Id, true);
        Auth_User__c toolAuthUser2 = TestingUtils.createAuthUser(UserInfo.getUserId(), instance2.Id, true);
        Auth_User__c nonToolAuthUser = TestingUtils.createAuthUser(UserInfo.getUserId(), instance2.Id, false);

        Test.startTest();

            Map<Id,Auth_User__c> authUsers = OAuthServices.getAuthUsersForTools(new Set<String>{instance.Id, instance2.Id});

        Test.stopTest();

        System.assertEquals(2, authUsers.size(), 'An auth user should be returned for each instance');
        System.assertEquals(true, authUsers.containsKey(instance.Id), 'An auth user should be returned for each tool Authorization');
        System.assertEquals(toolAuthUser1.Id, authUsers.get(instance.Id).Id, 'An auth user should be returned for each tool Authorization');

        System.assertEquals(true, authUsers.containsKey(instance2.Id), 'An auth user should be returned for each tool Authorization');
        System.assertEquals(toolAuthUser2.Id, authUsers.get(instance2.Id).Id, 'An auth user should be returned for each tool Authorization');
    }

    private static testMethod void getAuthUsers_authUserIsForTools() {
        Id testUserId = UserInfo.getUserId();

        setup();

        Auth_User__c testAuthUserForTools = TestingUtils.createAuthUser(testUserId, instance.Id, true);
        Auth_User__c testAuthUserNotForTools = TestingUtils.createAuthUser(testUserId, instance.Id, false);

        Test.startTest();

            Map<Id, Auth_User__c> actualAuthUsers = OAuthServices.getAuthUsers(new Set<Id>{instance.Id}, true, testUserId);

        Test.stopTest();

        System.assertEquals(1, actualAuthUsers.size(), 'There should only be one auth user returned.');
        System.assertEquals(testAuthUserForTools.Id, actualAuthUsers.get(instance.Id).Id, 'The proper auth user should be returned.');
    }

    private static testMethod void getAuthUsers_authUserIsNotForTools() {
        Id testUserId = UserInfo.getUserId();

        setup();

        Auth_User__c testAuthUserForTools = TestingUtils.createAuthUser(testUserId, instance.Id, true);
        Auth_User__c testAuthUserNotForTools = TestingUtils.createAuthUser(testUserId, instance.Id, false);

        Test.startTest();

            Map<Id, Auth_User__c> actualAuthUsers = OAuthServices.getAuthUsers(new Set<Id>{instance.Id}, false, testUserId);

        Test.stopTest();

        System.assertEquals(1, actualAuthUsers.size(), 'There should only be one auth user returned.');
        System.assertEquals(testAuthUserNotForTools.Id, actualAuthUsers.get(instance.Id).Id, 'The proper auth user should be returned.');
    }

    private static testMethod void OAuthRequestCache() {
        String testInstanceId = 'testInstanceId';
        String testUserId = 'testUserId';
        Boolean isInProgress = true;

        Test.startTest();

            OAuthServices.putOAuthRequestStatusInCache(testInstanceId, testUserId, isInProgress);

        Test.stopTest();

        Boolean actualIsInProgress = OAuthServices.OAuthRequestIsInProgress(testInstanceId, testUserId);
        System.assertEquals(isInProgress, actualIsInProgress, 'The Auth Request should have the correct In Progress status');
    }

    private static testMethod void OAuthRequestCache_StatusIsCorrectlySet() {
        String testInstanceId = 'testInstanceId';
        String testUserId = 'testUserId';
        Boolean isInProgress = true;
        OAuthServices.putOAuthRequestStatusInCache(testInstanceId, testUserId, isInProgress);

        Boolean newIsInProgress = false;

        Test.startTest();

            OAuthServices.putOAuthRequestStatusInCache(testInstanceId, testUserId, newIsInProgress);

        Test.stopTest();

        List<State__c> stateRecords = [SELECT Id FROM State__c];
        System.assertEquals(1, stateRecords.size(), 'There should only be one cache record');


        Boolean actualIsInProgress = OAuthServices.OAuthRequestIsInProgress(testInstanceId, testUserId);
        System.assertEquals(newIsInProgress, actualIsInProgress, 'The Auth Request should have the correct In Progress status');
    }

    private static testMethod void OAuthRequestCache_returnsFalseWhenNoCacheRecordExists() {

        Test.startTest();

            Boolean isInProgress = OAuthServices.OAuthRequestIsInProgress('fakeTestInstanceId', 'fakeTestUserId');

        Test.stopTest();

        System.assert(!isInProgress, 'OAuthRequestIsInProgress should return false ' +
                                     'when no cache record exists for a request');
    }

    private static testMethod void OAuthRequestCache_InvalidCacheRecordThrowsException() {

        String errorMessage;

        Test.startTest();

            try {
                OAuthServices.putOAuthRequestStatusInCache(null, '', true);
                System.assert(false, 'An exception should have been thrown');
            } catch (Exception e) {
                errorMessage = e.getMessage();
            }

        Test.stopTest();

        System.assert(errorMessage.contains(OAuthServices.OAUTH_CACHE_INVALID_DATA_ERROR_MESSAGE),
                      'Inserting an invalid cache record should throw the correct exception');

        System.assert(errorMessage.toLowerCase().contains('instance'),
                      'The error message should mention the blank instance id');

        System.assert(errorMessage.toLowerCase().contains('user'),
                      'The error message should mention the blank user id');
    }
}
