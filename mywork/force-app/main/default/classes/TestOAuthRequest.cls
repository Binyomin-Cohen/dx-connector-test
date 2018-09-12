@isTest
private class TestOAuthRequest {
    
    static MockOAuthAPI mockApi;
    
    static Instances__c source;
    static Instances__c target;
    static Auth_User__c sourceAuth;
    static Auth_User__c targetAuth;

    private static void setup() {
        source = new Instances__c(Name='dev');
        target = new Instances__c(Name='ALM Org');
        insert new List<Instances__c> {source, target};

        sourceAuth = TestingUtils.buildAuthUser(UserInfo.getUserId(), source.Id, true);
        sourceAuth.Is_Refresh_Token_Valid__c = true;
        targetAuth = TestingUtils.buildAuthUser(UserInfo.getUserId(), target.Id, true);
        targetAuth.Is_Refresh_Token_Valid__c = true;
        insert new List<Auth_User__c>{sourceAuth, targetAuth};
    }

    static testMethod void testSetState_encodesParams() {
        TestingUtils.createOAuthSettings();

        String key = 'key';
        Map<String, String> state = new Map<String, String>();
        state.put(key, '+');

        OAuthRequest request = new OAuthRequest();
        Test.startTest();
            request.setState('https://c.na17.visualforce.com/apex/AdminInstanceManagement', state);
        Test.stopTest();

        Map<String, String> updatedState = request.getState();
        System.assertEquals(true, updatedState.containsKey(key), 'all custom state should be put into the state map');
        System.assertEquals('%2B', updatedState.get(key), 'All state params should be url encoded');
    }
    
    static testMethod void testGetAuthorizationUrl_verifyNoClientSecretInURL() {
        TestingUtils.createOAuthSettings();
        OAuthRequest request = new OAuthRequest();
        String authUrl = request.getAuthorizationUrl('test.salesforce.com', true);
        System.assert(!authUrl.contains(TestingUtils.CONSUMER_SECRET), 'The request for the authorization code should not pass the client secret to the auth server');
    }
    
    static testMethod void reauthorize_maxCalloutsExceeded() {
        Test.setMock(HttpCalloutMock.class, new MockOAuthAPI(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST));
        TestingUtils.createOAuthSettings();

        setup();

        List<Auth_User__c> auths = new List<Auth_User__c>();

        for(Integer i = 0; i < Limits.getLimitCallouts() + 1; i++) {
             Auth_User__c authUser = TestingUtils.buildAuthUser(UserInfo.getUserId(), source.Id, true);
             auths.add(authUser);
        }

        insert auths;

        Test.startTest();
            OAuthRequest request = new OAuthRequest();

            try {
                request.reauthorize(auths, false);
                System.assert(false, 'An exception should be thrown when too many callouts are attempted.');
            } catch(ALMException ae) {
                System.assertEquals(OAuthRequest.REAUTHORIZE_MAX_CALLOUTS_MSG, ae.getMessage(), 'An exception due to the number of callouts being attempted should be thrown');
            }

        Test.stopTest();
    }
    
    static testMethod void shouldRetryAuth_noValues(){
        
        
        OAuthRequest.REQUESTS_TO_RETRY = new Map<Integer, Set<String>>();
        
        Test.startTest();
            Boolean actualValue = OAuthRequest.shouldRetryAuth(404, 'some body');
        Test.stopTest();
        
        System.assertEquals(false, actualValue, 'We expect the shouldRetryAuth value to be correct.');
        
    }
    
    static testMethod void shouldRetryAuth_withStatusCodeAndValues(){
        
        Integer statusCode = 404;
        String retryBody = 'some body';
        
        OAuthRequest.REQUESTS_TO_RETRY = new Map<Integer, Set<String>>{
            
            statusCode => new Set<String>{retryBody}
            
        };
        
        Test.startTest();
            Boolean actualValue = OAuthRequest.shouldRetryAuth(statusCode, retryBody);
        Test.stopTest();
        
        System.assertEquals(true, actualValue, 'We expect the shouldRetryAuth value to be correct.');
        
    }
    
     static testMethod void shouldRetryAuth_withStatusCodeAndNoValues(){
        
        Integer statusCode = 404;
        String retryBody = 'some other body';
        
        OAuthRequest.REQUESTS_TO_RETRY = new Map<Integer, Set<String>>{
            
            statusCode => null
            
        };
        
        Test.startTest();
            Boolean actualValue = OAuthRequest.shouldRetryAuth(statusCode, retryBody);
        Test.stopTest();
        
        System.assertEquals(true, actualValue, 'We expect the shouldRetryAuth value to be correct.');
        
    }
    
    
    static void setupTestAndMockOauthAPI(String oauthAction, Integer oauthUserInfoStatusCode, Integer oauthRefreshTokenStatusCode,  String oauthUserInfoRespBody, String oauthRefreshRespBody){
        
        if (oauthUserInfoStatusCode != null && oauthRefreshTokenStatusCode != null){
            mockApi = new MockOAuthAPI(oauthAction, oauthUserInfoStatusCode, oauthRefreshTokenStatusCode, oauthUserInfoRespBody, oauthRefreshRespBody);
        } 
        else if (oauthUserInfoStatusCode != null && oauthRefreshTokenStatusCode == null){
            mockApi = new MockOAuthAPI(oauthAction, oauthUserInfoStatusCode, oauthUserInfoRespBody);
        }else {
            mockApi = new MockOAuthAPI(oauthAction);
        }

        Test.setMock(HttpCalloutMock.class, mockApi);
        
        TestingUtils.createOAuthSettings();

        setup();
        
    }
    
    static void assertOAuthReauthorize(String oauthAction, Integer oauthUserInfoStatusCode, Integer oauthRefreshTokenStatusCode,  String oauthUserInfoRespBody, String oauthRefreshRespBody, Boolean doLogErrorsAndUpdateAuths){
        
        setupTestAndMockOauthAPI(oauthAction, oauthUserInfoStatusCode, oauthRefreshTokenStatusCode,  oauthUserInfoRespBody, oauthRefreshRespBody);
        
        Integer currentMockAPIStatusCode = mockAPI.statusCode;
        Boolean expectedIsRefreshTokenValidValue = mockAPI.statusCode == OAuthRequest.SUCCESS_STATUS_CODE || mockAPI.refreshStatusCode == OAuthRequest.SUCCESS_STATUS_CODE;

        List<Auth_User__c> authUsers = new List<Auth_User__c>{sourceAuth, targetAuth};

        Test.startTest();
        
            OAuthRequest request = new OAuthRequest();

            try {
                request.reauthorize(authUsers, doLogErrorsAndUpdateAuths);
            } catch(ALMException ae) {
                System.assert(false, 'No exceptions should be thrown: ' + ae);
            }

        Test.stopTest();

        System.assertEquals(OAuthRequest.shouldRetryAuth(currentMockAPIStatusCode, oauthUserInfoRespBody), mockApi.hasAnotherRefreshRequestBeenCalled, 'We expect to retry the authorization correctly.');
        System.assertEquals(expectedIsRefreshTokenValidValue, authUsers[0].Is_Refresh_Token_Valid__c, 'The refresh token should be marked correctly for auth request result: ' + oauthAction);
        if (doLogErrorsAndUpdateAuths){
            List<Auth_User__c> actualAuthUsers = [Select Id, Is_Refresh_Token_Valid__c From Auth_User__c Where Id in (:sourceAuth.Id, :targetAuth.Id)];
            System.assertEquals(2, actualAuthUsers.size(), 'We expect the correct number of auth users');
            for (Auth_User__c authUser : actualAuthUsers){
                System.assertEquals(expectedIsRefreshTokenValidValue, authUser.Is_Refresh_Token_Valid__c, 'We expect the auth user record to be updated correctly.');
            }
        }
    }
    
    static void assertOAuthGetUserInfo(String oauthAction, Integer oauthUserInfoStatusCode, Integer oauthRefreshTokenStatusCode,  String oauthUserInfoRespBody, String oauthRefreshRespBody){
        
        setupTestAndMockOauthAPI(oauthAction, oauthUserInfoStatusCode, oauthRefreshTokenStatusCode,  oauthUserInfoRespBody, oauthRefreshRespBody);
        
        Integer currentMockAPIStatusCode = mockAPI.statusCode;
        Boolean expectedIsRefreshTokenValidValue = mockAPI.statusCode == OAuthRequest.SUCCESS_STATUS_CODE || mockAPI.refreshStatusCode == OAuthRequest.SUCCESS_STATUS_CODE;

        Test.startTest();
            
            OAuthRequest.UserInfoResponse resp;
            OAuthRequest request = new OAuthRequest();

            try {
                resp = request.getUserInfo(sourceAuth);
                
            } catch(ALMException ae) {
                System.assert(false, 'No exceptions should be thrown: ' + ae);
            }

        Test.stopTest();
        
        List<Auth_User__c> authUsers = [Select Id, Is_Refresh_Token_Valid__c From Auth_User__c Where Id = :sourceAuth.Id];
        
        System.assertEquals(OAuthRequest.shouldRetryAuth(currentMockAPIStatusCode, oauthUserInfoRespBody), mockApi.hasAnotherRefreshRequestBeenCalled, 'We expect to retry the authorization correctly.');
        System.assertEquals(expectedIsRefreshTokenValidValue, resp.isAuthorized, 'The isAuthorized refresh token should be marked correctly');
        System.assertEquals(expectedIsRefreshTokenValidValue, authUsers[0].Is_Refresh_Token_Valid__c, 'The refresh token should be marked correctly for auth user.');
        
    }

    static testMethod void reauthorize_forbiddenStatusCodeOnBothAttempts() {
        assertOAuthReauthorize(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, null, null, null, null, false);
    }
    
    static testMethod void reauthorize_successfulOnFirstAttempt() {
        assertOAuthReauthorize(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST, null, null, null, null, false);
    }
    
    static testMethod void reauthorize_forbiddenStatusCodeOnFirstAttemptAndNotFoundOnSecond() {
        assertOAuthReauthorize(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_FORBIDDEN_STATUS_CODE, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, null, false);
    }
    
    static testMethod void reauthorize_forbiddenStatusCodeOnFirstAttemptAndSuccessOnSecond() {
        assertOAuthReauthorize(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_FORBIDDEN_STATUS_CODE, OAuthRequest.SUCCESS_STATUS_CODE, null, null, false);
    }
    
    static testMethod void reauthorize_notFoundOnBothAttemptsWithBadIdAsBody() {
        assertOAuthReauthorize(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, OAuthRequest.ERROR_NOT_FOUND_BAD_ID, null, false);
    }
    static testMethod void reauthorize_notFoundStatusCodeWithBadIdOnFirstAttemptAndSuccessOnSecond() {
        assertOAuthReauthorize(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, OAuthRequest.SUCCESS_STATUS_CODE, OAuthRequest.ERROR_NOT_FOUND_BAD_ID, null, false);
    }
    
    static testMethod void reauthorize_notFoundOnBothAttemptsWithInactiveAsBody() {
        assertOAuthReauthorize(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, OAuthRequest.ERROR_NOT_FOUND_INACTIVE, null, false);
    }
    static testMethod void reauthorize_notFoundOnBothAttemptsWithNoAccessAsBody() {
        assertOAuthReauthorize(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, OAuthRequest.ERROR_NOT_FOUND_NO_ACCESS, null, false);
    }
    
    static testMethod void reauthorize_notFoundWithBadIdOnFirstAttemptAndForbiddenOnSecondAttempt() {
        assertOAuthReauthorize(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, OAuthRequest.ERROR_FORBIDDEN_STATUS_CODE, OAuthRequest.ERROR_NOT_FOUND_BAD_ID, null, false);
    }
    
    static testMethod void reauthorize_notFoundOnBothAttemptsWithNoSiteAccessAsBody() {
        assertOAuthReauthorize(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, OAuthRequest.ERROR_NOT_FOUND_NO_SITE_ENDPOINT, null, true);
        System.assertEquals(1,  [SELECT count() FROM Logged_Exception__c], 'The number of exceptions logged should be correct.');
    }
    static testMethod void reauthorize_notFoundOnBothAttemptsWithInternalErrorAsBody() {
        assertOAuthReauthorize(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, OAuthRequest.ERROR_NOT_FOUND_INTERNAL_ERROR, null, true);
        System.assertEquals(1,  [SELECT count() FROM Logged_Exception__c], 'The number of exceptions logged should be correct.');
    }
    
    static testMethod void reauthorize_notAcceptableOnFirstAttempt() {
        assertOAuthReauthorize(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_ACCEPTABLE_STATUS_CODE, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, null, true);
        System.assertEquals(1,  [SELECT count() FROM Logged_Exception__c], 'The number of exceptions logged should be correct.');
    }
    static testMethod void reauthorize_notAcceptableOnFirstAttemptAndDoNotLogErrors() {
        assertOAuthReauthorize(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_ACCEPTABLE_STATUS_CODE, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, null, false);
        System.assertEquals(0,  [SELECT count() FROM Logged_Exception__c], 'The number of exceptions logged should be correct.');
    }
    
    static testMethod void getUserInfo_successfulOnFirstAttempt() {
        assertOAuthGetUserInfo(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST, null, null, null, null);
    }
    
    static testMethod void getUserInfo_forbiddenStatusCodeOnBothAttempts() {
        assertOAuthGetUserInfo(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, null, null, null, null);
    }
    
    static testMethod void getUserInfo_forbiddenStatusCodeOnFirstAttemptAndNotFoundOnSecond() {
        assertOAuthGetUserInfo(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_FORBIDDEN_STATUS_CODE, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, null);
    }
    
    static testMethod void getUserInfo_forbiddenStatusCodeOnFirstAttemptAndSuccessOnSecond() {
        assertOAuthGetUserInfo(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_FORBIDDEN_STATUS_CODE, OAuthRequest.SUCCESS_STATUS_CODE, null, null);
    }
    
    static testMethod void getUserInfo_notFoundOnBothAttemptsWithBadIdAsBody() {
        assertOAuthGetUserInfo(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, OAuthRequest.ERROR_NOT_FOUND_BAD_ID, null);
    }
    static testMethod void getUserInfo_notFoundStatusCodeWithBadIdOnFirstAttemptAndSuccessOnSecond() {
        assertOAuthGetUserInfo(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, OAuthRequest.SUCCESS_STATUS_CODE, OAuthRequest.ERROR_NOT_FOUND_BAD_ID, null);
    }
    
    static testMethod void getUserInfo_notFoundOnBothAttemptsWithInactiveAsBody() {
        assertOAuthGetUserInfo(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, OAuthRequest.ERROR_NOT_FOUND_INACTIVE, null);
    }
    static testMethod void getUserInfo_notFoundOnBothAttemptsWithNoAccessAsBody() {
        assertOAuthGetUserInfo(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, OAuthRequest.ERROR_NOT_FOUND_NO_ACCESS, null);
    }
    
    static testMethod void getUserInfo_notFoundWithBadIdOnFirstAttemptAndForbiddenOnSecondAttempt() {
        assertOAuthGetUserInfo(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, OAuthRequest.ERROR_FORBIDDEN_STATUS_CODE, OAuthRequest.ERROR_NOT_FOUND_BAD_ID, null);
    }
    
    static testMethod void getUserInfo_notFoundOnBothAttemptsWithNoSiteAccessAsBody() {
        assertOAuthGetUserInfo(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, OAuthRequest.ERROR_NOT_FOUND_NO_SITE_ENDPOINT, null);
        System.assertEquals(1,  [SELECT count() FROM Logged_Exception__c], 'An exception should be logged');
    }
    static testMethod void getUserInfo_notFoundOnBothAttemptsWithInternalErrorAsBody() {
        assertOAuthGetUserInfo(MockOAuthAPI.SUCCESS_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, OAuthRequest.ERROR_NOT_FOUND_INTERNAL_ERROR, null);
        System.assertEquals(1,  [SELECT count() FROM Logged_Exception__c], 'An exception should be logged');
    }
    
    static testMethod void getUserInfo_notAcceptableOnFirstAttempt() {
        assertOAuthGetUserInfo(MockOAuthAPI.FAILURE_ACCESS_TOKEN_REQUEST, OAuthRequest.ERROR_NOT_ACCEPTABLE_STATUS_CODE, OAuthRequest.ERROR_NOT_FOUND_STATUS_CODE, null, null);
        System.assertEquals(1,  [SELECT count() FROM Logged_Exception__c], 'An exception should be logged');
    }

    static testMethod void getSightlineAuthUser() {
        TestingUtils.setupSightlineAuth();

        Test.startTest();

            Auth_User__c sightlineAuthUser = OAuthServices.getSightlineAuthUser();

        Test.stopTest();

        System.assertEquals(InstanceServices.almInstance.Id, sightlineAuthUser.Instance__c, 'The auth user instance ID should match that of the Sightline instance.');
    }
}